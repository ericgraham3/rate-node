# Data Model: Fix FL Rate Calculator Discrepancies

**Phase**: 1 — Design & Contracts
**Date**: 2026-02-04

---

## Entities in Scope

Only two logical entities are touched. No schema change is needed — the SQLite `endorsements` table already has every column required.

---

### Entity 1 — Endorsement Definition (FL seed data)

Represents a single row in the `endorsements` table for Florida / TRG. Managed via `db/seeds/data/fl_rates.rb` → `Models::Endorsement.seed`.

| Field | Type | Notes |
|-------|------|-------|
| `code` | String | Primary lookup key (e.g., `"ALTA 6"`) |
| `form_code` | String | Same as `code` for FL endorsements |
| `name` | String | Human-readable label |
| `pricing_type` | Enum string | One of: `flat`, `percentage_combined`, `no_charge`, … |
| `base_amount` | Integer (cents) | Used when `pricing_type == "flat"` |
| `percentage` | Float | Used when `pricing_type == "percentage_combined"` (e.g., `0.10` = 10%) |
| `min` | Integer (cents) | Floor for percentage-based charges |
| `lender_only` | Boolean | `true` → endorsement applies only to lender policies |
| `owner_only` | Boolean | `true` → endorsement applies only to owner policies |

#### Changes to existing rows

| Code | Current `pricing_type` | New `pricing_type` | New fields | Reason |
|------|------------------------|---------------------|------------|--------|
| ALTA 6 | `no_charge` | `flat` | `base_amount: 2500` | FR-001: $25 flat per rate manual |
| ALTA 6.2 | `no_charge` | `flat` | `base_amount: 2500` | FR-002: $25 flat per rate manual |
| ALTA 9.3 | `no_charge` | `percentage_combined` | `percentage: 0.10, min: 2500` | FR-003: 10% of combined premium, $25 min |

#### New rows

| Code | `pricing_type` | `percentage` | `min` | `lender_only` | Reason |
|------|----------------|--------------|-------|---------------|--------|
| ALTA 9.1 | `percentage_combined` | `0.10` | `2500` | (not set — owner endorsement) | FR-004 |
| ALTA 9.2 | `percentage_combined` | `0.10` | `2500` | (not set — owner endorsement) | FR-004 |

#### Validation rules (from spec)

- `base_amount` for flat endorsements is expressed in cents: `2500` = $25.00.
- `min` for percentage endorsements is expressed in cents: `2500` = $25.00.
- When the combined premium is exactly $250.00 (25000 cents), 10% = 2500 cents = the minimum. Either comparison path yields $25.00.
- ALTA 9 and ALTA 9.3 on the same lender policy are charged independently — no subsumption logic exists or is needed.

---

### Entity 2 — Reissue Eligibility Window (FL calculator)

Not a persisted entity — it is a computed boolean inside `States::FL#eligible_for_reissue_rates?`. The threshold value (`reissue_eligibility_years: 3`) lives in `STATE_RULES` and is unchanged.

| Concept | Current behavior | New behavior |
|---------|-----------------|--------------|
| Boundary comparison | `years_since_prior <= 3` (inclusive) | `years_since_prior < 3` (exclusive) |
| Prior policy exactly 3 years old | Qualifies for reissue | Does NOT qualify |
| Prior policy 2 years 364 days old | Qualifies (floored to 2) | Still qualifies (floored to 2) |
| Prior policy > 3 years old | Does not qualify | Does not qualify (unchanged) |
| No prior policy date supplied | Returns false early | Returns false early (unchanged) |

#### State transitions

```
prior_policy_date supplied?
  NO  → eligible = false  (unchanged)
  YES → years_since_prior = floor((as_of_date - prior_policy_date) / 365.25)
        years_since_prior < 3?        ← operator change (was <=)
          YES → eligible = true
          NO  → eligible = false
```

---

## What is NOT changing

- The `endorsements` table schema — all columns already exist.
- `Models::Endorsement` — the pricing dispatch logic already handles `flat` and `percentage_combined`.
- `EndorsementCalculator` — it already passes `combined_premium_cents` through.
- `STATE_RULES["FL"]` — no configuration keys change; only the operator in FL's calculator changes.
- `scenarios_input.csv` — human-controlled; not modified by this feature.
