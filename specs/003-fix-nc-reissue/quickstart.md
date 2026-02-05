# Quickstart: Fix NC Reissue Discount Calculation

**Feature**: 003-fix-nc-reissue | **Date**: 2026-02-04

## Prerequisites

- Ruby 3.4.8 installed
- Dependencies installed (`bundle install`)
- Database seeded (`bundle exec rake db:seed`)

## Implementation Checklist

### 1. Modify `calculate_reissue_discount()` in NC calculator

**File**: `lib/ratenode/calculators/states/nc.rb`

**Current code** (lines 152-171):
```ruby
def calculate_reissue_discount(full_premium)
  return 0 unless eligible_for_reissue_discount?

  discount_percent = state_rules[:reissue_discount_percent]
  discountable_portion_cents = [@liability_cents, @prior_policy_amount_cents].min

  # BUG: Proportional approximation
  discountable_base_rate = if discountable_portion_cents == @liability_cents
                               full_premium
                             else
                               (full_premium * discountable_portion_cents.to_f / @liability_cents).round
                             end

  (discountable_base_rate * discount_percent).round
end
```

**Corrected code**:
```ruby
def calculate_reissue_discount(full_premium)
  return 0 unless eligible_for_reissue_discount?

  discount_percent = state_rules[:reissue_discount_percent]
  discountable_portion_cents = [@liability_cents, @prior_policy_amount_cents].min

  # Calculate tiered rate on discountable portion (not proportional)
  discountable_tiered_rate = Models::RateTier.calculate_rate(
    discountable_portion_cents,
    state: "NC",
    underwriter: @underwriter,
    as_of_date: @as_of_date
  )

  # Apply policy type multiplier to discount base
  multiplier = Models::PolicyType.multiplier_for(
    @policy_type,
    state: "NC",
    underwriter: @underwriter,
    as_of_date: @as_of_date
  )
  discountable_base = (discountable_tiered_rate * multiplier).round

  (discountable_base * discount_percent).round
end
```

### 2. Remove outdated TODO comment

**File**: `lib/ratenode/calculators/states/nc.rb`

Remove or update the `TODO: FR-013` block at lines 12-28 since this fix addresses the issue.

### 3. Verify tests pass

```bash
bundle exec rspec spec/
```

Expected: All existing NC tests pass. The "liability equals prior" case produces the same result because the tiered rate on full liability equals `full_premium / multiplier`, so the math is equivalent.

### 4. Manual verification against spec example

```ruby
# In Rails console or test
calculator = RateNode::States::NC.new
result = calculator.calculate_owners_premium(
  liability_cents: 40_000_000,          # $400,000
  prior_policy_amount_cents: 25_000_000, # $250,000
  prior_policy_date: Date.today - 365,   # 1 year ago
  policy_type: :standard,
  underwriter: "DEFAULT",
  as_of_date: Date.today
)
# Expected: 62725 cents ($627.25)

discount = calculator.reissue_discount_amount(
  liability_cents: 40_000_000,
  prior_policy_amount_cents: 25_000_000,
  prior_policy_date: Date.today - 365,
  policy_type: :standard,
  underwriter: "DEFAULT",
  as_of_date: Date.today
)
# Expected: 30175 cents ($301.75)
```

### 5. Human task: Add CSV test scenarios

**File**: `spec/fixtures/scenarios_input.csv`

Add scenarios for partial-reissue cases. Expected values must be human-verified against NC rate manual.

| Scenario Name | Liability | Prior Amount | Expected Premium | Expected Discount |
|---------------|-----------|--------------|------------------|-------------------|
| NC_reissue_partial_400k_250k | $400,000 | $250,000 | $627.25 | $301.75 |
| NC_reissue_partial_homeowner | $400,000 | $250,000 | (with 1.2× multiplier) | (verify from manual) |

## Verification Commands

```bash
# Run all tests
bundle exec rspec

# Run NC-specific tests
bundle exec rspec spec/ --example "NC"

# Check for regressions in other states
bundle exec rspec spec/fixtures/scenarios_input.csv
```

## Files Changed Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `lib/ratenode/calculators/states/nc.rb` | MODIFY | Fix `calculate_reissue_discount()` to use tiered rate |
| `spec/fixtures/scenarios_input.csv` | HUMAN | Add partial-reissue test scenarios |
