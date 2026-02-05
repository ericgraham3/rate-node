# Contracts

No new API contracts for this feature. The existing `BaseStateCalculator` contract and public methods remain unchanged.

## Existing Contracts (Unchanged)

### NC#calculate_owners_premium

```ruby
# @param params [Hash]
# @option params [Integer] :liability_cents (required)
# @option params [Symbol] :policy_type (:standard, :homeowner, :extended)
# @option params [String] :underwriter (required)
# @option params [Date] :as_of_date
# @option params [Integer] :prior_policy_amount_cents (optional, for reissue)
# @option params [Date] :prior_policy_date (optional, for reissue)
# @return [Integer] Premium in cents
```

### NC#reissue_discount_amount

```ruby
# @param params [Hash] Same as calculate_owners_premium
# @return [Integer] Discount amount in cents
```

## Internal Methods (Modified)

### NC#calculate_reissue_discount (private)

**Before**: Used proportional approximation based on full premium ratio.

**After**: Calculates tiered rate on discountable portion using `RateTier.calculate_rate()`.

```ruby
# @param full_premium [Integer] Full premium in cents (unused after fix, kept for signature)
# @return [Integer] Discount amount in cents
#
# Formula: tiered_rate(discountable_portion) * policy_type_multiplier * discount_percent
```
