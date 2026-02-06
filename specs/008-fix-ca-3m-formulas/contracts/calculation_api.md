# Calculation API Contract

**Feature**: 008-fix-ca-3m-formulas
**Date**: 2026-02-05
**Phase**: 1 - Design

## Overview

This contract defines the API for CA premium calculation methods that will be modified or added to support underwriter-specific over-$3M formulas, minimum premiums, and refinance caps.

---

## Method: `RateTier.calculate_over_3m_rate`

### Purpose
Calculate owner's premium for liability amounts > $3,000,000 using underwriter-specific formulas.

### Signature
```ruby
def self.calculate_over_3m_rate(liability_cents, state:, underwriter:)
```

### Parameters

| Name | Type | Required | Description | Constraints |
|------|------|----------|-------------|-------------|
| `liability_cents` | Integer | Yes | Policy liability amount in cents | Must be > 300_000_000 |
| `state` | String | Yes | State code | Must be "CA" for this formula |
| `underwriter` | String | Yes | Underwriter code | Must be "TRG" or "ORT" |

### Returns
- **Type**: Integer
- **Unit**: cents
- **Description**: Calculated owner's premium for amounts > $3M

### Algorithm
```ruby
rules = RateNode.rules_for(state, underwriter: underwriter)
base = rules[:over_3m_base_cents]
rate_per_10k = rules[:over_3m_per_10k_cents]

excess_cents = liability_cents - 300_000_000
increments = (excess_cents / 1_000_000.0).ceil

base + (increments * rate_per_10k)
```

### Examples

**TRG at $3.5M:**
```ruby
RateTier.calculate_over_3m_rate(350_000_000, state: "CA", underwriter: "TRG")
# => 447_350 ($4,473.50)
# Calculation: $4,211 + (50 × $5.25) = $4,211 + $262.50 = $4,473.50
```

**ORT at $5M:**
```ruby
RateTier.calculate_over_3m_rate(500_000_000, state: "CA", underwriter: "ORT")
# => 563_800 ($5,638)
# Calculation: $4,438 + (200 × $6.00) = $4,438 + $1,200 = $5,638
```

### Error Conditions
- Raises `Error` if underwriter parameters not found in state_rules.rb
- Returns incorrect result if `liability_cents <= 300_000_000` (caller should use tier lookup instead)

### Side Effects
None - pure function

### Changes from Current Implementation
- **BREAKING CHANGE**: Removes hardcoded `OVER_3M_BASE_CENTS` and `OVER_3M_PER_10K_CENTS` constants
- **NEW PARAMETER**: Adds `underwriter` parameter for formula selection
- **NEW DEPENDENCY**: Requires state_rules.rb configuration

---

## Method: `RateTier.calculate_elc_over_3m_rate`

### Purpose
Calculate Extended Lender Concurrent (ELC) premium for liability amounts > $3,000,000 using underwriter-specific formulas.

### Signature
```ruby
def self.calculate_elc_over_3m_rate(liability_cents, state:, underwriter:)
```

### Parameters

| Name | Type | Required | Description | Constraints |
|------|------|----------|-------------|-------------|
| `liability_cents` | Integer | Yes | Loan amount in cents | Must be > 300_000_000 |
| `state` | String | Yes | State code | Must be "CA" for this formula |
| `underwriter` | String | Yes | Underwriter code | Must be "TRG" or "ORT" |

### Returns
- **Type**: Integer
- **Unit**: cents
- **Description**: Calculated ELC premium for amounts > $3M

### Algorithm
```ruby
rules = RateNode.rules_for(state, underwriter: underwriter)
base = rules[:elc_over_3m_base_cents]
rate_per_10k = rules[:elc_over_3m_per_10k_cents]

excess_cents = liability_cents - 300_000_000
increments = (excess_cents / 1_000_000.0).ceil

base + (increments * rate_per_10k)
```

### Examples

**TRG at $3.5M:**
```ruby
RateTier.calculate_elc_over_3m_rate(350_000_000, state: "CA", underwriter: "TRG")
# => 268_200 ($2,682)
# Calculation: $2,472 + (50 × $4.20) = $2,472 + $210 = $2,682
```

**ORT at $3.5M:**
```ruby
RateTier.calculate_elc_over_3m_rate(350_000_000, state: "CA", underwriter: "ORT")
# => 270_000 ($2,700)
# Calculation: $2,550 + (50 × $3.00) = $2,550 + $150 = $2,700
```

### Error Conditions
- Raises `Error` if underwriter parameters not found in state_rules.rb
- Returns incorrect result if `liability_cents <= 300_000_000` (caller should use tier lookup instead)

### Side Effects
None - pure function

### Changes from Current Implementation
- **CRITICAL FIX**: Replaces hardcoded `75 + (increments * 75)` which produces cents instead of dollars
- **NEW PARAMETER**: Adds `underwriter` parameter for formula selection
- **NEW DEPENDENCY**: Requires state_rules.rb configuration
- **RENAMED**: From `calculate_elc_over_3m` to `calculate_elc_over_3m_rate` for consistency

---

## Method: `CA.calculate_standard` (modified)

### Purpose
Calculate standard owner's premium with minimum premium enforcement.

### Signature
```ruby
def calculate_standard
```

### Parameters
Uses instance variables:
- `@liability_cents` - Policy liability amount
- `@policy_type` - Policy type (:standard, :homeowners, :extended)
- `@underwriter` - Underwriter code
- `@as_of_date` - Effective date for rate lookup

### Returns
- **Type**: Integer
- **Unit**: cents
- **Description**: Owner's premium with minimum enforcement and policy type multiplier applied

### Algorithm
```ruby
# 1. Calculate base rate (tier or formula)
base_rate = lookup_base_rate(@liability_cents)

# 2. Apply minimum premium
rules = state_rules
minimum = rules[:minimum_premium_cents] || 0
base_rate = [base_rate, minimum].max

# 3. Apply policy type multiplier
multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "CA", underwriter: @underwriter, as_of_date: @as_of_date)
(base_rate * multiplier).round
```

### Examples

**TRG at $10K (below minimum):**
```ruby
# Assume tier lookup returns $200
# Instance vars: @liability_cents = 1_000_000, @policy_type = :standard, @underwriter = "TRG"
calculate_standard
# => 60_900 ($609)
# Calculation: MAX($200, $609) × 1.00 = $609
```

**ORT at $500K (above minimum):**
```ruby
# Assume tier lookup returns $1,600
# Instance vars: @liability_cents = 50_000_000, @policy_type = :standard, @underwriter = "ORT"
calculate_standard
# => 160_000 ($1,600)
# Calculation: MAX($1,600, $725) × 1.00 = $1,600
```

**TRG at $3.5M with homeowners multiplier:**
```ruby
# Over-$3M formula returns $4,473.50
# Instance vars: @liability_cents = 350_000_000, @policy_type = :homeowners, @underwriter = "TRG"
calculate_standard
# => 492_085 ($4,920.85)
# Calculation: MAX($4,473.50, $609) × 1.10 = $4,473.50 × 1.10 = $4,920.85
```

### Error Conditions
None - uses existing error handling from lookup_base_rate

### Side Effects
None - reads instance variables, returns calculated value

### Changes from Current Implementation
- **NEW**: Adds minimum premium enforcement between base rate calculation and multiplier
- **PRESERVES**: Existing logic for base_rate lookup and multiplier application

---

## Method: `BaseRate.calculate_elc` (call-site modification)

### Purpose
Calculate Extended Lender Concurrent rate (wrapper method, delegates to RateTier).

### Current Signature (unchanged)
```ruby
def calculate_elc
```

### Internal Changes
Must pass `underwriter` parameter to `RateTier.calculate_elc_over_3m_rate`:

```ruby
def calculate_elc
  if @liability_cents > 300_000_000
    # OLD: RateTier.calculate_elc_over_3m(@liability_cents)
    # NEW:
    RateTier.calculate_elc_over_3m_rate(@liability_cents, state: @state, underwriter: @underwriter)
  else
    # Tier lookup (unchanged)
    RateTier.calculate_extended_lender_concurrent_rate(@liability_cents, state: @state, underwriter: @underwriter, as_of_date: @as_of_date)
  end
end
```

### No Public API Changes
External callers see no difference - method signature and return type unchanged.

---

## Method: `RefinanceRate.calculate_rate` (optional enhancement)

### Purpose
Calculate refinance premium with support for over-$10M formulas.

### Signature
```ruby
def self.calculate_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
```

### Current Implementation
Only uses tier lookups and has over-$5M formula (not CA-specific).

### Proposed Enhancement
Add CA-specific over-$10M logic:

```ruby
def self.calculate_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
  # CA-specific over-$10M formula
  if state == "CA" && liability_cents > 1_000_000_000
    return calculate_ca_over_10m_refinance(liability_cents, underwriter: underwriter)
  end

  # Existing logic for other states/amounts
  # ...
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

### Examples

**TRG at $12M:**
```ruby
RefinanceRate.calculate_rate(1_200_000_000, state: "CA", underwriter: "TRG")
# => 880_000 ($8,800)
# Calculation: $7,200 + (2 × $800) = $8,800
```

**ORT at $15M:**
```ruby
RefinanceRate.calculate_rate(1_500_000_000, state: "CA", underwriter: "ORT")
# => 1_261_000 ($12,610)
# Calculation: $7,610 + (5 × $1,000) = $12,610
```

### Optional
This enhancement is listed as P3 priority in User Story 4. May be deferred if refinance workflow is not actively used.

---

## Boundary Condition Contracts

### At $3,000,000 (Tier vs Formula Threshold)

```ruby
# Use tier lookup
RateTier.calculate_rate(300_000_000, state: "CA", underwriter: "TRG")
# => 421_100 (from tier data, NOT formula)

# Use formula
RateTier.calculate_rate(300_000_001, state: "CA", underwriter: "TRG")
# => Uses calculate_over_3m_rate(300_000_001, ...)
```

### At $10,000,000 (Refinance Tier vs Formula Threshold)

```ruby
# Use tier lookup
RefinanceRate.calculate_rate(1_000_000_000, state: "CA", underwriter: "TRG")
# => 720_000 (from tier data, NOT formula)

# Use formula
RefinanceRate.calculate_rate(1_000_000_001, state: "CA", underwriter: "TRG")
# => Uses calculate_ca_over_10m_refinance(1_000_000_001, ...)
```

---

## Integration Points

### Call Graph

```
CA.calculate_owners_premium
  └─> CA.calculate_standard
      ├─> CA.lookup_base_rate
      │   └─> BaseRate.calculate
      │       └─> RateTier.calculate_rate
      │           └─> RateTier.calculate_over_3m_rate (NEW: underwriter param)
      │
      └─> Apply minimum_premium_cents (NEW)
      └─> Apply policy_type_multiplier (existing)

CA.calculate_lenders_premium
  └─> BaseRate.calculate_elc
      └─> RateTier.calculate_elc_over_3m_rate (RENAMED + underwriter param)
```

### State Rules Access

All methods access state rules via:
```ruby
rules = RateNode.rules_for(state, underwriter: underwriter)
```

This returns merged state-level + underwriter-level configuration.

---

## Backward Compatibility

### Breaking Changes (Internal Only)
- `RateTier.calculate_over_3m_rate` requires new `underwriter` parameter
- `RateTier.calculate_elc_over_3m` renamed to `calculate_elc_over_3m_rate` + requires `state`, `underwriter`

### Public API (Preserved)
- `CA.calculate_owners_premium(params)` - signature unchanged
- `CA.calculate_lenders_premium(params)` - signature unchanged
- All calculations still accept same input parameters

### Other States (Unaffected)
- AZ, FL, NC, TX do not call over-$3M or ELC methods
- No impact to non-CA calculation flows

---

## Testing Contract

### Unit Test Requirements

Each method must have unit tests covering:

1. **Happy path** - typical amounts with expected results
2. **Boundary conditions** - $3M, $3M+1, $10M, $10M+1
3. **Minimum enforcement** - amounts below minimum
4. **Both underwriters** - TRG and ORT produce different results
5. **Rounding** - verify proper integer rounding

### Integration Test Requirements (CSV Scenarios)

- Over-$3M owner premium (both underwriters)
- ELC above $3M (both underwriters)
- Minimum premium enforcement (both underwriters)
- Refinance over $10M (if implemented)
- All within $2.00 tolerance

### Success Criteria

From spec.md:
- SC-001: Premiums at $3.5M, $5M, $10M match manuals ±$2
- SC-002: ELC at $3.5M, $5M in thousands of dollars ±$2
- SC-003: Minimum exactly $609 (TRG) or $725 (ORT)
- SC-004: Refinance $12M = $8,800 TRG (if implemented)
- SC-005: Existing CSV tests pass ±$2
- SC-006: Existing CA unit tests pass

---

## Summary

- **3 modified methods**: `calculate_over_3m_rate`, `calculate_elc_over_3m_rate` (renamed), `calculate_standard`
- **1 call-site change**: `BaseRate.calculate_elc` passes underwriter
- **1 optional enhancement**: `RefinanceRate` over-$10M support
- **0 public API changes**: external callers unaffected
- **7 parameters per underwriter**: all sourced from state_rules.rb
