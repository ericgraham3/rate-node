# Research: Fix FL Rate Calculator Discrepancies

**Phase**: 0 — Outline & Research
**Date**: 2026-02-04
**Status**: Complete — all questions resolved from spec clarifications and codebase inspection

---

## Research Questions & Resolutions

### RQ-1: How are endorsement definitions persisted?

**Decision**: Endorsements are defined as Ruby hashes in `db/seeds/data/fl_rates.rb` (the `ENDORSEMENTS` array) and inserted into the SQLite `endorsements` table at boot via `Models::Endorsement.seed`. The seed hash keys that map to database columns are: `code`, `form_code`, `name`, `pricing_type`, `base_amount` (→ `base_amount_cents`), `percentage`, `min` (→ `min_cents`), `lender_only`, `owner_only`.

**Rationale**: Endorsement fixes are therefore pure seed-data edits — no schema change, no model change, no new pricing logic.

**Alternatives considered**: None. The seeding pipeline is the established pattern for all states.

---

### RQ-2: Does the endorsement model already support `percentage_combined` pricing?

**Decision**: Yes. `Models::Endorsement#calculate_premium` dispatches to `calculate_percentage_combined_premium(combined_premium_cents)` when `pricing_type == "percentage_combined"`. That method applies `percentage`, enforces `min_cents`, and enforces `max_cents`. The existing `ALTA 9` entry in `fl_rates.rb` already uses this exact pricing type with `percentage: 0.10, min: 2500`. ALTA 9.1, 9.2, and 9.3 need only the same seed-hash shape.

**Rationale**: No model or calculator logic change is needed for the 9-series fixes. Only the seed data rows change.

**Alternatives considered**: None — the pricing type is pre-existing.

---

### RQ-3: What is the correct seed-hash shape for a flat endorsement vs a percentage_combined endorsement?

**Decision**:

Flat (used by ALTA 6, 6.2):
```ruby
{ code: "ALTA 6", form_code: "ALTA 6", name: "...", pricing_type: "flat", base_amount: 2500, lender_only: true }
```

Percentage-combined (used by ALTA 9, 9.1, 9.2, 9.3):
```ruby
{ code: "ALTA 9.3", form_code: "ALTA 9.3", name: "...", pricing_type: "percentage_combined", percentage: 0.10, min: 2500, lender_only: true }
```

**Rationale**: Confirmed by inspecting the existing ALTA 9 and ALTA 4 entries in `fl_rates.rb` and the `Endorsement.seed` column-mapping logic in `endorsement.rb:112`.

---

### RQ-4: Are ALTA 9.1 and 9.2 owner or lender endorsements?

**Decision**: Owner endorsements. Per the spec clarification session (2026-02-04): "ALTA 9.1 and 9.2 are owner endorsements (no `lender_only` flag). ALTA 9 and 9.3 are lender endorsements."

**Rationale**: The seed hash must NOT include `lender_only: true` for 9.1/9.2. It can be omitted entirely (defaults to `false` via `row[:lender_only] ? 1 : 0` in the seed method).

---

### RQ-5: How does the reissue eligibility check work and where exactly is the operator?

**Decision**: In `lib/ratenode/calculators/states/fl.rb`, the private method `eligible_for_reissue_rates?` computes:

```ruby
years_since_prior = ((@as_of_date - @prior_policy_date) / 365.25).floor
years_since_prior <= eligibility_years   # ← this line
```

The `eligibility_years` value is `3` (from `STATE_RULES["FL"][:reissue_eligibility_years]`). The FL rate manual states the window is "less than three years," which means a prior policy exactly 3 years old must NOT qualify. The fix is to change `<=` to `<`.

**Rationale**: `years_since_prior` is the floored integer number of years. A prior policy exactly 3 years old yields `years_since_prior == 3`. Under `<=`, `3 <= 3` is true (reissue granted — incorrect). Under `<`, `3 < 3` is false (standard rates — correct). Policies at 2 years 364 days floor to `2`, and `2 < 3` remains true (reissue still granted — correct).

**Alternatives considered**: Changing `eligibility_years` from 3 to 2 would over-correct (policies between 2 and 3 years would lose eligibility). The operator change is the minimal, correct fix.

---

### RQ-6: Will the existing FL CSV scenarios still pass after these changes?

**Decision**: Yes, with high confidence. The three FL scenarios in `scenarios_input.csv` are:

| Scenario | Endorsements | Reissue? | Impact |
|----------|-------------|----------|--------|
| `FL_Purchase_Simple` | none | no | No endorsement or reissue change applies |
| `FL_Purchase_With_Loan` | none listed | no | No endorsement change applies |
| `FL_Purchase_Reissue` | none | yes (prior date 1/1/2024) | Prior policy is ~1 year old as of 2026-02-04 → `years_since_prior == 1` → `1 < 3` is true → reissue still granted. No change in behavior. |
| `FL_Endorsement_Combined` | ALTA 9 | no | ALTA 9 is unchanged (already `percentage_combined`). No effect. |

None of the existing scenarios exercise ALTA 6, 6.2, 9.1, 9.2, or 9.3, and none hit the exact 3-year reissue boundary. All four scenarios are unaffected.

**Rationale**: The changes are additive (new endorsements) or narrowing (boundary tightening that doesn't affect the existing test date). Safe to proceed.

---

### RQ-7: Does the `contracts/` directory apply to this feature?

**Decision**: No. This feature has no new API endpoints, no new CLI commands, and no interface changes. The `BaseStateCalculator` contract is unchanged. The `contracts/` directory is not needed. A note to this effect is included in `plan.md`.

**Rationale**: Contract artifacts are for interface-level design. This feature is entirely internal to FL seed data and one operator in FL's calculator.
