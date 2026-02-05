# Data Model: NC Reissue Discount Calculation

**Feature**: 003-fix-nc-reissue | **Date**: 2026-02-04

## Entities

### Existing Entities (No Changes)

| Entity | Location | Purpose |
|--------|----------|---------|
| `RateTier` | `lib/ratenode/models/rate_tier.rb` | Rate tier data with `calculate_rate()` for tiered computation |
| `PolicyType` | `lib/ratenode/models/policy_type.rb` | Policy type multipliers (standard=1.0, homeowner=1.2, extended=1.2) |
| `StateRules` | `lib/ratenode/state_rules.rb` | NC config: `reissue_discount_percent: 0.50`, `reissue_eligibility_years: 15` |

### Modified Logic (Same File, New Algorithm)

| Component | Location | Change |
|-----------|----------|--------|
| `NC#calculate_reissue_discount` | `lib/ratenode/calculators/states/nc.rb:152-171` | Replace proportional approximation with tiered rate lookup |

## Calculation Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        NC Reissue Discount Calculation                      │
└─────────────────────────────────────────────────────────────────────────────┘

Inputs:
  • liability_cents         — Current policy liability
  • prior_policy_amount_cents — Previous policy amount
  • prior_policy_date       — Date of previous policy
  • policy_type             — :standard | :homeowner | :extended
  • underwriter             — Underwriter code (e.g., "DEFAULT")
  • as_of_date              — Effective date for rate lookup

                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Step 1: Eligibility Check                                                   │
│                                                                             │
│   eligible_for_reissue_discount?                                           │
│     • prior_policy_date present?                                           │
│     • prior_policy_amount_cents present?                                   │
│     • years_since_prior <= reissue_eligibility_years (15)?                 │
│                                                                             │
│   If NO → return 0                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │ YES
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Step 2: Calculate Discountable Portion                                      │
│                                                                             │
│   discountable_portion_cents = MIN(liability_cents, prior_policy_amount_cents)│
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Step 3: Calculate Tiered Rate on Discountable Portion                       │
│                                                                             │
│   discountable_tiered_rate = RateTier.calculate_rate(                      │
│     discountable_portion_cents,                                             │
│     state: "NC",                                                            │
│     underwriter: @underwriter,                                              │
│     as_of_date: @as_of_date                                                │
│   )                                                                         │
│                                                                             │
│   ┌───────────────────────────────────────────────────────────────┐        │
│   │ Example: $250,000 discountable portion                        │        │
│   │   Tier 1: $0-$100k    @ $2.78/k = $278.00                    │        │
│   │   Tier 2: $100k-$250k @ $2.17/k = $325.50                    │        │
│   │   Total: $603.50 (60350 cents)                                │        │
│   └───────────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Step 4: Apply Policy Type Multiplier                                        │
│                                                                             │
│   multiplier = PolicyType.multiplier_for(@policy_type, state: "NC", ...)   │
│   discountable_base = (discountable_tiered_rate * multiplier).round        │
│                                                                             │
│   NC Multipliers:                                                           │
│     :standard  → 1.00                                                       │
│     :homeowner → 1.20                                                       │
│     :extended  → 1.20                                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ Step 5: Apply Discount Percentage                                           │
│                                                                             │
│   discount_percent = state_rules[:reissue_discount_percent]   # 0.50       │
│   reissue_discount = (discountable_base * discount_percent).round          │
│                                                                             │
│   ┌───────────────────────────────────────────────────────────────┐        │
│   │ Example: $603.50 × 1.00 × 0.50 = $301.75                     │        │
│   └───────────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                            Return reissue_discount
```

## Validation Rules

| Rule | Description | Source |
|------|-------------|--------|
| Eligibility gate | Both prior_policy_date and prior_policy_amount_cents must be present | FR-006 |
| Time window | prior_policy_date must be within 15 years of as_of_date | FR-006, state_rules |
| Discountable cap | discountable_portion <= liability | FR-002 |
| Percentage from config | discount_percent read from state_rules, not hardcoded | FR-004 |
| Consistency | `reissue_discount_amount()` and internal discount must match | FR-007 |

## State Transitions

N/A — This is a stateless calculation with no entity lifecycle.

## Database Schema

No schema changes required. Uses existing `rate_tiers` table:

```sql
-- Existing table structure (for reference)
CREATE TABLE rate_tiers (
  id INTEGER PRIMARY KEY,
  min_liability_cents INTEGER,
  max_liability_cents INTEGER,
  base_rate_cents INTEGER,
  per_thousand_cents INTEGER,
  extended_lender_concurrent_cents INTEGER,
  state_code TEXT,
  underwriter_code TEXT,
  effective_date TEXT,
  expires_date TEXT,
  rate_type TEXT,
  rate_table_type TEXT
);
```

NC rate tiers are seeded from `db/seeds/data/nc_rates.rb` with `per_thousand` values.
