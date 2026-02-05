# Research: Explicit Seed Unit Declaration

**Feature**: 006-explicit-seed-units | **Date**: 2026-02-05

## Current Implementation Analysis

### The Shared Seeder

**Location**: `/home/eric/rate-node/db/seeds/rates.rb`, lines 114-152

The `seed_rate_tiers(state, rate_type: nil)` method handles NC, CA, and TX rate tier seeding. It is called from:
- `seed_ca` (line 25)
- `seed_nc` (line 36)
- `seed_tx` (lines 48-49)

### The Fragile Heuristic (Line 118)

```ruby
already_in_cents = state::RATE_TIERS.first && state::RATE_TIERS.first[:min] >= 100_000
```

**How it works**:
- Inspects the first tier's `:min` value
- If `:min` >= 100,000, assumes data is in cents (TX)
- If `:min` < 100,000, assumes data is in dollars (NC, CA)

**Why it's fragile**:
- **Ambiguous range**: A dollar amount >= $1,000 (`:min` >= 1,000) but < $100,000 creates ambiguity. Is `min: 50_000` dollars ($50,000) or cents ($500)?
- **Silent misclassification**: If a new state's first tier falls in the ambiguous range, the heuristic guesses wrong and multiplies (or doesn't multiply) incorrectly, producing 100x errors in seeded rates.
- **No error path**: Missing or malformed data doesn't raise an error; it just picks a default interpretation.

### Current State Data Conventions

| State | First Tier Min | Unit | Correctly Detected? |
|-------|----------------|------|---------------------|
| NC | `min: 0` | Dollars | ✅ Yes (0 < 100,000) |
| CA | `min: 0` | Dollars | ✅ Yes (0 < 100,000) |
| TX | `min: 2_500_000` | Cents | ✅ Yes (2,500,000 >= 100,000) |

**Risk case**: A hypothetical state with `min: 50_000` in dollars ($50,000) would be misclassified as dollars by the heuristic, but the seeder would then multiply by 100, producing 5,000,000 cents ($50,000). This happens to be correct, but the reasoning is accidental, not intentional.

A more dangerous case: A state with `min: 100_000` in dollars ($100,000) would be misclassified as cents. The seeder would pass through unchanged, but the database would contain $100,000 when it should contain $10,000,000 cents.

### States Using Dedicated Seeders (Out of Scope)

- **FL**: Uses `seed_fl_rate_tiers(state)` (lines 70-112). Data is already in cents. Has separate `RATE_TIERS_ORIGINAL` and `RATE_TIERS_REISSUE` tables.
- **AZ**: Uses `seed_az_rate_tiers(state, rate_tiers, region: nil)` (lines 229-253). Data is already in cents. Has region-specific tables for TRG underwriter.

These states are out of scope because they already use dedicated seeders that don't rely on the heuristic.

## Decision: Explicit Unit Declaration

### Design Choice

Add a `RATE_TIERS_UNIT` constant to each state module that participates in the shared seeder:

```ruby
# In nc_rates.rb
RATE_TIERS_UNIT = :dollars

# In ca_rates.rb
RATE_TIERS_UNIT = :dollars

# In tx_rates.rb
RATE_TIERS_UNIT = :cents
```

### Rationale

1. **Co-location**: The declaration lives with the data it describes. A developer editing `RATE_TIERS` sees the unit declaration immediately.

2. **Explicitness**: No value inspection. The seeder reads the declared unit and applies the known conversion.

3. **Fail-fast**: If `RATE_TIERS_UNIT` is missing or contains an unrecognized value, the seeder raises an error. No silent defaults.

4. **Simplicity**: A single constant per state module. No inheritance, no base classes, no configuration files.

### Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Pass unit as parameter to `seed_rate_tiers()` | Declaration would be separated from data. Easy to forget to update one when changing the other. |
| Encode unit in data structure (e.g., `{ unit: :dollars, tiers: [...] }`) | Requires restructuring all state modules. Overkill for a one-time declaration. |
| Infer from constant name (e.g., `RATE_TIERS_DOLLARS`) | Requires renaming constants. Breaks existing code that references `RATE_TIERS`. |
| Add validation to detect mismatches | Heuristics compound; they don't eliminate. Validation adds complexity without removing the root cause. |

## Implementation Approach

### Step 1: Add Declarations to State Modules

Add `RATE_TIERS_UNIT = :dollars` to NC and CA modules, and `RATE_TIERS_UNIT = :cents` to TX module.

**Placement**: Immediately before the `RATE_TIERS` constant definition for maximum visibility.

### Step 2: Update Shared Seeder

Replace the heuristic with explicit unit reading:

```ruby
def self.seed_rate_tiers(state, rate_type: nil)
  # Read explicit unit declaration
  unless state.const_defined?(:RATE_TIERS_UNIT)
    raise ArgumentError, "#{state}::RATE_TIERS_UNIT must be declared (:dollars or :cents)"
  end

  unit = state::RATE_TIERS_UNIT
  unless [:dollars, :cents].include?(unit)
    raise ArgumentError, "#{state}::RATE_TIERS_UNIT must be :dollars or :cents, got #{unit.inspect}"
  end

  schedule_data = if unit == :cents
    # Data is already in cents (TX format)
    state::RATE_TIERS.map { |row| ... }
  else
    # Data is in dollars (CA/NC format) - convert to cents
    state::RATE_TIERS.map { |row| ... }
  end

  Models::RateTier.seed(schedule_data, ...)
end
```

### Step 3: Verify Zero Data Change

Run a before/after comparison:

1. Seed database with current code, export rate_tiers table
2. Apply changes, re-seed, export rate_tiers table
3. Diff the two exports

All rows must be identical.

### Step 4: Run Full Test Suite

```bash
bundle exec rspec
```

All CSV scenario tests must pass without modification.

## Validation Strategy

### Primary Validation

CSV scenario tests cover NC, CA, and TX rate calculations. If any seeded value changes, downstream premium calculations will produce different results and scenarios will fail.

### Secondary Validation

Direct database comparison before and after the change ensures no silent data drift.

### Edge Case Validation

Manually test error paths:
1. Remove `RATE_TIERS_UNIT` from a state module → expect clear error
2. Set `RATE_TIERS_UNIT = :invalid` → expect clear error

## Files to Modify

| File | Change |
|------|--------|
| `db/seeds/data/nc_rates.rb` | Add `RATE_TIERS_UNIT = :dollars` |
| `db/seeds/data/ca_rates.rb` | Add `RATE_TIERS_UNIT = :dollars` |
| `db/seeds/data/tx_rates.rb` | Add `RATE_TIERS_UNIT = :cents` |
| `db/seeds/rates.rb` | Remove heuristic, read `RATE_TIERS_UNIT`, add error handling |

## No New Dependencies

This change uses only Ruby's built-in constant definition and checking (`const_defined?`). No gems or external libraries are required.
