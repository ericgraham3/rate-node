# Quickstart: State Calculator Plugin Architecture

**Branch**: `001-extract-state-calculators`
**Date**: 2026-02-03

## Overview

This guide explains how to work with the new state calculator plugin architecture after the refactor is complete.

## Using State Calculators

### Before (Old Pattern)
```ruby
# Direct instantiation - different classes per state
if state == "AZ"
  calculator = RateNode::AZCalculator.new(
    liability_cents: 50_000_000,
    policy_type: "standard",
    underwriter: "TRG",
    # ...many individual params
  )
  premium = calculator.calculate
else
  calculator = RateNode::OwnersPolicy.new(
    liability_cents: 50_000_000,
    state: state,
    # ...
  )
  premium = calculator.calculate
end
```

### After (New Pattern)
```ruby
# Factory routing - same interface for all states
calculator = RateNode::StateCalculatorFactory.for(state)
premium = calculator.calculate_owners_premium(
  liability_cents: 50_000_000,
  policy_type: "standard",
  underwriter: "TRG",
  transaction_type: "purchase",
  as_of_date: Date.today,
  # ...other params as needed
)
```

## Adding a New State

To add support for a new state (e.g., Colorado):

### Step 1: Add State Rules Configuration
Edit `lib/ratenode/state_rules.rb`:

```ruby
STATE_RULES = {
  # ...existing states...
  "CO" => {
    has_cpl: true,
    underwriters: {
      "DEFAULT" => {
        concurrent_base_fee_cents: 15_000,
        minimum_premium_cents: 50_000,
        # ...state-specific configuration
      }
    }
  }
}.freeze
```

### Step 2: Create Rate Data Seeds
Create `db/seeds/data/co_rates.rb`:

```ruby
# Colorado rate tiers
CO_RATE_TIERS = [
  { min: 0, max: 10_000_000, rate_per_thousand: 500 },
  { min: 10_000_000, max: Float::INFINITY, rate_per_thousand: 400 }
].freeze
```

### Step 3: Create State Calculator
Create `lib/ratenode/calculators/states/co.rb`:

```ruby
# frozen_string_literal: true

module RateNode
  module States
    class CO < BaseStateCalculator
      def calculate_owners_premium(params)
        liability = params[:liability_cents]
        policy_type = params[:policy_type]
        underwriter = params[:underwriter]
        as_of_date = params[:as_of_date]

        # Get state rules
        rules = rules_for("CO", underwriter: underwriter)

        # Calculate base rate using tier lookup utility
        tiers = load_rate_tiers(as_of_date)
        base_premium = tier_lookup.calculate_tiered_rate(liability, tiers)

        # Apply policy type multiplier
        multiplier = PolicyType.multiplier_for(policy_type, state: "CO", underwriter: underwriter)
        premium = (base_premium * multiplier).to_i

        # Apply minimum
        [premium, rules[:minimum_premium_cents]].max
      end

      def calculate_lenders_premium(params)
        # CO-specific lender calculation
        # ...
      end

      private

      def load_rate_tiers(as_of_date)
        RateTier.tiers_for(state: "CO", as_of_date: as_of_date)
      end
    end
  end
end
```

### Step 4: Register in Factory
Edit `lib/ratenode/calculators/state_calculator_factory.rb`:

```ruby
SUPPORTED_STATES = %w[AZ FL CA TX NC CO].freeze  # Add CO

def build_calculator(state)
  case state
  # ...existing states...
  when "CO" then States::CO.new
  else
    raise UnsupportedStateError, "..."
  end
end
```

### Step 5: Add Test Scenarios (Human Task)
Add rows to `spec/fixtures/scenarios_input.csv` with expected premiums.

> **Note**: Per Constitution Principle V, only humans should add test scenarios.
> Agents may propose scenario types but not actual values.

## Using Shared Utilities

### Rounding
```ruby
# Round up to next $5,000 increment
rounded = Utilities::Rounding.round_up(48_750_000, 500_000)
# => 49_000_000 ($490,000)

# Round to nearest $10,000
rounded = Utilities::Rounding.round_to_nearest(48_750_000, 1_000_000)
# => 49_000_000

# No rounding (TX style)
exact = Utilities::Rounding.round_up(48_750_000, nil)
# => 48_750_000 (unchanged)
```

### Tier Lookup
```ruby
# Tiered rate calculation (FL/NC style)
tiers = [
  { min: 0, max: 10_000_000, rate_per_thousand: 575 },
  { min: 10_000_000, max: 50_000_000, rate_per_thousand: 450 }
]
premium = Utilities::TierLookup.calculate_tiered_rate(25_000_000, tiers)
# => 125_000 ($1,250)

# Bracket lookup (CA style)
bracket = Utilities::TierLookup.find_bracket(25_000_000, tiers)
# => { min: 10_000_000, max: 50_000_000, rate_per_thousand: 450 }
```

## State-Specific Features

### Arizona (AZ)
```ruby
calculator = StateCalculatorFactory.for("AZ")

# Standard calculation
premium = calculator.calculate_owners_premium(
  liability_cents: 50_000_000,
  policy_type: "standard",
  underwriter: "TRG",  # or "ORT"
  county: "Maricopa",
  as_of_date: Date.today
)

# Hold-open calculation
initial_premium = calculator.calculate_owners_premium(
  liability_cents: 50_000_000,
  is_hold_open: true,
  hold_open_phase: "initial",
  # ...
)

final_premium = calculator.calculate_owners_premium(
  liability_cents: 60_000_000,  # Increased liability
  prior_policy_amount_cents: 50_000_000,
  is_hold_open: true,
  hold_open_phase: "final",
  # ...
)
```

### Florida (FL)
```ruby
calculator = StateCalculatorFactory.for("FL")

# Reissue rate calculation (uses split rate table)
premium = calculator.calculate_owners_premium(
  liability_cents: 50_000_000,
  prior_policy_amount_cents: 30_000_000,
  prior_policy_date: Date.today - 365,
  # ...
)
```

### North Carolina (NC)
```ruby
calculator = StateCalculatorFactory.for("NC")

# Reissue discount (percentage-based, not rate table)
premium = calculator.calculate_owners_premium(
  liability_cents: 50_000_000,
  prior_policy_amount_cents: 30_000_000,
  prior_policy_date: Date.today - 365,
  # ...
)
# Note: NC reissue bug documented - see FR-013
```

## Running Tests

```bash
# Run all scenario tests
bundle exec rspec spec/integration/csv_scenarios_spec.rb

# Run specific state scenarios (filter by state in CSV)
bundle exec rspec spec/integration/csv_scenarios_spec.rb --tag az

# Run unit tests for new components
bundle exec rspec spec/unit/
```

## Architecture Principles

1. **State Isolation**: Each state has its own calculator file. Changes to FL cannot affect TX.
2. **Contract-First**: All calculators implement `BaseStateCalculator` methods.
3. **Stateless Singletons**: Calculators have no instance state; factory caches instances.
4. **Prove Before Extracting**: Shared utilities only contain proven patterns (rounding, tier lookup).
5. **Configuration Over Conditionals**: State rules in `state_rules.rb`, not case statements.
