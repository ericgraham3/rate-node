# Contracts: Fix NC Rate Configuration

**Feature**: 004-fix-nc-config
**Date**: 2026-02-05

## Overview

This feature is configuration-only and does not introduce or modify any API contracts. The existing interfaces remain unchanged:

- `StateCalculator.for(state, params)` — unchanged
- `RateNode.rules_for(state, underwriter:)` — unchanged
- `PolicyType.multiplier_for(type, state:, underwriter:)` — unchanged
- `Endorsement.find_by_code(state:, code:, ...)` — unchanged

## Configuration Contracts

### NC Endorsement Catalogue

After implementation, the NC endorsement catalogue MUST satisfy:

```ruby
# Contract: NC endorsements
endorsements = RateNode::Models::Endorsement.all(state: "NC")

# Invariant 1: Exactly 3 endorsements
endorsements.count == 3

# Invariant 2: All are flat-priced at $23.00
endorsements.all? { |e| e[:pricing_type] == "flat" && e[:base_amount_cents] == 2300 }

# Invariant 3: Only valid codes exist
endorsements.map { |e| e[:code] }.sort == ["ALTA 5", "ALTA 8.1", "ALTA 9"]
```

### Policy Type Multipliers

After implementation, policy type lookups MUST satisfy:

```ruby
# Contract: homeowners multiplier exists for all states
%w[NC CA FL TX AZ].each do |state|
  multiplier = RateNode::Models::PolicyType.multiplier_for(:homeowners, state: state)

  # Invariant: Returns a number, not nil or 1.0 fallback
  multiplier.is_a?(Numeric) && multiplier != 1.0
end

# Expected values:
# NC: 1.20
# CA: 1.10
# FL: 1.10
# TX: 1.10
# AZ: 1.10
```

### NC State Rules

After implementation, NC state rules MUST satisfy:

```ruby
# Contract: NC rules
rules = RateNode.rules_for("NC")

# Invariant 1: Minimum premium is $56.00
rules[:minimum_premium_cents] == 5600

# Invariant 2: Rounding increment is $1,000
rules[:rounding_increment_cents] == 100_000

# Invariant 3: Policy type multipliers use :homeowners key
rules[:policy_type_multipliers].key?(:homeowners)
rules[:policy_type_multipliers][:homeowners] == 1.20
```

## Test Contracts

### CSV Scenario Tests

The following contract MUST hold after all changes:

```bash
# All existing CSV tests pass without modification to the fixture file
bundle exec rspec spec/csv_scenarios_spec.rb
# Exit code: 0
# Failures: 0
```

The CSV fixture file (`spec/fixtures/scenarios_input.csv`) MUST NOT be modified.
