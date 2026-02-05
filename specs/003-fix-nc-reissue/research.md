# Research: NC Reissue Discount Calculation

**Feature**: 003-fix-nc-reissue | **Date**: 2026-02-04

## Bug Analysis

### Current Implementation (Buggy)

**File**: `lib/ratenode/calculators/states/nc.rb:152-171`

```ruby
def calculate_reissue_discount(full_premium)
  return 0 unless eligible_for_reissue_discount?

  discount_percent = state_rules[:reissue_discount_percent]
  discountable_portion_cents = [@liability_cents, @prior_policy_amount_cents].min

  discountable_base_rate = if discountable_portion_cents == @liability_cents
                               full_premium
                             else
                               # BUG: Linear proportional approximation
                               (full_premium * discountable_portion_cents.to_f / @liability_cents).round
                             end

  (discountable_base_rate * discount_percent).round
end
```

### Why Proportional Scaling Is Wrong

NC uses **tiered per-thousand rates**, not a flat rate. Each bracket has a different per-unit cost:

| Liability Range | Per $1,000 |
|-----------------|------------|
| $0 – $100,000 | $2.78 |
| $100,001 – $500,000 | $2.17 |
| $500,001 – $2,000,000 | $1.41 |
| $2,000,001 – $7,000,000 | $1.08 |
| $7,000,001+ | $0.75 |

When liability ($400,000) differs from prior policy amount ($250,000), the proportional shortcut:

```
discount_base = full_premium × (250k / 400k)
```

This assumes every dollar of coverage costs the same, which is false. The first $100k costs $2.78/k, the next $150k costs $2.17/k—the average cost per dollar decreases as liability increases.

### Correct Formula

**Reissue Discount = Tiered Rate on Discountable Portion × Discount % × Policy Type Multiplier**

Where:
- **Discountable Portion** = MIN(current liability, prior policy amount)
- **Tiered Rate** = `RateTier.calculate_rate(discountable_portion_cents, ...)`
- **Discount %** = `state_rules[:reissue_discount_percent]` (currently 0.50)
- **Policy Type Multiplier** = `PolicyType.multiplier_for(@policy_type, ...)`

### Worked Example (from spec)

**Inputs**: Liability $400,000, Prior policy $250,000, Policy type Standard (1.0)

**Step 1**: Discountable portion = MIN($400,000, $250,000) = $250,000

**Step 2**: Tiered rate on $250,000
- First $100,000 @ $2.78/k = $278.00
- Next $150,000 @ $2.17/k = $325.50
- **Total**: $603.50

**Step 3**: Apply policy type multiplier (1.0 for standard)
- Discountable base = $603.50 × 1.0 = $603.50

**Step 4**: Apply discount percentage (50%)
- **Reissue discount** = $603.50 × 0.50 = **$301.75**

**Step 5**: Full premium on $400,000
- First $100,000 @ $2.78/k = $278.00
- Next $300,000 @ $2.17/k = $651.00
- **Total**: $929.00 × 1.0 = $929.00

**Step 6**: Net premium
- **Final premium** = $929.00 − $301.75 = **$627.25** ✓

### Buggy Calculation (for comparison)

Using the current proportional approximation:
- Full premium: $929.00
- Proportional discount base: $929.00 × (250,000 / 400,000) = $580.63
- Discount: $580.63 × 0.50 = $290.31
- Final: $929.00 − $290.31 = **$638.69** ✗ (off by $11.44)

## Decisions

### Decision 1: Reuse `RateTier.calculate_rate()` for discountable portion

**Decision**: Call `Models::RateTier.calculate_rate()` with `discountable_portion_cents` to get the true tiered rate.

**Rationale**: This method already exists and correctly sums charges across all applicable brackets. No new calculation logic needed.

**Alternatives considered**:
- Inline the tiered calculation in NC: Rejected — duplicates existing, tested logic
- Pass a "discount mode" flag to `BaseRate.new()`: Rejected — overcomplicates the interface

### Decision 2: Apply policy type multiplier to discount

**Decision**: Multiply the tiered rate on discountable portion by the policy type multiplier before applying the discount percentage.

**Rationale**: The discount represents "credit for previously paid premium." If a homeowner's policy (1.2× multiplier) was previously purchased, the prior payment was also at that multiplier. The discount should reflect what was actually paid.

**Formula**: `discount = tiered_rate_on_discountable × multiplier × discount_percent`

**Alternatives considered**:
- Apply multiplier only to full premium, not discount: Rejected — creates inconsistency where discount doesn't match what was paid
- Ignore multiplier entirely in discount: Rejected — same reason

### Decision 3: Keep discount percentage configurable

**Decision**: Continue sourcing discount percentage from `state_rules[:reissue_discount_percent]`.

**Rationale**: FR-004 requires the percentage remain configurable. Currently 50% for NC, but may change with rate manual updates.

## Implementation Path

1. Modify `calculate_reissue_discount()` in `nc.rb`
2. Replace proportional approximation with `RateTier.calculate_rate(discountable_portion_cents, ...)`
3. Apply policy type multiplier to the tiered rate before discount percentage
4. Verify `reissue_discount_amount()` public method uses same logic (it calls `calculate_reissue_discount()`)
5. Run existing tests — the "liability equals prior" case should remain unchanged
6. **Human task**: Add CSV scenarios for partial-reissue cases with verified expected values
