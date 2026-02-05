# Quickstart: Fix NC Rate Configuration

**Feature**: 004-fix-nc-config
**Date**: 2026-02-05

## Prerequisites

- Ruby 3.4.8
- Bundler installed (`gem install bundler`)
- SQLite3 available

## Setup

```bash
# Clone and enter repo
cd /home/eric/rate-node

# Install dependencies
bundle install

# Initialize database and seed
bundle exec rake db:migrate
bundle exec rake db:seed
```

## Verification Commands

### 1. Run all CSV scenario tests

```bash
bundle exec rspec spec/csv_scenarios_spec.rb
```

**Expected**: All tests pass (including AZ tests using `homeowners`).

### 2. Verify NC endorsement count

```bash
bundle exec ruby -e "
  require_relative 'lib/ratenode'
  RateNode::Models::Endorsement.all(state: 'NC').each do |e|
    puts \"#{e[:code]}: #{e[:pricing_type]} - $#{e[:base_amount_cents] / 100.0}\"
  end
"
```

**Expected output**:
```
ALTA 5: flat - $23.0
ALTA 8.1: flat - $23.0
ALTA 9: flat - $23.0
```

### 3. Verify policy type multiplier lookup

```bash
bundle exec ruby -e "
  require_relative 'lib/ratenode'
  %w[NC CA FL TX AZ].each do |state|
    mult = RateNode::Models::PolicyType.multiplier_for(:homeowners, state: state)
    puts \"#{state}: homeowners → #{mult}\"
  end
"
```

**Expected output**:
```
NC: homeowners → 1.2
CA: homeowners → 1.1
FL: homeowners → 1.1
TX: homeowners → 1.1
AZ: homeowners → 1.1
```

### 4. Verify NC state rules

```bash
bundle exec ruby -e "
  require_relative 'lib/ratenode'
  rules = RateNode.rules_for('NC')
  puts \"minimum_premium_cents: #{rules[:minimum_premium_cents]}\"
  puts \"rounding_increment_cents: #{rules[:rounding_increment_cents]}\"
  puts \"policy_type_multipliers: #{rules[:policy_type_multipliers]}\"
"
```

**Expected output**:
```
minimum_premium_cents: 5600
rounding_increment_cents: 100000
policy_type_multipliers: {:standard=>1.0, :homeowners=>1.2, :extended=>1.2}
```

## Test Scenarios

### Existing tests (must pass unchanged)

| Scenario | Liability | Expected Impact |
|----------|-----------|-----------------|
| NC_purchase_loan_reissue | $500,000 | Unaffected (above minimum/rounding thresholds) |
| NC_purchase_loan | $500,000 | Unaffected |
| NC_purchase_cash | $500,000 | Unaffected |
| AZ_Maricopa_Homeowners_* | $480,000-$500,000 | Uses `homeowners` — must pass |

### New test scenarios (require human expected values)

Per FR-007 and Principle V, the following scenarios require human-provided expected values before implementation:

| Scenario | Liability | Purpose | Expected Value |
|----------|-----------|---------|----------------|
| NC_minimum_premium_edge | ~$10,000 | Verify $56 minimum applies | (from rate manual) |
| NC_rounding_1000 | $105,500 | Verify rounds to $106,000 | (from rate manual) |
| NC_rounding_exact | $106,000 | Verify exact multiples unchanged | (from rate manual) |

**Note**: Agents MUST NOT provide expected values for these scenarios. A human must calculate expected premiums from the NC rate manual before these tests can be added.

## Error Conditions

### Removed endorsement requested

```ruby
# This should raise an error (not return $0 or nil)
RateNode::Models::Endorsement.find_by_code(state: "NC", code: "ALTA 17")
# → nil (caller must handle as error)
```

### Invalid policy type requested

```ruby
# Old identifier should not return 1.0 fallback
RateNode::Models::PolicyType.multiplier_for(:homeowner, state: "NC")
# → Expected: nil or error (unrecognized type)
# → Current behavior TBD — may need separate fix
```

## Files Modified

| File | Change |
|------|--------|
| `lib/ratenode/state_rules.rb` | NC: minimum_premium_cents, rounding_increment_cents; All states: `:homeowner` → `:homeowners` |
| `lib/ratenode/models/policy_type.rb` | TYPES, NC_TYPES: `:homeowner` → `:homeowners` |
| `lib/ratenode/calculators/states/ca.rb` | `format_policy_type`: `:homeowner` → `:homeowners` |
| `lib/ratenode/calculators/states/fl.rb` | `format_policy_type`: `:homeowner` → `:homeowners` |
| `lib/ratenode/calculators/states/nc.rb` | `format_policy_type`: `:homeowner` → `:homeowners` |
| `lib/ratenode/calculators/states/tx.rb` | `format_policy_type`: `:homeowner` → `:homeowners` |
| `db/seeds/data/nc_rates.rb` | ENDORSEMENTS: 46 entries → 3 entries |
