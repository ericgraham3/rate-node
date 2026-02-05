# Tasks: Fix FL Rate Calculator Discrepancies

**Input**: Design documents from `/specs/002-fix-fl-rates/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not included. The CSV scenario suite (`spec/fixtures/scenarios_input.csv` driven by `spec/integration/csv_scenarios_spec.rb`) is the sole test authority per Constitution Principle V. New edge-case rows are human-authored and out of scope.

**Organization**: Tasks are grouped by user story. US1 and US2 both edit `db/seeds/data/fl_rates.rb` (different entries) and must run sequentially. US3 edits a different file (`lib/ratenode/calculators/states/fl.rb`) and can run in parallel with US1/US2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: No project initialization is needed. The Ruby project, SQLite database, endorsement model, and test harness are all in place. The endorsement model already supports `flat` and `percentage_combined` pricing types. No dependencies to install, no schema to migrate.

**Checkpoint**: Skip directly to user story implementation.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No foundational work is required. All infrastructure that these changes depend on already exists:
- `Models::Endorsement` dispatches `flat` and `percentage_combined` correctly
- `EndorsementCalculator` passes `combined_premium_cents` through to the model
- `States::FL` implements `BaseStateCalculator` and contains `eligible_for_reissue_rates?`
- The seed pipeline (`Endorsement.seed`) maps all required hash keys to columns

**Checkpoint**: User story implementation can begin immediately.

---

## Phase 3: User Story 1 — ALTA 6 Endorsements Charged Correctly (Priority: P1) 🎯 MVP

**Goal**: Change ALTA 6 and ALTA 6.2 from `no_charge` to a flat $25.00 fee in the FL endorsement seed data. After this task, any FL lender policy requesting either endorsement will produce a $25.00 line item.

**Independent Test**: Run `bundle exec rspec spec/integration/csv_scenarios_spec.rb` — all existing scenarios must pass. To manually verify the fix, inspect the ALTA 6 and ALTA 6.2 entries in the seeded `endorsements` table and confirm `pricing_type = "flat"` and `base_amount_cents = 2500`.

### Implementation for User Story 1

- [X] T001 [US1] Edit ALTA 6 entry in `db/seeds/data/fl_rates.rb`: change `pricing_type: "no_charge"` to `pricing_type: "flat", base_amount: 2500` (keep `lender_only: true`)
- [X] T002 [US1] Edit ALTA 6.2 entry in `db/seeds/data/fl_rates.rb`: change `pricing_type: "no_charge"` to `pricing_type: "flat", base_amount: 2500` (keep `lender_only: true`)

**Checkpoint**: ALTA 6 and ALTA 6.2 are now flat $25.00 lender endorsements. Scenario tests still pass.

---

## Phase 4: User Story 2 — ALTA 9-Series Endorsements Priced at 10% (Priority: P1)

**Goal**: Fix ALTA 9.3 from `no_charge` to 10%-of-combined-premium (min $25.00), and add ALTA 9.1 and 9.2 as new owner endorsements with the same pricing. After these tasks, all three endorsements produce the correct charge. Note: ALTA 9 (the base form) is already correct and is not touched.

**Independent Test**: Run `bundle exec rspec spec/integration/csv_scenarios_spec.rb` — all existing scenarios must pass (the `FL_Endorsement_Combined` scenario exercises ALTA 9 and must remain unchanged). To manually verify, confirm ALTA 9.3 now has `pricing_type = "percentage_combined"` and that ALTA 9.1/9.2 exist in the seeded table with `lender_only = 0`.

### Implementation for User Story 2

- [X] T003 [US2] Edit ALTA 9.3 entry in `db/seeds/data/fl_rates.rb`: change `pricing_type: "no_charge"` to `pricing_type: "percentage_combined", percentage: 0.10, min: 2500` (keep `lender_only: true`)
- [X] T004 [US2] Add ALTA 9.1 entry to the `ENDORSEMENTS` array in `db/seeds/data/fl_rates.rb` near the other 9-series entries: `{ code: "ALTA 9.1", form_code: "ALTA 9.1", name: "Restrictions, Encroachments, Minerals - Owner Policy", pricing_type: "percentage_combined", percentage: 0.10, min: 2500 }` (no `lender_only` flag — this is an owner endorsement)
- [X] T005 [US2] Add ALTA 9.2 entry to the `ENDORSEMENTS` array in `db/seeds/data/fl_rates.rb` near the other 9-series entries: `{ code: "ALTA 9.2", form_code: "ALTA 9.2", name: "Restrictions, Encroachments, Minerals - Owner Policy (Planned)", pricing_type: "percentage_combined", percentage: 0.10, min: 2500 }` (no `lender_only` flag — this is an owner endorsement)

**Checkpoint**: ALTA 9.1, 9.2, and 9.3 all produce 10%-of-combined-premium charges (min $25.00). Scenario tests still pass.

---

## Phase 5: User Story 3 — Reissue Eligibility Boundary Is Exclusive (Priority: P2)

**Goal**: Change the reissue eligibility comparison in the FL calculator from inclusive (`<=`) to exclusive (`<`). After this change, a prior policy that is exactly 3 years old no longer qualifies for reissue rates; policies up to 2 years 364 days old still qualify.

**Independent Test**: Run `bundle exec rspec spec/integration/csv_scenarios_spec.rb` — all existing scenarios must pass. The `FL_Purchase_Reissue` scenario has a prior policy date of 1/1/2024 (~1 year old), which floors to `years_since_prior == 1` and satisfies `1 < 3`, so reissue rates are still correctly applied.

### Implementation for User Story 3

- [X] T006 [P] [US3] Edit `eligible_for_reissue_rates?` in `lib/ratenode/calculators/states/fl.rb`: change `years_since_prior <= eligibility_years` to `years_since_prior < eligibility_years`

**Checkpoint**: Reissue eligibility boundary is now exclusive. Scenario tests still pass.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verify the complete set of changes end-to-end against the scenario suite.

- [X] T007 Run full scenario suite (`bundle exec rspec spec/integration/csv_scenarios_spec.rb`) and confirm all scenarios pass with zero failures
- [X] T008 Review all edits against `quickstart.md` checklist to confirm every item is addressed before merging

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** and **Foundational (Phase 2)**: Empty — no work required.
- **User Stories (Phases 3–5)**: Can begin immediately.
  - US1 (Phase 3) and US2 (Phase 4) both edit `db/seeds/data/fl_rates.rb` — run sequentially (US1 then US2, or US2 then US1).
  - US3 (Phase 5) edits `lib/ratenode/calculators/states/fl.rb` — a different file. Can run in parallel with US1 and US2.
- **Polish (Phase 6)**: Depends on all user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies. Can start immediately.
- **User Story 2 (P1)**: No logical dependency on US1, but shares the same file. Run after US1 to avoid merge conflicts, or coordinate edits if running concurrently.
- **User Story 3 (P2)**: No dependency on US1 or US2. Different file — fully parallel.

### Within Each User Story

- US1: T001 and T002 edit different entries in the same array — can be done in one pass but are listed as sequential tasks for clarity.
- US2: T003, T004, T005 edit/add different entries — same file, one pass.
- US3: Single task (T006).

### Parallel Opportunities

- **T006 (US3)** can run in parallel with T001–T005 (US1 + US2) because it targets a different file.
- T001–T005 must be applied sequentially to `fl_rates.rb` (same file).

---

## Parallel Example

```text
# Stream A — fl_rates.rb (sequential within stream)
T001 [US1] Fix ALTA 6 in db/seeds/data/fl_rates.rb
T002 [US1] Fix ALTA 6.2 in db/seeds/data/fl_rates.rb
T003 [US2] Fix ALTA 9.3 in db/seeds/data/fl_rates.rb
T004 [US2] Add ALTA 9.1 in db/seeds/data/fl_rates.rb
T005 [US2] Add ALTA 9.2 in db/seeds/data/fl_rates.rb

# Stream B — fl.rb (parallel with Stream A)
T006 [US3] Fix reissue boundary in lib/ratenode/calculators/states/fl.rb

# After both streams complete:
T007 Run scenario suite
T008 Final review
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete T001–T002 (ALTA 6/6.2 fix)
2. Run scenario suite — confirm pass
3. ALTA 6 endorsements are now correctly priced. Shippable increment.

### Incremental Delivery

1. T001–T002 → ALTA 6/6.2 fixed → test → ship
2. T003–T005 → ALTA 9-series fixed → test → ship
3. T006 → reissue boundary fixed → test → ship
4. T007–T008 → full polish and final validation

### Single-Developer (Recommended for this feature)

All changes are small and in two files. A single pass is the most efficient path:

1. Edit `db/seeds/data/fl_rates.rb` — apply T001 through T005 in one sitting
2. Edit `lib/ratenode/calculators/states/fl.rb` — apply T006
3. Run scenario suite (T007)
4. Review against quickstart (T008)

---

## Notes

- [P] on T006 indicates it targets a different file from T001–T005 and can run concurrently
- All amounts in code are cents: $25.00 = `2500`
- Do NOT modify `spec/fixtures/scenarios_input.csv` — human-controlled per Constitution Principle V
- Do NOT touch any other state's files — Constitution Principle I (State Isolation)
- ALTA 9 (base form) is already correct — do not change it
- Out-of-scope: ALTA 9 may be missing `lender_only: true` — track separately
