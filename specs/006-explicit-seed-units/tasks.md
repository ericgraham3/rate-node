# Tasks: Explicit Seed Unit Declaration

**Input**: Design documents from `/specs/006-explicit-seed-units/`
**Prerequisites**: plan.md, spec.md, research.md, quickstart.md

**Tests**: No test tasks generated. Tests are not explicitly requested. The existing CSV scenario test suite (`bundle exec rspec`) is the validation gate for this feature.

**Organization**: Tasks are grouped by user story. US1 (P1) is the core implementation; US2 (P2) is the validation gate that confirms zero data drift.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: No project initialization or new dependencies are required for this feature. All changes are modifications to 4 existing Ruby files. No new gems, no new directories, no new files.

*This phase is intentionally empty. Proceed to Phase 2.*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the baseline state of the shared seeder before any changes are made. This baseline is needed by US2's before/after validation.

**⚠️ CRITICAL**: Phase 2 must complete before US1 work begins.

- [X] T001 Export current seeded rate_tiers data as baseline: run `bin/ratenode seed` to populate the database, then export the rate_tiers table with `sqlite3 -csv db/ratenode.db "SELECT * FROM rate_tiers ORDER BY state_code, min_liability_cents;" > tmp/baseline_rate_tiers.csv`. This is the "before" snapshot required by SC-001.

**Checkpoint**: Baseline snapshot exists. US1 implementation can now begin.

---

## Phase 3: User Story 1 - Developer adds a new state without silent misclassification (Priority: P1) 🎯 MVP

**Goal**: Add explicit `RATE_TIERS_UNIT` declarations to NC, CA, and TX state modules, then replace the value-inspection heuristic in the shared seeder with logic that reads the declaration and fails loud on missing or unrecognized values.

**Independent Test**: After all T002–T006 tasks complete, re-seed the database and compare every row in `rate_tiers` against the Phase 2 baseline. Zero rows should differ (SC-001).

### Implementation for User Story 1

- [X] T002 [P] [US1] Add `RATE_TIERS_UNIT = :dollars` to NC state module in `db/seeds/data/nc_rates.rb`, immediately before the `RATE_TIERS` constant definition
- [X] T003 [P] [US1] Add `RATE_TIERS_UNIT = :dollars` to CA state module in `db/seeds/data/ca_rates.rb`, immediately before the `RATE_TIERS` constant definition
- [X] T004 [P] [US1] Add `RATE_TIERS_UNIT = :cents` to TX state module in `db/seeds/data/tx_rates.rb`, immediately before the `RATE_TIERS` constant definition
- [X] T005 [US1] Remove the `already_in_cents` heuristic (the `state::RATE_TIERS.first && state::RATE_TIERS.first[:min] >= 100_000` line) from `seed_rate_tiers()` in `db/seeds/rates.rb` and replace it with: (a) a guard that raises `ArgumentError` if `state::RATE_TIERS_UNIT` is not defined, (b) a guard that raises `ArgumentError` if the value is not `:dollars` or `:cents`, and (c) a branch that maps tier rows to cents when the unit is `:dollars`, or passes them through unchanged when the unit is `:cents`. Follow the code structure shown in `research.md` "Step 2".
- [X] T006 [US1] Review `db/seeds/rates.rb` after T005 to confirm: the heuristic line is fully removed, both error paths use the exact messages specified in `research.md`, and the cents/dollars conversion logic matches the original behaviour for each state (NC/CA multiply, TX pass-through).

**Checkpoint**: All state declarations and seeder changes are in place. Proceed to US2 validation.

---

## Phase 4: User Story 2 - Existing scenario tests remain green after the change (Priority: P2)

**Goal**: Confirm zero seeded-data drift and zero test regressions. This is the primary quality gate for the feature (SC-001, SC-002).

**Independent Test**: Re-seed produces identical `rate_tiers` rows; full RSpec suite passes.

### Implementation for User Story 2

- [X] T007 [US2] Re-seed the database with the modified code (`bin/ratenode seed`), then re-export rate_tiers (ordered by state_code, min_liability_cents) to `tmp/after_rate_tiers.csv`. Compare data content against the Phase 2 baseline excluding auto-increment IDs. Zero data differences expected. This satisfies SC-001. *(Note: sqlite3 CLI was unavailable; export was performed via RateNode::Database + Ruby CSV.)*
- [X] T008 [US2] Run the full CSV scenario test suite (`bundle exec rspec`). All previously passing NC, CA, and TX scenarios must pass without modification. This satisfies SC-002.

**Checkpoint**: SC-001 and SC-002 confirmed. Feature is validated.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Edge-case validation and final review per research.md "Edge Case Validation".

- [X] T009 Verify the missing-declaration error path: in `db/seeds/data/nc_rates.rb`, comment out the `RATE_TIERS_UNIT` line. Run `bin/ratenode seed` and confirm it exits with: `ArgumentError: ...NC::RATE_TIERS_UNIT must be declared (:dollars or :cents)`. Restore the line. This satisfies SC-003.
- [X] T010 Verify the unrecognized-value error path: in `db/seeds/data/nc_rates.rb`, change `RATE_TIERS_UNIT = :dollars` to `RATE_TIERS_UNIT = :invalid`. Run `bin/ratenode seed` and confirm it exits with: `ArgumentError: ...NC::RATE_TIERS_UNIT must be :dollars or :cents, got :invalid`. Restore the original value.
- [X] T011 Clean up any temporary baseline/comparison files created during validation (e.g., `tmp/baseline_rate_tiers.csv`, `tmp/after_rate_tiers.csv`).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: No dependencies — can start immediately. Produces the baseline snapshot.
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion (baseline must exist before changes are made).
- **User Story 2 (Phase 4)**: Depends on Phase 3 completion (all declarations and seeder changes must be in place before validation).
- **Polish (Phase 5)**: Depends on Phase 4 completion (feature validated before edge-case checks).

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Phase 2. T002, T003, T004 are independent of each other (different files). T005 depends on T002–T004 being complete (seeder reads the declarations). T006 depends on T005.
- **User Story 2 (P2)**: Depends on all of US1 completing. T007 and T008 are sequential (seed before test).

### Within Each User Story

- US1: State declarations (T002–T004) before seeder rewrite (T005) before review (T006)
- US2: Re-seed and diff (T007) before full test run (T008)

### Parallel Opportunities

- T002, T003, T004 can all run in parallel — each modifies a different state module file
- No other parallel opportunities exist in this feature (the remaining tasks form a strict sequential chain)

---

## Parallel Example: User Story 1

```bash
# Launch all state declarations together (different files, no dependencies):
Task: "Add RATE_TIERS_UNIT = :dollars to db/seeds/data/nc_rates.rb"
Task: "Add RATE_TIERS_UNIT = :dollars to db/seeds/data/ca_rates.rb"
Task: "Add RATE_TIERS_UNIT = :cents  to db/seeds/data/tx_rates.rb"

# Then sequentially:
Task: "Rewrite seed_rate_tiers() in db/seeds/rates.rb"
Task: "Review db/seeds/rates.rb for correctness"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Foundational (baseline snapshot)
2. Complete Phase 3: User Story 1 (declarations + seeder rewrite)
3. **STOP and VALIDATE**: Run `bundle exec rspec` to confirm no regressions
4. If green, proceed to Phase 4 for full SC-001/SC-002 sign-off

### Incremental Delivery

1. Phase 2 → baseline exists
2. Phase 3 (US1) → declarations and seeder rewrite complete → quick smoke test
3. Phase 4 (US2) → full before/after diff and test suite → feature validated
4. Phase 5 → edge-case error paths confirmed → feature complete

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- No new files or dependencies are introduced by this feature
- FL and AZ are explicitly out of scope (dedicated seeders, not modified)
- The scenario test suite is the primary correctness oracle — if seeded values drift, tests will fail
