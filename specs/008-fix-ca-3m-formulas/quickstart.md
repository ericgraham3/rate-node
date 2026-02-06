# Quick Start: CA Over-$3M Formulas Implementation

**Feature**: 008-fix-ca-3m-formulas
**Branch**: `008-fix-ca-3m-formulas`
**Target**: Ruby 3.4.8 CLI application

## What This Feature Does

Implements accurate premium calculations for California properties valued over $3 million by:
1. Adding underwriter-specific (TRG and ORT) formula parameters to configuration
2. Fixing ELC calculation that was producing cents instead of dollars (~99% too low)
3. Enforcing minimum premium floors ($609 TRG, $725 ORT) on all owner policies
4. Supporting progressive refinance rates above $10M

## Prerequisites

- Ruby 3.4.8 installed
- Dependencies installed: `bundle install`
- Understanding of California title insurance rate structures
- Access to rate manual summaries in `docs/rate_manuals/ca/`

## Files You'll Modify

```
lib/ratenode/
├── state_rules.rb                   # Add formula parameters (CA → TRG, CA → ORT)
├── models/rate_tier.rb              # Update over-$3M and ELC methods
├── calculators/states/ca.rb         # Add minimum premium enforcement
└── models/refinance_rate.rb         # (Optional) Add over-$10M formula
```

## Implementation Steps

### Step 1: Add Formula Parameters to State Rules

**File**: `lib/ratenode/state_rules.rb`

Locate the CA → TRG section (~line 33) and add:
```ruby
"TRG" => {
  # ... existing config ...

  # Add these 7 parameters:
  minimum_premium_cents: 60_900,                      # $609
  over_3m_base_cents: 421_100,                        # $4,211
  over_3m_per_10k_cents: 525,                         # $5.25
  elc_over_3m_base_cents: 247_200,                    # $2,472
  elc_over_3m_per_10k_cents: 420,                     # $4.20
  refinance_over_10m_base_cents: 720_000,             # $7,200
  refinance_over_10m_per_million_cents: 80_000        # $800
}
```

Locate the CA → ORT section (~line 57) and add:
```ruby
"ORT" => {
  # ... existing config ...

  # Add these 7 parameters:
  minimum_premium_cents: 72_500,                      # $725
  over_3m_base_cents: 443_800,                        # $4,438
  over_3m_per_10k_cents: 600,                         # $6.00
  elc_over_3m_base_cents: 255_000,                    # $2,550
  elc_over_3m_per_10k_cents: 300,                     # $3.00
  refinance_over_10m_base_cents: 761_000,             # $7,610
  refinance_over_10m_per_million_cents: 100_000       # $1,000
}
```

**Verification**: Run `irb -r ./lib/ratenode` and check:
```ruby
RateNode.rules_for("CA", underwriter: "TRG")[:over_3m_base_cents]
# => 421100
```

---

### Step 2: Update Over-$3M Owner Premium Method

**File**: `lib/ratenode/models/rate_tier.rb`

**Remove hardcoded constants** (lines 8-9):
```ruby
# DELETE:
# OVER_3M_BASE_CENTS = 421_100
# OVER_3M_PER_10K_CENTS = 525
```

**Replace `calculate_over_3m_rate` method** (~line 125):
```ruby
def self.calculate_over_3m_rate(liability_cents, state:, underwriter:)
  rules = RateNode.rules_for(state, underwriter: underwriter)
  base = rules[:over_3m_base_cents]
  rate_per_10k = rules[:over_3m_per_10k_cents]

  excess = liability_cents - THREE_MILLION_CENTS
  increments = (excess / 1_000_000.0).ceil
  base + (increments * rate_per_10k)
end
```

**Update call site** (~line 72):
```ruby
# OLD:
# return calculate_over_3m_rate(liability_cents) if liability_cents > THREE_MILLION_CENTS

# NEW:
return calculate_over_3m_rate(liability_cents, state: state, underwriter: underwriter) if liability_cents > THREE_MILLION_CENTS && state == "CA"
```

**Verification**:
```ruby
RateNode::Models::RateTier.calculate_over_3m_rate(350_000_000, state: "CA", underwriter: "TRG")
# => 447350 ($4,473.50)
```

---

### Step 3: Fix ELC Over-$3M Method

**File**: `lib/ratenode/models/rate_tier.rb`

**Rename and replace `calculate_elc_over_3m`** (~line 131):
```ruby
# OLD METHOD NAME: calculate_elc_over_3m
# NEW METHOD NAME: calculate_elc_over_3m_rate

def self.calculate_elc_over_3m_rate(liability_cents, state:, underwriter:)
  rules = RateNode.rules_for(state, underwriter: underwriter)
  base = rules[:elc_over_3m_base_cents]
  rate_per_10k = rules[:elc_over_3m_per_10k_cents]

  excess = liability_cents - THREE_MILLION_CENTS
  increments = (excess / 1_000_000.0).ceil
  base + (increments * rate_per_10k)
end
```

**Update call site in `calculate_extended_lender_concurrent_rate`** (~line 117):
```ruby
# OLD:
# return calculate_elc_over_3m(liability_cents) if liability_cents > THREE_MILLION_CENTS

# NEW:
return calculate_elc_over_3m_rate(liability_cents, state: state, underwriter: underwriter) if liability_cents > THREE_MILLION_CENTS
```

**Verification**:
```ruby
RateNode::Models::RateTier.calculate_elc_over_3m_rate(350_000_000, state: "CA", underwriter: "TRG")
# => 268200 ($2,682) - NOT 150 (cents)!
```

---

### Step 4: Add Minimum Premium Enforcement

**File**: `lib/ratenode/calculators/states/ca.rb`

**Update `calculate_standard` method** (~line 170):
```ruby
def calculate_standard
  base_rate = lookup_base_rate(@liability_cents)

  # NEW: Apply minimum premium floor
  minimum = state_rules[:minimum_premium_cents] || 0
  base_rate = [base_rate, minimum].max

  multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "CA", underwriter: @underwriter, as_of_date: @as_of_date)
  (base_rate * multiplier).round
end
```

**Verification**:
```ruby
calc = RateNode::States::CA.new
calc.calculate_owners_premium(
  liability_cents: 1_000_000,      # $10K (below minimum)
  policy_type: :standard,
  underwriter: "TRG"
)
# => 60900 ($609 minimum enforced)
```

---

### Step 5 (Optional): Add Refinance Over-$10M Formula

**File**: `lib/ratenode/models/refinance_rate.rb`

**Add CA-specific logic to `calculate_rate`** (~line 35):
```ruby
def self.calculate_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
  # CA-specific over-$10M formula
  if state == "CA" && liability_cents > 1_000_000_000
    return calculate_ca_over_10m_refinance(liability_cents, underwriter: underwriter)
  end

  # Existing logic...
end

def self.calculate_ca_over_10m_refinance(liability_cents, underwriter:)
  rules = RateNode.rules_for("CA", underwriter: underwriter)
  base = rules[:refinance_over_10m_base_cents]
  rate_per_million = rules[:refinance_over_10m_per_million_cents]

  excess_cents = liability_cents - 1_000_000_000
  millions_over_10m = (excess_cents / 100_000_000.0).ceil

  base + (millions_over_10m * rate_per_million)
end
```

**Verification**:
```ruby
RateNode::Models::RefinanceRate.calculate_rate(1_200_000_000, state: "CA", underwriter: "TRG")
# => 880000 ($8,800)
```

---

## Testing

### Run Unit Tests
```bash
bundle exec rspec spec/calculators/states/ca_spec.rb
```

### Run CSV Integration Tests
```bash
bundle exec rspec spec/integration/csv_scenarios_spec.rb
```

### Key Test Cases to Verify

| Test Case | Expected Result | Tolerance |
|-----------|----------------|-----------|
| TRG owner at $3.5M | $4,473.50 | ±$2 |
| ORT owner at $3.5M | $4,738 | ±$2 |
| TRG ELC at $3.5M | $2,682 | ±$2 |
| ORT ELC at $3.5M | $2,700 | ±$2 |
| TRG minimum at $10K | $609 exactly | $0 |
| ORT minimum at $10K | $725 exactly | $0 |
| TRG refinance at $12M | $8,800 | ±$2 |
| ORT refinance at $15M | $12,610 | ±$2 |

### Manual Smoke Test
```bash
bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --liability 3500000 \
  --policy-type standard

# Expected: ~$4,473.50
```

---

## Common Issues & Solutions

### Issue 1: "Unknown underwriter" Error
**Symptom**: `Error: Unknown underwriter TRG for CA`
**Solution**: Check that formula parameters are added to the correct underwriter section in state_rules.rb

### Issue 2: ELC Still Returns Cents
**Symptom**: ELC at $3.5M returns $2.68 instead of $2,682
**Solution**: Verify `calculate_elc_over_3m_rate` call site is passing `state:` and `underwriter:` parameters

### Issue 3: Minimum Not Applied
**Symptom**: $10K liability returns less than $609 for TRG
**Solution**: Check that `calculate_standard` method applies minimum AFTER base_rate but BEFORE multiplier

### Issue 4: Boundary Condition Fails
**Symptom**: $3,000,000 uses formula instead of tier
**Solution**: Ensure comparison is `>` not `>=`: `if liability_cents > THREE_MILLION_CENTS`

---

## Validation Checklist

Before submitting PR:

- [ ] All formula parameters added to state_rules.rb (both TRG and ORT)
- [ ] Hardcoded constants removed from rate_tier.rb
- [ ] `calculate_over_3m_rate` accepts underwriter parameter
- [ ] `calculate_elc_over_3m` renamed to `calculate_elc_over_3m_rate` + accepts underwriter
- [ ] Minimum premium enforcement added to CA calculator
- [ ] Unit tests pass for CA calculator
- [ ] CSV scenario tests pass within $2 tolerance
- [ ] No regressions in other states (AZ, FL, NC, TX tests pass)
- [ ] Manual smoke test successful for $3.5M property

---

## Rate Manual References

When verifying calculations, reference these sections:

**TRG Manual** (`docs/rate_manuals/ca/CA_TRG_rate_summary.md`):
- Line 36: Minimum premium $609
- Line 65: Over-$3M formula ($5.25 per $10K)
- Line 298: Refinance over-$10M ($800 per million)
- Clarification: ELC over-$3M ($2,472 base + $4.20 per $10K)

**ORT Manual** (`docs/rate_manuals/ca/CA_ORT_rate_summary.md`):
- Line 37: Minimum premium $725
- Line 75: Over-$3M formula ($6 per $10K)
- Line 327: ELC over-$3M ($2,550 base + $3 per $10K)
- Section 2.3: Residential Financing max $10M

---

## Next Steps After Implementation

1. Update CLAUDE.md with new formula parameter pattern (run agent context update script)
2. Create PR with descriptive title: "feat(CA): Add underwriter-specific over-$3M formulas and minimum premiums"
3. Reference spec.md in PR description
4. Request review from domain expert (rate manual verification)
5. After merge, update project memory with lessons learned

---

## Help & Resources

- **Spec**: `specs/008-fix-ca-3m-formulas/spec.md`
- **Research**: `specs/008-fix-ca-3m-formulas/research.md`
- **Data Model**: `specs/008-fix-ca-3m-formulas/data-model.md`
- **API Contract**: `specs/008-fix-ca-3m-formulas/contracts/calculation_api.md`
- **Memory**: `~/.claude/projects/-home-eric-rate-node/memory/MEMORY.md`

**Questions?** Check Memory.md for common pitfalls and patterns.
