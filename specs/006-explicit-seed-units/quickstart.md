# Quickstart: Explicit Seed Unit Declaration

**Feature**: 006-explicit-seed-units | **Date**: 2026-02-05

## What This Change Does

Replaces the fragile auto-detection heuristic in the rate tier seeder with an explicit unit declaration in each state module.

**Before**: The seeder inspected the first tier's `min` value to guess whether data was in dollars or cents.

**After**: Each state module declares its unit explicitly (`RATE_TIERS_UNIT = :dollars` or `:cents`), and the seeder reads that declaration.

## Why This Matters

The old heuristic could silently misclassify a new state's data if its first tier fell in an ambiguous range, producing 100x errors in seeded rates. The new approach fails loudly if the declaration is missing, eliminating silent misclassification.

## Files Changed

| File | Change |
|------|--------|
| `db/seeds/data/nc_rates.rb` | Add `RATE_TIERS_UNIT = :dollars` |
| `db/seeds/data/ca_rates.rb` | Add `RATE_TIERS_UNIT = :dollars` |
| `db/seeds/data/tx_rates.rb` | Add `RATE_TIERS_UNIT = :cents` |
| `db/seeds/rates.rb` | Remove heuristic, read declaration, add error handling |

## How to Test

```bash
# Run the full test suite - all scenarios should pass unchanged
bundle exec rspec

# Optionally, reseed the database and verify manually
bin/ratenode db:seed
```

## Adding a New State to the Shared Seeder

If you add a new state that uses the shared `seed_rate_tiers()` method:

1. Determine the unit convention of your rate data (dollars or cents)
2. Add `RATE_TIERS_UNIT = :dollars` or `RATE_TIERS_UNIT = :cents` to your state module, **before** the `RATE_TIERS` definition
3. The seeder will read your declaration and apply the correct conversion

**Example** (hypothetical new state):

```ruby
module RateNode
  module Seeds
    module NY
      EFFECTIVE_DATE = Date.new(2026, 1, 1)
      STATE_CODE = "NY"
      UNDERWRITER_CODE = "TRG"

      # Declare unit BEFORE the rate tiers
      RATE_TIERS_UNIT = :dollars

      RATE_TIERS = [
        { min: 0, max: 100_000, rate: 500, per_thousand: nil, elc: 0 },
        # ...
      ].freeze
    end
  end
end
```

## Error Handling

If a state module is missing `RATE_TIERS_UNIT` or has an unrecognized value, the seeder will raise a clear error:

```
ArgumentError: RateNode::Seeds::NY::RATE_TIERS_UNIT must be declared (:dollars or :cents)
```

or

```
ArgumentError: RateNode::Seeds::NY::RATE_TIERS_UNIT must be :dollars or :cents, got :invalid
```

This prevents silent misclassification and makes the required fix obvious.
