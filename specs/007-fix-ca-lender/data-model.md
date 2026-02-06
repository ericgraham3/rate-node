# Data Model: CA Lender Policy Calculation

**Feature**: 007-fix-ca-lender
**Date**: 2026-02-05

## Overview

This document describes the entities, fields, validation rules, and state transitions for CA lender policy calculations. No new database tables or models are required - all changes are to calculation logic and configuration.

---

## Entity: Lender Policy Calculation Input

**Description**: Parameters passed to `calculate_lenders_premium` method to compute lender's title insurance premium.

### Fields

| Field Name | Type | Required | Default | Description |
|------------|------|----------|---------|-------------|
| `loan_amount_cents` | Integer | Yes | - | Loan amount in cents (must be ≥ 0) |
| `owner_liability_cents` | Integer | No | nil | Owner's policy liability for concurrent calculations (cents) |
| `underwriter` | String | Yes | - | Underwriter code ("TRG", "ORT", or "DEFAULT") |
| `as_of_date` | Date | No | Date.today | Effective date for rate lookup |
| `concurrent` | Boolean | No | false | Whether issued concurrently with owner's policy |
| `lender_policy_type` | Symbol | No | :standard | Coverage type (`:standard` or `:extended`) |
| `is_binder_acquisition` | Boolean | No | false | Whether this is a cash acquisition (no lender policy) |
| `include_lenders_policy` | Boolean | No | true | Whether to include lender policy in quote |

### Validation Rules

| Rule | Error Type | Message |
|------|------------|---------|
| `loan_amount_cents >= 0` | ArgumentError | "Loan amount cannot be negative" |
| `loan_amount_cents.is_a?(Integer)` | TypeError | "Loan amount must be an integer (cents)" |
| `underwriter` is present | ArgumentError | "Underwriter is required" |
| `lender_policy_type` in [:standard, :extended] | ArgumentError | "Invalid lender policy type: must be :standard or :extended" |
| If `concurrent == true` and loan > owner, `owner_liability_cents` must be present | ArgumentError | "Owner liability required for concurrent calculation with loan > owner" |

### Computed Fields

| Field Name | Computation | Usage |
|------------|-------------|-------|
| `should_skip_lender_policy` | `is_binder_acquisition == true \|\| include_lenders_policy == false` | Early return $0 premium |
| `is_standalone` | `!concurrent` | Route to standalone multiplier logic |
| `has_excess` | `concurrent && loan_amount_cents > owner_liability_cents` | Route to excess calculation formula |

---

## Entity: State Rules Configuration (CA)

**Description**: Underwriter-specific configuration values for CA lender policy calculations stored in `state_rules.rb`.

### New Configuration Keys (Per Underwriter)

| Key | Type | TRG Value | ORT Value | Description |
|-----|------|-----------|-----------|-------------|
| `standalone_lender_standard_percent` | Float | 80.0 | 75.0 | Multiplier for standalone Standard lender policies (percentage of base rate) |
| `standalone_lender_extended_percent` | Float | 90.0 | 85.0 | Multiplier for standalone Extended lender policies (percentage of base rate) |
| `concurrent_standard_excess_percent` | Float | 80.0 | 75.0 | Percentage applied to rate difference when loan > owner for Standard concurrent |

### Existing Configuration Keys (Used)

| Key | Type | Value | Usage |
|-----|------|-------|-------|
| `concurrent_base_fee_cents` | Integer | 15_000 ($150) | Flat fee for concurrent Standard lender policy when loan ≤ owner |
| `concurrent_uses_elc` | Boolean | true | Whether to use ELC rate for Extended concurrent calculations |

### Validation Rules

- All percentage values must be > 0 and ≤ 100
- Underwriter-specific values override "DEFAULT" values
- TRG and ORT must have explicit values (no fallback to DEFAULT for lender percentages)

---

## Entity: Lender Policy Calculation Output

**Description**: Result returned by `calculate_lenders_premium` method.

### Fields

| Field Name | Type | Description |
|------------|------|-------------|
| `premium_cents` | Integer | Calculated lender policy premium in cents |

### Special Values

| Value | Meaning |
|-------|---------|
| `0` | No lender policy (binder acquisition, include_lenders_policy: false, or $0 loan) |
| `15_000` ($150) | Flat fee for concurrent Standard when loan ≤ owner |
| `ArgumentError` raised | Invalid input (negative loan, missing required params) |
| Other exceptions propagated | Rate lookup failure (database error, rate not found) |

---

## State Transitions

### Standalone Lender Policy Flow

```
Input: loan_amount, lender_policy_type, underwriter
  ↓
[Validation: loan_amount >= 0]
  ↓
[Guard: loan_amount == 0?] → Return 0
  ↓
[Guard: is_binder_acquisition?] → Return 0
  ↓
[Guard: !include_lenders_policy?] → Return 0
  ↓
[Lookup: base_rate = BaseRate.calculate(loan_amount)]
  ↓
[Config: Get multiplier from state_rules]
  ↓
  ├─ Standard: standalone_lender_standard_percent (80% TRG / 75% ORT)
  └─ Extended: standalone_lender_extended_percent (90% TRG / 85% ORT)
  ↓
[Calculate: (base_rate * multiplier / 100.0).round]
  ↓
Return premium_cents
```

### Concurrent Standard Lender Policy Flow

```
Input: loan_amount, owner_liability, underwriter, concurrent: true, lender_policy_type: :standard
  ↓
[Validation: loan_amount >= 0, owner_liability present]
  ↓
[Guard: loan_amount == 0?] → Return 0
  ↓
[Guard: is_binder_acquisition?] → Return 0
  ↓
[Guard: !include_lenders_policy?] → Return 0
  ↓
[Check: loan_amount <= owner_liability?]
  ↓
  YES → Return concurrent_base_fee_cents ($150)
  ↓
  NO → Calculate excess:
    ├─ [Lookup: rate_loan = BaseRate.calculate(loan_amount)]
    ├─ [Lookup: rate_owner = BaseRate.calculate(owner_liability)]
    ├─ [Config: excess_percent = concurrent_standard_excess_percent (80% TRG / 75% ORT)]
    ├─ [Calculate: rate_diff = rate_loan - rate_owner]
    ├─ [Calculate: excess_rate = (rate_diff * excess_percent / 100.0).round]
    ├─ [Calculate: total = concurrent_base_fee_cents + excess_rate]
    └─ [Ensure: [concurrent_base_fee_cents, total].max]  # Minimum $150
  ↓
Return premium_cents
```

### Concurrent Extended Lender Policy Flow

```
Input: loan_amount, owner_liability, underwriter, concurrent: true, lender_policy_type: :extended
  ↓
[Validation: loan_amount >= 0, owner_liability present]
  ↓
[Guard: loan_amount == 0?] → Return 0
  ↓
[Guard: is_binder_acquisition?] → Return 0
  ↓
[Guard: !include_lenders_policy?] → Return 0
  ↓
[Lookup: Full ELC rate for loan_amount via BaseRate.calculate_elc]
  ↓
Return premium_cents (ELC rate)
```

**Note**: Extended concurrent uses full ELC rate table lookup, not the $150 + excess formula. This is per TRG/ORT rate manuals.

---

## Relationship Diagram

```
                                calculate_lenders_premium(params)
                                           |
                    ┌──────────────────────┼──────────────────────┐
                    |                      |                      |
          [Guard Checks]          [Standalone Path]      [Concurrent Path]
                    |                      |                      |
          ┌─────────┴─────────┐           |            ┌─────────┴─────────┐
     is_binder_      include_  loan == 0  |       Standard              Extended
     acquisition?    lenders?      ↓      |       lender_policy_type    lender_policy_type
          ↓              ↓         0      |              |                      |
       Return 0      Return 0             |       ┌──────┴──────┐              |
                                          |    loan ≤    loan >               |
                                          |    owner     owner                |
                                          |      ↓         ↓                  ↓
                                          |    $150    $150 + %×Δrate    ELC rate
                                          |             ↑                   lookup
                                          |             |
                                          |   concurrent_standard_
                                          |   excess_percent
                                          |
                                 standalone_lender_X_percent
                                          ↓
                                (base_rate × multiplier).round
```

---

## Example Calculations

### Example 1: Standalone Standard (TRG)

```
Input:
  loan_amount_cents: 50_000_000 ($500,000)
  underwriter: "TRG"
  concurrent: false
  lender_policy_type: :standard

Calculation:
  base_rate = BaseRate.calculate(50_000_000, "CA", "TRG") → 157_100 ($1,571)
  multiplier = 80.0 / 100.0 → 0.80
  premium = (157_100 * 0.80).round → 125_680 ($1,256.80)

Output: 125_680 cents
```

### Example 2: Concurrent Standard with Excess (TRG)

```
Input:
  loan_amount_cents: 50_000_000 ($500,000)
  owner_liability_cents: 40_000_000 ($400,000)
  underwriter: "TRG"
  concurrent: true
  lender_policy_type: :standard

Calculation:
  rate_loan = BaseRate.calculate(50_000_000, "CA", "TRG") → 157_100 ($1,571)
  rate_owner = BaseRate.calculate(40_000_000, "CA", "TRG") → 137_200 ($1,372)
  rate_diff = 157_100 - 137_200 → 19_900
  excess_percent = 80.0 / 100.0 → 0.80
  excess_rate = (19_900 * 0.80).round → 15_920
  total = 15_000 + 15_920 → 30_920 ($309.20)
  final = [15_000, 30_920].max → 30_920

Output: 30_920 cents ($309.20)
```

### Example 3: Concurrent Extended (TRG)

```
Input:
  loan_amount_cents: 50_000_000 ($500,000)
  owner_liability_cents: 40_000_000 ($400,000)
  underwriter: "TRG"
  concurrent: true
  lender_policy_type: :extended

Calculation:
  elc_rate = BaseRate.calculate_elc(50_000_000, "CA", "TRG") → [ELC table value]

Output: [ELC rate in cents]
```

### Example 4: Binder Acquisition (Cash Purchase)

```
Input:
  loan_amount_cents: 50_000_000 ($500,000)
  underwriter: "TRG"
  is_binder_acquisition: true
  include_lenders_policy: true  # Ignored due to precedence

Calculation:
  Guard: is_binder_acquisition == true → Return 0

Output: 0 cents (no lender policy on cash acquisition)
```

---

## Notes

- All monetary values stored and calculated in cents (integers) to avoid floating-point errors
- Rounding occurs only at final calculation step: `(value * multiplier).round`
- Rate lookups may raise exceptions if rate not found - these should propagate to fail fast
- The $150 minimum for concurrent Standard is enforced using `[base_fee, total].max`
- Extended concurrent calculations use the existing `calculate_elc` method (no changes to that logic)
