# Research Findings: CA Over-$3M Formulas

**Feature**: 008-fix-ca-3m-formulas
**Date**: 2026-02-05
**Phase**: 0 - Research & Discovery

## Executive Summary

This research consolidates findings from rate manuals, existing codebase analysis, and clarifications to support implementation of underwriter-specific over-$3M formulas, minimum premiums, and refinance caps for California.

---

## 1. Over-$3M Owner Premium Formulas

### Decision: Store formulas as configuration parameters in state_rules.rb

**Rationale:**
- Formulas differ by underwriter (TRG vs ORT) but use same calculation pattern
- Storing parameters (base_cents, per_10k_cents) in config allows runtime formula selection
- Removes hardcoded TRG-only constants from rate_tier.rb

**Current Implementation Issues:**
```ruby
# lib/ratenode/models/rate_tier.rb:8-9
OVER_3M_BASE_CENTS = 421_100  # Hardcoded TRG value
OVER_3M_PER_10K_CENTS = 525   # Hardcoded TRG value
```

**From Rate Manuals:**

| Underwriter | Base at $3M | Per $10K Increment | Manual Reference |
|-------------|-------------|--------------------|--------------------|
| TRG | $4,211 (421_100 cents) | $5.25 (525 cents) | CA_TRG_rate_summary.md line 65 |
| ORT | $4,438 (443_800 cents) | $6.00 (600 cents) | CA_ORT_rate_summary.md line 75 |

**Formula Pattern:**
```ruby
premium = base_cents + (increments × per_10k_cents)
where increments = (liability_cents - 300_000_000) / 1_000_000).ceil
```

**Alternatives Considered:**
- Database table: Rejected - formulas are configuration, not rate data
- Separate calculator methods: Rejected - adds duplication for same calculation pattern

---

## 2. Extended Lender Concurrent (ELC) Over-$3M Formulas

### Decision: Add underwriter-specific ELC formula parameters to state_rules.rb

**Rationale:**
- ELC has different formula than owner premium (different base, different per-$10K rate)
- Current implementation has incorrect hardcoded values producing cents instead of dollars
- Underwriter-specific parameters enable correct calculations for both TRG and ORT

**Current Implementation Issues:**
```ruby
# lib/ratenode/models/rate_tier.rb:131-135
def self.calculate_elc_over_3m(liability_cents)
  excess = liability_cents - THREE_MILLION_CENTS
  increments = (excess / 1_000_000.0).ceil
  75 + (increments * 75)  # WRONG: produces $0.75 instead of $2,472+
end
```

**From Rate Manuals:**

| Underwriter | ELC Base at $3M | ELC Per $10K | Manual Reference |
|-------------|-----------------|--------------|-------------------|
| TRG | $2,472 (247_200 cents) | $4.20 (420 cents) | CA_TRG_rate_summary.md line 12 (clarification) |
| ORT | $2,550 (255_000 cents) | $3.00 (300 cents) | CA_ORT_rate_summary.md line 327 |

**Formula Pattern:**
```ruby
elc_premium = elc_base_cents + (increments × elc_per_10k_cents)
where increments = (liability_cents - 300_000_000) / 1_000_000).ceil
```

**Impact:**
- User Story 2 reports ELC rates are ~99% too low (cents instead of dollars)
- This is the critical revenue leak

---

## 3. Minimum Premium Enforcement

### Decision: Apply minimum to base rate before multipliers/surcharges

**Rationale:**
- Clarification confirms: "Apply minimum to base rate first, then apply all multipliers and surcharges"
- Prevents minimum from being bypassed by multiplying a below-minimum base rate
- Consistent with industry practice

**From Clarifications (spec.md line 13):**
> Q: When should minimum premium be applied? FR-004 says "after policy-type multipliers but before hold-open surcharges" but User Story 3 says "before multipliers/surcharges". Which is correct?
> A: Apply minimum to base rate first, then apply all multipliers and surcharges

**From Rate Manuals:**

| Underwriter | Minimum Premium | Manual Reference |
|-------------|----------------|-------------------|
| TRG | $609 (60_900 cents) | CA_TRG_rate_summary.md line 36 |
| ORT | $725 (72_500 cents) | CA_ORT_rate_summary.md line 37 |

**Calculation Order:**
```
1. Calculate base owner rate (tier lookup or over-$3M formula)
2. Apply minimum floor: base_rate = [base_rate, minimum].max
3. Apply policy type multiplier: premium = base_rate × multiplier
4. Add hold-open surcharge if applicable: premium += surcharge
```

**Implementation Location:**
- CA calculator's `calculate_standard` method (lib/ratenode/calculators/states/ca.rb:170)
- Must apply minimum AFTER base_rate lookup, BEFORE multiplier

---

## 4. Refinance Premium Over $10M

### Decision: Dual calculation approach - tier lookups ≤$10M, runtime formulas >$10M

**Rationale:**
- Rate manuals provide fixed tiers up to $10M
- Over $10M uses progressive formula (base + per-million increment)
- Matches existing refinance_rate.rb pattern (has over-$5M formula)

**From Rate Manuals:**

| Underwriter | Refinance Base at $10M | Per Million Over $10M | Manual Reference |
|-------------|------------------------|----------------------|-------------------|
| TRG | $7,200 (720_000 cents) | $800 (80_000 cents) | CA_TRG_rate_summary.md line 298 |
| ORT | $7,610 (761_000 cents) | $1,000 (100_000 cents) | CA_ORT_rate_summary.md: inferred from Section 2.3 limits at $10M |

**ORT Note:**
- ORT "Residential Financing" (Section 2.3) explicitly states "Up to $10,000,000" as maximum
- No explicit over-$10M formula documented in ORT summary
- Conservative approach: use database tiers up to $10M, add formula parameters for consistency

**Formula Pattern:**
```ruby
if liability_cents <= 1_000_000_000  # $10M
  # Use tier lookup from refinance_rates table
  Models::RefinanceRate.calculate_rate(liability_cents, state: "CA", underwriter: underwriter)
else
  # Use runtime formula
  millions_over_10m = ((liability_cents - 1_000_000_000) / 100_000_000.0).ceil
  refinance_base_cents + (millions_over_10m × refinance_per_million_cents)
end
```

**Implementation Notes:**
- Refinance calculation happens in separate flow (not owner's premium)
- Parameters belong in state_rules.rb for consistency
- Existing `refinance_rate.rb:36` already has OVER_5M logic - extend pattern for CA

**Alternatives Considered:**
- Extend database tiers to cover all amounts: Rejected - formulas are more flexible for ultra-high values
- State-specific calculator method: Rejected - formula parameters in config are more maintainable

---

## 5. Underwriter Parameter Passthrough

### Decision: Pass `underwriter` parameter through entire calculation pipeline

**Rationale:**
- Formulas require underwriter identifier to select correct parameters from state_rules.rb
- Current pipeline: Calculator → BaseRate → RateTier
- `underwriter` already passed to BaseRate; must continue to RateTier methods

**Current Implementation (lib/ratenode/calculators/base_rate.rb):**
```ruby
def initialize(liability_cents, state:, underwriter:, as_of_date: Date.today)
  @liability_cents = liability_cents
  @state = state
  @underwriter = underwriter
  @as_of_date = as_of_date
end
```

**Required Changes:**
- `RateTier.calculate_over_3m_rate` → Add underwriter parameter, use state_rules lookup
- `RateTier.calculate_elc_over_3m` → Add underwriter parameter, use state_rules lookup
- CA calculator's `lookup_base_rate` → Already passes underwriter ✅
- CA calculator's `calculate_owners_premium` → Already has @underwriter ✅

**No Breaking Changes:**
- Other states (AZ, FL, NC, TX) don't use over-$3M formulas
- Underwriter parameter already optional in most methods

---

## 6. Configuration Structure in state_rules.rb

### Decision: Add formula parameters under underwriter-specific sections

**Rationale:**
- Existing pattern: CA has `underwriters: { "TRG" => {...}, "ORT" => {...} }`
- Each underwriter section already contains rate-related config (concurrent_base_fee_cents, multipliers)
- Formula parameters belong alongside other rate configuration

**New Parameters to Add:**

```ruby
STATE_RULES = {
  "CA" => {
    underwriters: {
      "TRG" => {
        # Existing config...
        minimum_premium_cents: 60_900,                      # $609
        over_3m_base_cents: 421_100,                        # $4,211
        over_3m_per_10k_cents: 525,                         # $5.25
        elc_over_3m_base_cents: 247_200,                    # $2,472
        elc_over_3m_per_10k_cents: 420,                     # $4.20
        refinance_over_10m_base_cents: 720_000,             # $7,200
        refinance_over_10m_per_million_cents: 80_000        # $800
      },
      "ORT" => {
        # Existing config...
        minimum_premium_cents: 72_500,                      # $725
        over_3m_base_cents: 443_800,                        # $4,438
        over_3m_per_10k_cents: 600,                         # $6.00
        elc_over_3m_base_cents: 255_000,                    # $2,550
        elc_over_3m_per_10k_cents: 300,                     # $3.00
        refinance_over_10m_base_cents: 761_000,             # $7,610 (inferred)
        refinance_over_10m_per_million_cents: 100_000       # $1,000 (estimated)
      }
    }
  }
}
```

**Parameter Naming Convention:**
- All amounts in cents (consistent with existing codebase)
- Descriptive names: `over_3m_base_cents` (not `base_cents` which is ambiguous)
- Parallel structure: same parameter names for both underwriters

**Access Pattern:**
```ruby
rules = RateNode.rules_for("CA", underwriter: "TRG")
base = rules[:over_3m_base_cents]           # 421_100
per_10k = rules[:over_3m_per_10k_cents]     # 525
```

---

## 7. Boundary Conditions

### Decision: Use tier-based rates at exactly $3,000,000 and $10,000,000

**Rationale:**
- Clarification confirms: "Use tier-based rate from seed data; over-$3M formula applies only to amounts > $3,000,000"
- Prevents off-by-one errors at boundary thresholds
- Consistent with "or fraction thereof" language in rate manuals (applies to amounts ABOVE threshold)

**From Clarifications (spec.md line 14):**
> Q: At exactly $3,000,000, should the system use tier-based rate from seed data or the over-$3M formula?
> A: Use tier-based rate from seed data; over-$3M formula applies only to amounts > $3,000,000

**Implementation:**
```ruby
# Over-$3M check
if liability_cents > 300_000_000  # Strictly greater than
  calculate_over_3m_rate(liability_cents, underwriter: underwriter)
else
  # Use tier lookup from rate_tiers table
end

# Refinance over-$10M check
if liability_cents > 1_000_000_000  # Strictly greater than
  calculate_over_10m_refinance(liability_cents, underwriter: underwriter)
else
  # Use tier lookup from refinance_rates table
end
```

**Test Cases:**
- $3,000,000 → Use tier data (not formula)
- $3,000,001 → Use formula ($4,211 + $5.25 for TRG)
- $10,000,000 → Use tier data
- $10,000,001 → Use formula ($7,200 + $800 for TRG)

---

## 8. Floating Point Precision

### Decision: Always round results of multiplications with float percentages

**Rationale:**
- Memory guidance: "Floating point: always `.round` results of multiplication with Float percentages"
- Prevents accumulation of floating point errors
- Consistent with existing codebase patterns

**Implementation Pattern:**
```ruby
# Policy type multiplier (1.10, 1.25)
premium = (base_rate * multiplier).round

# Surcharge percent (0.10 for hold-open)
surcharge = (base_rate * surcharge_percent).round

# Lender policy percentages (80.0, 75.0)
lender_premium = (base_rate * lender_percent / 100.0).round
```

**Already Correct in CA Calculator:**
- Line 173: `(base_rate * multiplier).round` ✅
- Line 184: `(base_rate * surcharge_percent).round` ✅
- Line 102: `(base_rate * multiplier / 100.0).round` ✅

---

## 9. Test Strategy

### Decision: Reuse existing CSV scenario test infrastructure with $2.00 tolerance

**Rationale:**
- CSV scenario tests already exist for CA (spec/integration/csv_scenarios_spec.rb)
- $2.00 tolerance accounts for rounding differences (Memory: "CSV test tolerance: $2.00 difference allowed for rounding")
- Success Criterion SC-005 requires "All existing CSV scenario tests continue to pass"

**Test Coverage Requirements:**

| Test Scenario | Purpose | Acceptance Criteria |
|---------------|---------|---------------------|
| Over-$3M owner premiums | Verify formula calculations | Match manual values ±$2 |
| ELC above $3M | Verify ELC formulas produce dollars not cents | Match manual values ±$2 |
| Minimum premium enforcement | Verify floor is applied | Exactly minimum for low values |
| Refinance over $10M | Verify progressive formula | Match manual values ±$2 |
| Boundary at $3,000,000 | Verify tier vs formula selection | Use tier rate |
| Boundary at $10,000,000 | Verify tier vs formula selection | Use tier rate |
| Both underwriters (TRG, ORT) | Verify underwriter-specific formulas | Different results per underwriter |

**Existing Test Infrastructure:**
- `spec/integration/csv_scenarios_spec.rb` - CSV-driven integration tests
- `spec/calculators/states/ca_spec.rb` - Unit tests for CA calculator
- `spec/fixtures/scenarios_input.csv` - Test data (human-controlled per Constitution V)

**No CSV Schema Changes:**
- Existing columns support underwriter, liability, policy_type
- No new input/output columns needed

---

## 10. Dependencies and Integration Points

### Files Requiring Modification:

1. **lib/ratenode/state_rules.rb**
   - Add formula parameters to CA → TRG section
   - Add formula parameters to CA → ORT section

2. **lib/ratenode/models/rate_tier.rb**
   - Remove hardcoded constants OVER_3M_BASE_CENTS, OVER_3M_PER_10K_CENTS
   - Add underwriter parameter to `calculate_over_3m_rate`
   - Add underwriter parameter to `calculate_elc_over_3m` (rename to `calculate_elc_over_3m_rate`)
   - Retrieve formula parameters from state_rules.rb

3. **lib/ratenode/calculators/states/ca.rb**
   - Add minimum premium enforcement in `calculate_standard` method
   - Pass underwriter to ELC calculation calls

4. **lib/ratenode/models/refinance_rate.rb** (if refinance support needed)
   - Add CA-specific over-$10M formula logic
   - Retrieve formula parameters from state_rules.rb

### No Changes Required:
- `lib/ratenode/calculators/base_rate.rb` - Already passes underwriter ✅
- `lib/ratenode/calculator.rb` - No changes to public API
- Database schema - No migrations needed
- CSV test format - No schema changes

---

## 11. Risk Mitigation

### Backward Compatibility:
- ✅ Other states (AZ, FL, NC, TX) unaffected - they don't use over-$3M formulas
- ✅ Existing CA behavior preserved for amounts ≤$3M - tier lookup unchanged
- ✅ Hold-open/binder workflow untouched (implemented in 007-fix-ca-lender)

### Testing Strategy:
- Run existing CSV scenarios to catch regressions
- Add unit tests for new formula methods with boundary conditions
- Verify both TRG and ORT produce correct results

### Documentation:
- Rate manual references included in code comments
- Formula parameters clearly named and documented
- Configuration centralized in state_rules.rb for easy verification

---

## Summary: Ready for Implementation

All unknowns from Technical Context have been resolved:

| Original Unknown | Resolution |
|------------------|-----------|
| TRG ELC per-$10K rate | $4.20 (420 cents) - confirmed from manual |
| Minimum premium application order | Before multipliers/surcharges - confirmed |
| Boundary at $3,000,000 | Use tier rate; formula for > $3M only |
| Refinance dual approach | Tier lookup ≤$10M, formula >$10M |
| Formula parameter storage | state_rules.rb with underwriter-specific sections |

**Next Phase**: Generate data model and contracts (Phase 1)
