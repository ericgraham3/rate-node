# Data Model: CA Over-$3M Formulas

**Feature**: 008-fix-ca-3m-formulas
**Date**: 2026-02-05
**Phase**: 1 - Design

## Overview

This feature does NOT introduce new entities or database schema changes. Instead, it adds configuration parameters to existing state rules and modifies calculation logic to use these parameters at runtime.

---

## Configuration Entity: State Rules

**File**: `lib/ratenode/state_rules.rb`

### CA Underwriter Configuration Structure

```ruby
STATE_RULES = {
  "CA" => {
    # State-level keys (unchanged)
    has_cpl: true,
    cpl_flat_fee_cents: 0,
    supports_property_type: false,

    underwriters: {
      "TRG" => {
        # EXISTING CONFIGURATION (preserved)
        concurrent_base_fee_cents: 15_000,
        concurrent_uses_elc: true,
        reissue_discount_percent: 0.0,
        # ... (other existing fields)

        # NEW CONFIGURATION (to be added)
        minimum_premium_cents: 60_900,                      # $609
        over_3m_base_cents: 421_100,                        # $4,211
        over_3m_per_10k_cents: 525,                         # $5.25 per $10K
        elc_over_3m_base_cents: 247_200,                    # $2,472
        elc_over_3m_per_10k_cents: 420,                     # $4.20 per $10K
        refinance_over_10m_base_cents: 720_000,             # $7,200
        refinance_over_10m_per_million_cents: 80_000        # $800 per million
      },
      "ORT" => {
        # EXISTING CONFIGURATION (preserved)
        concurrent_base_fee_cents: 15_000,
        concurrent_uses_elc: true,
        # ... (other existing fields)

        # NEW CONFIGURATION (to be added)
        minimum_premium_cents: 72_500,                      # $725
        over_3m_base_cents: 443_800,                        # $4,438
        over_3m_per_10k_cents: 600,                         # $6.00 per $10K
        elc_over_3m_base_cents: 255_000,                    # $2,550
        elc_over_3m_per_10k_cents: 300,                     # $3.00 per $10K
        refinance_over_10m_base_cents: 761_000,             # $7,610
        refinance_over_10m_per_million_cents: 100_000       # $1,000 per million
      }
    }
  }
}
```

### Field Definitions

| Field Name | Type | Unit | Description | Validation Rules |
|-----------|------|------|-------------|------------------|
| `minimum_premium_cents` | Integer | cents | Minimum premium floor for owner's policy | >= 0 |
| `over_3m_base_cents` | Integer | cents | Base premium at $3M for owner's policy | > 0 |
| `over_3m_per_10k_cents` | Integer | cents | Incremental charge per $10K over $3M | > 0 |
| `elc_over_3m_base_cents` | Integer | cents | ELC base premium at $3M | > 0 |
| `elc_over_3m_per_10k_cents` | Integer | cents | ELC incremental charge per $10K over $3M | > 0 |
| `refinance_over_10m_base_cents` | Integer | cents | Refinance base premium at $10M | > 0 |
| `refinance_over_10m_per_million_cents` | Integer | cents | Refinance incremental charge per $1M over $10M | > 0 |

### Access Pattern

```ruby
rules = RateNode.rules_for("CA", underwriter: "TRG")

# Access configuration
minimum = rules[:minimum_premium_cents]              # 60_900
base_3m = rules[:over_3m_base_cents]                 # 421_100
per_10k = rules[:over_3m_per_10k_cents]              # 525
```

### Data Source

**Manual References:**
- TRG parameters: `docs/rate_manuals/ca/CA_TRG_rate_summary.md`
  - Minimum: line 36 ($609)
  - Over-$3M: line 65 ($5.25 per $10K)
  - ELC over-$3M: Clarification (April 2026) - $2,472 base + $4.20 per $10K
  - Refinance over-$10M: line 298 ($800 per million)

- ORT parameters: `docs/rate_manuals/ca/CA_ORT_rate_summary.md`
  - Minimum: line 37 ($725)
  - Over-$3M: line 75 ($6 per $10K)
  - ELC over-$3M: line 327 ($3 per $10K)
  - Refinance over-$10M: Section 2.3 max at $10M (formula inferred)

---

## Calculation Model: Premium Calculation Pipeline

### 1. Owner's Premium Calculation Flow

```
Input:
  - liability_cents: Integer
  - policy_type: Symbol (:standard, :homeowners, :extended)
  - underwriter: String ("TRG", "ORT")
  - is_hold_open: Boolean (optional)
  - prior_policy_amount_cents: Integer (optional)

Pipeline:
  1. Calculate base rate
     IF liability_cents > 300_000_000 THEN
       use over_3m_formula(liability_cents, underwriter)
     ELSE
       use tier_lookup(liability_cents, underwriter)
     END

  2. Apply minimum premium
     base_rate = MAX(base_rate, minimum_premium_cents)

  3. Apply policy type multiplier
     premium = base_rate × policy_type_multiplier

  4. Apply hold-open surcharge (if applicable)
     IF is_hold_open AND !prior_policy_amount_cents THEN
       premium += base_rate × hold_open_surcharge_percent
     END

Output:
  - premium_cents: Integer
```

### 2. Over-$3M Owner Premium Formula

```
Input:
  - liability_cents: Integer (> 300_000_000)
  - underwriter: String

Calculation:
  excess_cents = liability_cents - 300_000_000
  increments = CEIL(excess_cents / 1_000_000)

  base = state_rules[underwriter][:over_3m_base_cents]
  rate_per_10k = state_rules[underwriter][:over_3m_per_10k_cents]

  premium = base + (increments × rate_per_10k)

Output:
  - premium_cents: Integer

Example (TRG, $3.5M):
  excess = 350_000_000 - 300_000_000 = 50_000_000
  increments = CEIL(50_000_000 / 1_000_000) = 50
  premium = 421_100 + (50 × 525) = 421_100 + 26_250 = 447_350 cents ($4,473.50)
```

### 3. ELC Over-$3M Formula

```
Input:
  - liability_cents: Integer (> 300_000_000)
  - underwriter: String

Calculation:
  excess_cents = liability_cents - 300_000_000
  increments = CEIL(excess_cents / 1_000_000)

  base = state_rules[underwriter][:elc_over_3m_base_cents]
  rate_per_10k = state_rules[underwriter][:elc_over_3m_per_10k_cents]

  elc_premium = base + (increments × rate_per_10k)

Output:
  - elc_premium_cents: Integer

Example (TRG, $3.5M):
  excess = 350_000_000 - 300_000_000 = 50_000_000
  increments = CEIL(50_000_000 / 1_000_000) = 50
  elc_premium = 247_200 + (50 × 420) = 247_200 + 21_000 = 268_200 cents ($2,682)
```

### 4. Refinance Over-$10M Formula

```
Input:
  - liability_cents: Integer (> 1_000_000_000)
  - underwriter: String

Calculation:
  excess_cents = liability_cents - 1_000_000_000
  millions_over_10m = CEIL(excess_cents / 100_000_000)

  base = state_rules[underwriter][:refinance_over_10m_base_cents]
  rate_per_million = state_rules[underwriter][:refinance_over_10m_per_million_cents]

  refinance_premium = base + (millions_over_10m × rate_per_million)

Output:
  - refinance_premium_cents: Integer

Example (TRG, $12M):
  excess = 1_200_000_000 - 1_000_000_000 = 200_000_000
  millions = CEIL(200_000_000 / 100_000_000) = 2
  refinance = 720_000 + (2 × 80_000) = 720_000 + 160_000 = 880_000 cents ($8,800)
```

### 5. Minimum Premium Enforcement

```
Input:
  - calculated_base_rate: Integer
  - underwriter: String

Calculation:
  minimum = state_rules[underwriter][:minimum_premium_cents]
  enforced_base_rate = MAX(calculated_base_rate, minimum)

Output:
  - enforced_base_rate: Integer

Example (TRG, $10K liability):
  tier_lookup($10K) = $200 (hypothetical)
  minimum = $609
  enforced = MAX(20_000, 60_900) = 60_900 cents ($609)
```

---

## State Transitions

No state transitions - these are stateless calculations.

---

## Relationships

```
StateRules (CA)
  ├─ has_many: Underwriters (TRG, ORT)
  │   └─ has_many: FormulaParameters
  │
  └─ used_by: CA Calculator
      ├─ calls: BaseRate (passes underwriter)
      │   └─ calls: RateTier.calculate_over_3m_rate(underwriter)
      │   └─ calls: RateTier.calculate_elc_over_3m_rate(underwriter)
      │
      └─ applies: Minimum Premium Enforcement
```

---

## Validation Rules

### At Configuration Load Time:
1. All `*_cents` parameters must be integers >= 0
2. Formula parameters (`over_3m_*`, `elc_*`, `refinance_*`) must be > 0
3. Both TRG and ORT must have complete parameter sets

### At Calculation Time:
1. `liability_cents` must be > 0
2. `underwriter` must be "TRG" or "ORT" for CA
3. If using over-$3M formula, `liability_cents` must be > 300_000_000
4. If using over-$10M refinance, `liability_cents` must be > 1_000_000_000

### At Test Time:
1. Calculated premiums must match manual values within $2.00 tolerance
2. Minimum premium must be enforced for all owner policies
3. ELC premiums must be in thousands of dollars (not cents)
4. Boundary conditions ($3M, $10M) must use tier rates, not formulas

---

## Boundary Conditions

| Amount | Calculation Method | Rationale |
|--------|-------------------|-----------|
| $2,999,999 | Tier lookup | < $3M threshold |
| $3,000,000 | Tier lookup | AT boundary (use tier per clarification) |
| $3,000,001 | Formula | > $3M threshold |
| $9,999,999 | Tier lookup (refinance) | < $10M threshold |
| $10,000,000 | Tier lookup (refinance) | AT boundary |
| $10,000,001 | Formula (refinance) | > $10M threshold |

---

## Constants Removed

**File**: `lib/ratenode/models/rate_tier.rb`

These hardcoded TRG-only constants will be REMOVED:
```ruby
# REMOVE:
OVER_3M_BASE_CENTS = 421_100        # Line 8
OVER_3M_PER_10K_CENTS = 525         # Line 9
THREE_MILLION_CENTS = 300_000_000   # Line 10 (can be kept as general threshold)
```

Replaced by runtime lookups:
```ruby
rules = RateNode.rules_for("CA", underwriter: underwriter)
base = rules[:over_3m_base_cents]
rate = rules[:over_3m_per_10k_cents]
```

---

## Summary

- **No database schema changes** - all configuration stored in `state_rules.rb`
- **No new entities** - extends existing StateRules configuration
- **7 new parameters per underwriter** - all in cents, all sourced from rate manuals
- **4 calculation formulas** - over-$3M owner, ELC over-$3M, refinance over-$10M, minimum enforcement
- **Backward compatible** - existing behavior preserved for amounts ≤$3M
