# Quickstart: Fix CA Lender Policy Calculation Bugs

**Feature**: 007-fix-ca-lender
**Status**: Planning Phase Complete
**Next Steps**: Generate tasks.md via `/speckit.tasks` command

---

## What This Feature Fixes

Four critical calculation errors in California lender policy pricing:

1. **Standalone Lender Multipliers**: Apply underwriter-specific multipliers (80% TRG / 75% ORT for Standard; 90% TRG / 85% ORT for Extended) instead of using 100% base rate
2. **Concurrent Standard Excess Formula**: Use $150 + percentage × (rate difference) instead of ELC lookup on excess amount - fixes 109% overcharge bug
3. **Extended Concurrent Support**: Enable Extended concurrent lender policies via full ELC rate table lookup
4. **Binder Acquisition Logic**: Skip lender policy calculation when `is_binder_acquisition: true` (cash purchases don't have lenders)

---

## Quick Start

### Prerequisites

- Ruby 3.4.8
- Bundler with dependencies installed (`bundle install`)
- RSpec for testing (`bundle exec rspec`)
- Rate manual references in `docs/rate_manuals/ca/`

### Key Files

| File | Purpose | Changes |
|------|---------|---------|
| `lib/ratenode/state_rules.rb` | State configuration | Add 3 new keys per underwriter (TRG/ORT) |
| `lib/ratenode/calculators/states/ca.rb` | CA calculator | Rewrite `calculate_lenders_premium` method |
| `spec/fixtures/scenarios_input.csv` | CSV test scenarios | Add test cases (human-provided values) |
| `spec/calculators/states/ca_spec.rb` | Unit tests | Add tests for new logic |

### Development Workflow

1. **Read the research** (`specs/007-fix-ca-lender/research.md`) - All unknowns resolved
2. **Review data model** (`specs/007-fix-ca-lender/data-model.md`) - Entities and validation rules
3. **Check contracts** (`specs/007-fix-ca-lender/contracts/`) - API signatures and configuration schema
4. **Generate tasks**: Run `/speckit.tasks` to create `tasks.md` with implementation steps
5. **Implement changes**: Follow tasks in order (state rules → calculator → tests)
6. **Run tests**: `bundle exec rspec spec/calculators/states/ca_spec.rb`
7. **CSV scenario validation**: Human must provide expected values from rate manuals

---

## Testing Strategy

### Unit Tests (RSpec)

Create tests in `spec/calculators/states/ca_spec.rb`:

```ruby
describe "calculate_lenders_premium" do
  context "Bug Fix 1: Standalone lender multipliers" do
    it "applies 80% multiplier for TRG Standard standalone" do
      # Test TRG Standard standalone = 80% of base rate
    end

    it "applies 75% multiplier for ORT Standard standalone" do
      # Test ORT Standard standalone = 75% of base rate
    end

    it "applies 90% multiplier for TRG Extended standalone" do
      # Test TRG Extended standalone = 90% of base rate
    end

    it "applies 85% multiplier for ORT Extended standalone" do
      # Test ORT Extended standalone = 85% of base rate
    end
  end

  context "Bug Fix 2: Concurrent Standard excess formula" do
    it "calculates TRG concurrent excess as $150 + 80% × rate_diff" do
      # Test TRG $400K owner / $500K loan = $309.20 (not $648)
    end

    it "calculates ORT concurrent excess as $150 + 75% × rate_diff" do
      # Test ORT $400K owner / $500K loan = expected value
    end

    it "returns $150 minimum when loan <= owner" do
      # Test concurrent Standard with loan <= owner returns $150 flat
    end

    it "enforces $150 minimum even if rate_diff calculation yields less" do
      # Test [concurrent_fee, concurrent_fee + excess_rate].max
    end
  end

  context "Bug Fix 3: Extended concurrent support" do
    it "uses ELC rate lookup for Extended concurrent" do
      # Test Extended concurrent = full ELC rate (not $150 + formula)
    end
  end

  context "Bug Fix 4: Binder acquisition logic" do
    it "returns $0 when is_binder_acquisition: true" do
      # Test cash acquisition skips lender policy
    end

    it "prioritizes is_binder_acquisition over include_lenders_policy" do
      # Test is_binder_acquisition: true + include_lenders_policy: true → $0
    end

    it "returns $0 when include_lenders_policy: false" do
      # Test explicit exclusion of lender policy
    end
  end

  context "Edge cases" do
    it "returns $0 for loan_amount_cents == 0" do
      # No loan means no lender policy
    end

    it "raises ArgumentError for negative loan amounts" do
      # Fail fast on invalid input
    end

    it "propagates rate lookup failures" do
      # Let database errors raise through
    end
  end
end
```

### CSV Scenario Tests

**IMPORTANT**: Human must add test scenarios with expected values from rate manuals (per Constitution Principle V).

New CSV columns needed:
- `lender_policy_type` (standard/extended)
- `is_binder_acquisition` (true/false)
- `include_lenders_policy` (true/false) - may already exist

Example scenarios to add:
```csv
state,underwriter,liability,loan_amount,lender_policy_type,is_binder_acquisition,expected_lender_premium
CA,TRG,50000000,50000000,standard,false,125680
CA,ORT,50000000,50000000,standard,false,120000
CA,TRG,50000000,50000000,extended,false,141390
CA,ORT,50000000,50000000,extended,false,133600
CA,TRG,40000000,50000000,standard,false,30920
CA,ORT,40000000,50000000,standard,false,24900
CA,TRG,50000000,40000000,standard,false,15000
CA,TRG,50000000,50000000,standard,true,0
```

**Action Required**: User must validate expected values against TRG/ORT rate manuals before adding to CSV.

---

## Configuration Reference

### State Rules (lib/ratenode/state_rules.rb)

Add to CA > underwriters > TRG:
```ruby
standalone_lender_standard_percent: 80.0,
standalone_lender_extended_percent: 90.0,
concurrent_standard_excess_percent: 80.0
```

Add to CA > underwriters > ORT:
```ruby
standalone_lender_standard_percent: 75.0,
standalone_lender_extended_percent: 85.0,
concurrent_standard_excess_percent: 75.0
```

### Rate Manual References

**TRG California** (`docs/rate_manuals/ca/CA_TRG_rate_summary.md`):
- Standalone lender rates: Lines 176-189
- Concurrent lender rates: Lines 192-240
- Concurrent excess formula: Lines 203-206

**ORT California** (`docs/rate_manuals/ca/CA_ORT_rate_summary.md`):
- Standalone lender rates: Lines 252-273
- Concurrent lender rates: Lines 275-348
- Concurrent excess formula: Lines 293-298

---

## Example Calculations

### Example 1: Standalone Standard (TRG, $500K loan)

**Before (Bug)**:
```
base_rate = BaseRate.calculate(50_000_000) → $1,571
premium = $1,571 (100% of base) ❌ WRONG
```

**After (Fixed)**:
```
base_rate = BaseRate.calculate(50_000_000) → $1,571
multiplier = 80.0 / 100.0 → 0.80
premium = ($1,571 * 0.80).round → $1,256.80 ✅ CORRECT
```

### Example 2: Concurrent Standard Excess (TRG, $400K owner / $500K loan)

**Before (Bug)**:
```
excess = 50_000_000 - 40_000_000 → $100,000
excess_rate = BaseRate.calculate_elc($100,000) → $648
premium = $150 + $648 → $798 ❌ WRONG (109% overcharge)
```

**After (Fixed)**:
```
rate_loan = BaseRate.calculate(50_000_000) → $1,571
rate_owner = BaseRate.calculate(40_000_000) → $1,372
rate_diff = $1,571 - $1,372 → $199
excess_percent = 80.0 / 100.0 → 0.80
excess_rate = ($199 * 0.80).round → $159.20
premium = [$150, $150 + $159.20].max → $309.20 ✅ CORRECT
```

### Example 3: Cash Acquisition (Binder)

**Before (Bug)**:
```
# Calculated lender policy even though cash purchase
premium = $1,256.80 ❌ WRONG
```

**After (Fixed)**:
```
is_binder_acquisition: true
return 0  # No lender policy on cash purchase ✅ CORRECT
```

---

## Validation Checklist

Before merging:

- [ ] All unit tests pass (`bundle exec rspec spec/calculators/states/ca_spec.rb`)
- [ ] CSV scenario tests pass with human-validated expected values (`bundle exec rspec spec/scenario_spec.rb`)
- [ ] TRG $400K owner / $500K loan returns $309.20 (not $648) - validates Bug Fix 2
- [ ] TRG standalone Standard $500K returns $1,256.80 (80% of $1,571) - validates Bug Fix 1
- [ ] ORT standalone Standard $500K returns $1,200 (75% of $1,600) - validates Bug Fix 1
- [ ] Extended concurrent uses ELC rate (not $150 + formula) - validates Bug Fix 3
- [ ] Cash acquisition (is_binder_acquisition: true) returns $0 - validates Bug Fix 4
- [ ] Constitution compliance: All changes isolated to CA, no cross-state dependencies
- [ ] Rate manual references documented in code comments

---

## Next Steps

1. Run `/speckit.tasks` to generate task breakdown in `tasks.md`
2. Implement tasks in dependency order
3. Request human-provided CSV test scenarios (Constitution Principle V)
4. Run tests and validate against rate manual examples
5. Merge when all tests pass and quote accuracy is confirmed

---

## Questions?

- Review `research.md` for detailed findings on each bug fix
- Review `data-model.md` for entities, fields, and state transitions
- Review `contracts/` for API signatures and configuration schema
- Reference TRG/ORT rate manuals in `docs/rate_manuals/ca/` for official rates

---

**Last Updated**: 2026-02-05
**Plan Phase**: Complete ✅
**Next Command**: `/speckit.tasks`
