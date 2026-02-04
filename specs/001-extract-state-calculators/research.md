# Research: Extract State Calculators into Plugin Architecture

**Date**: 2026-02-03
**Branch**: `001-extract-state-calculators`

## Research Tasks Completed

### 1. Factory Pattern Implementation in Ruby

**Decision**: Use a class method with memoized singleton instances per state

**Rationale**:
- Ruby's class-level instance variables (`@calculators ||= {}`) provide clean memoization
- Thread-safe for single-threaded CLI usage (current project scope)
- Aligns with clarification: "Factory returns singleton/cached calculator per state (stateless)"

**Alternatives Considered**:
- Autoloader-based discovery: Too complex for 5 states; explicit registration is simpler
- Dependency injection container: Over-engineered for this project's scope
- New instance per call: Wasteful since calculators are stateless

**Pattern**:
```ruby
module RateNode
  class StateCalculatorFactory
    @calculators = {}

    def self.for(state_code)
      normalized = state_code.to_s.upcase
      @calculators[normalized] ||= build_calculator(normalized)
    end

    def self.build_calculator(state)
      case state
      when "AZ" then States::AZ.new
      when "FL" then States::FL.new
      # ...
      else raise UnsupportedStateError, "No calculator for state: #{state}"
      end
    end
  end
end
```

---

### 2. Abstract Contract Pattern in Ruby

**Decision**: Use a base class with abstract method stubs that raise `NotImplementedError`

**Rationale**:
- Ruby lacks interfaces; abstract base class is idiomatic
- Explicit errors at method call time provide clear developer feedback
- Subclasses must override required methods or fail immediately

**Alternatives Considered**:
- Duck typing with no base class: Loses discoverability; no contract documentation
- Module inclusion: Doesn't enforce implementation; more suitable for mixins
- Method signature validation gem: Adds dependency for little benefit

**Pattern**:
```ruby
module RateNode
  class BaseStateCalculator
    def calculate_owners_premium(params)
      raise NotImplementedError, "#{self.class} must implement #calculate_owners_premium"
    end

    def calculate_lenders_premium(params)
      raise NotImplementedError, "#{self.class} must implement #calculate_lenders_premium"
    end

    protected

    # Shared utility access (not shared logic)
    def rounding
      Utilities::Rounding
    end

    def tier_lookup
      Utilities::TierLookup
    end
  end
end
```

---

### 3. Rounding Utility Extraction

**Decision**: Extract rounding logic to `Utilities::Rounding` module with pure functions

**Rationale**:
- Rounding appears in 3+ places: `AZCalculator.rounded_liability`, `BaseRate.rounded_liability`, `RateTier` calculations
- Constitution Principle III permits extraction of "mathematical operations: rounding functions"
- Pure functions avoid state; safe for singleton calculators

**Current Implementations Found**:

| Location | Rounding Logic |
|----------|---------------|
| `AZCalculator` | `((liability / increment) + 1) * increment` for TRG ($5k) and ORT ($20k) |
| `BaseRate` | `((liability / 1_000_000) + 1) * 1_000_000` (default $10k), TX: no rounding |
| `RateTier` | Various tier-boundary rounding |

**Unified Interface**:
```ruby
module RateNode
  module Utilities
    module Rounding
      def self.round_up(amount_cents, increment_cents)
        return amount_cents if increment_cents.nil? || increment_cents.zero?
        ((amount_cents / increment_cents) + 1) * increment_cents
      end

      def self.round_to_nearest(amount_cents, increment_cents)
        return amount_cents if increment_cents.nil? || increment_cents.zero?
        ((amount_cents + (increment_cents / 2)) / increment_cents) * increment_cents
      end
    end
  end
end
```

---

### 4. Tier Lookup Utility Extraction

**Decision**: Extract tier lookup traversal to `Utilities::TierLookup` module

**Rationale**:
- Tier lookup algorithm is identical across states; only the rate data differs
- Constitution permits extraction of "generic algorithms: tier lookup traversal"
- Keep rate data in database; utility only handles traversal logic

**Current Implementation** (from `RateTier.calculate_tiered_rate`):
```ruby
def calculate_tiered_rate(liability_cents, tiers)
  remaining = liability_cents
  total = 0
  tiers.each do |tier|
    break if remaining <= 0
    tier_amount = [remaining, tier[:max] - tier[:min]].min
    total += (tier_amount / 100) * tier[:rate_per_thousand]
    remaining -= tier_amount
  end
  total
end
```

**Extracted Interface**:
```ruby
module RateNode
  module Utilities
    module TierLookup
      def self.calculate_tiered_rate(amount_cents, tiers)
        # Same logic, receives tiers as parameter
      end

      def self.find_bracket(amount_cents, tiers)
        # Single bracket lookup for states like CA
      end
    end
  end
end
```

---

### 5. State-Specific Logic Mapping

**Research Goal**: Map current scattered logic to target state calculators

| State | Current Location | Key Logic | Target Method |
|-------|-----------------|-----------|---------------|
| **AZ** | `az_calculator.rb` | Hold-open, TRG/ORT regions, rounding | `States::AZ#calculate_owners_premium` |
| **FL** | `owners_policy.rb` | Reissue rate table (split calculation) | `States::FL#calculate_owners_premium` |
| **CA** | `owners_policy.rb` | Simple calculation, $3M+ handling | `States::CA#calculate_owners_premium` |
| **TX** | `owners_policy.rb`, `rate_tier.rb` | Formula-based rates (>$100k), no rounding | `States::TX#calculate_owners_premium` |
| **NC** | `owners_policy.rb` | Percentage-based reissue discount (50%) | `States::NC#calculate_owners_premium` |

**Lenders Policy Logic**:

| State | Current Logic | Notes |
|-------|--------------|-------|
| AZ | Flat fee, concurrent uses ELC config | Move to `States::AZ#calculate_lenders_premium` |
| FL | Flat fee + excess rate when loan > owner | Move to `States::FL#calculate_lenders_premium` |
| CA | Same as FL | Move to `States::CA#calculate_lenders_premium` |
| TX | Same as FL | Move to `States::TX#calculate_lenders_premium` |
| NC | Always flat fee when concurrent | Move to `States::NC#calculate_lenders_premium` |

---

### 6. NC Reissue Rate Bug Investigation

**Research Goal**: Understand and document the NC reissue rate bug

**Finding**: The NC reissue discount calculation in `owners_policy.rb` applies a 50% discount:

```ruby
def calculate_reissue_discount
  base_rate = calculate_base_rate
  (base_rate * 0.50).to_i  # 50% discount
end
```

**Potential Issues Identified**:
1. Discount percentage may be hardcoded vs. configurable in `state_rules.rb`
2. Eligibility window check may use incorrect date logic
3. Discount may apply to wrong base (before vs. after policy type multiplier)

**Recommendation**: During extraction to `States::NC`:
1. Preserve current behavior (even if buggy) to pass existing tests
2. Add explicit TODO comment marking the bug location
3. Create separate issue/task for NC bug investigation after architecture ships

---

### 7. Parameter Object Structure

**Decision**: Use a hash with symbol keys for calculation inputs

**Rationale**:
- Ruby convention for options/params
- Aligns with clarification: "Single parameter object/hash containing all calculation inputs"
- Easy to extend without changing method signatures
- Works well with Ruby keyword argument splatting

**Standard Parameters** (across all states):
```ruby
{
  liability_cents: Integer,        # Policy liability amount in cents
  loan_amount_cents: Integer,      # Loan amount for lender's policy (may be nil)
  policy_type: String,             # "standard", "homeowners", "extended"
  underwriter: String,             # "TRG", "ORT", etc.
  transaction_type: String,        # "purchase", "refinance"
  as_of_date: Date,               # Effective date for rate lookup
  prior_policy_amount_cents: Integer, # For reissue calculations (may be nil)
  prior_policy_date: Date,         # For reissue eligibility (may be nil)
  county: String,                  # For AZ region/area lookup (may be nil)
  concurrent: Boolean,             # Owner + lender concurrent issue
  is_hold_open: Boolean,           # AZ hold-open transaction
  hold_open_phase: String          # "initial" or "final" for AZ hold-open
}
```

---

## Summary: No Blocking Unknowns

All technical questions have been resolved:
- Factory pattern: Class method with memoized singletons
- Abstract contract: Base class with `NotImplementedError` stubs
- Utilities: Pure function modules for rounding and tier lookup
- Parameter passing: Hash with symbol keys
- NC bug: Document and defer to post-refactor task

**Ready for Phase 1: Design & Contracts**
