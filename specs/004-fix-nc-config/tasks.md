# Tasks: Fix NC Rate Configuration and Cross-State Policy Type Symbol

**Input**: Design documents from `/specs/004-fix-nc-config/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: Not explicitly requested. CSV scenario tests are an existing safety net; no new test tasks generated. FR-007 explicitly prohibits agent-authored expected values for new scenarios.

**Organization**: Tasks grouped by user story. US1 (endorsements) and US3 (minimum/rounding) touch only NC files. US2 (policy type symbol) touches all states but each file is an independent edit.

## Phase 1: Setup

**Purpose**: Confirm the environment is ready and the baseline passes before any changes are made. No new files — this is a configuration-correction feature against an existing codebase.

- [x] T001 Verify baseline: run `bundle exec rspec` from repo root and confirm all existing CSV scenario tests pass before any edits

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The endorsement seed data is the only shared dependency — US1 must remove the invalid NC endorsements before US3's rounding/minimum changes are validated against a clean catalogue. US2 (policy type symbol) has no shared dependency; it can proceed in parallel with US1 once Phase 1 passes.

**⚠️ CRITICAL**: T002 must complete before T006 (US3 touches the same NC state rules block). US2 tasks (T003–T005) are all independent of each other and of US1/US3.

- [x] T002 [US1] Replace the NC ENDORSEMENTS array in `db/seeds/data/nc_rates.rb` (lines 53–99): remove all 46 entries and replace with exactly three entries — ALTA 5 ("Planned Unit Development", flat, base_amount 2300), ALTA 8.1 ("Environmental Protection Lien (Owner)", flat, base_amount 2300), ALTA 9 ("Restrictions, Encroachments, Minerals", flat, base_amount 2300). Preserve the `.freeze` call. Do not touch RATE_TIERS, REFINANCE_RATES, or CPL_RATES.

**Checkpoint**: NC seed data is correct. US1 implementation is complete at this point — it is a data-only change.

---

## Phase 3: User Story 1 - NC Endorsement List Corrected to Rate Manual (Priority: P1) — MVP

**Goal**: The NC endorsement catalogue contains exactly three endorsements (ALTA 5, ALTA 8.1, ALTA 9), each priced at $23.00 flat. All other previously-defined NC endorsements are gone.

**Independent Test**: Reseed the database (`bundle exec bin/ratenode seed`) then run `bundle exec rspec`. Confirm all CSV scenario tests pass. Manually verify NC endorsement count and pricing per quickstart.md verification command 2.

### Implementation for User Story 1

T002 (in Phase 2) is the sole implementation task for this story. The endorsement catalogue is entirely seed-data driven; no calculator or model code changes are required for US1.

**Checkpoint**: US1 is complete after T002. Reseed and run tests to confirm.

---

## Phase 4: User Story 2 - Policy Type Symbol Unified Across All States (Priority: P2)

**Goal**: The symbol `:homeowners` (with trailing "s") is used consistently in all state rule multiplier maps, both PolicyType constants, and all calculator display methods. AZ is already correct and must not be touched.

**Independent Test**: After all T003–T005 edits, run `bundle exec rspec`. All CSV scenario tests must pass — in particular the six AZ `homeowners` scenarios that already use the new symbol. Manually verify per quickstart.md verification command 3.

### Implementation for User Story 2

All four tasks below edit different files and carry no mutual dependencies. They can be executed in any order or in parallel.

- [x] T003 [P] [US2] In `lib/ratenode/state_rules.rb`: rename the `:homeowner` key to `:homeowners` in the `policy_type_multipliers` hash for CA (line 44), NC (line 69), TX (line 94), and FL (line 119). Do NOT touch AZ (already `:homeowners`) and do NOT touch DEFAULT_STATE_RULES (line 203, explicitly out of scope per spec Assumptions).
- [x] T004 [P] [US2] In `lib/ratenode/models/policy_type.rb`: in the TYPES constant (line 11), change the key from `:homeowner` to `:homeowners` and the `name` value from `"homeowner"` to `"homeowners"`. Apply the same rename to the NC_TYPES constant (line 18). The `multiplier` values (1.10 and 1.20 respectively) must remain unchanged.
- [x] T005 [P] [US2] In each of the four calculator files, rename the `when :homeowner` branch to `when :homeowners` in the `format_policy_type` case statement. The display string `"Homeowner's"` stays the same — only the symbol changes. Files and lines: `lib/ratenode/calculators/states/ca.rb` line 127, `lib/ratenode/calculators/states/fl.rb` line 219, `lib/ratenode/calculators/states/nc.rb` line 164, `lib/ratenode/calculators/states/tx.rb` line 128. Do NOT touch `lib/ratenode/calculators/states/az.rb` (already correct at line 233).

**Checkpoint**: US2 is complete after T003–T005. Run tests to confirm AZ homeowners scenarios still pass and no state falls back to 1.0.

---

## Phase 5: User Story 3 - NC Minimum Premium and Rounding Enforced (Priority: P3)

**Goal**: NC state rules reflect the rate manual PR-1 values: minimum premium $56.00 (5600 cents) and rounding increment $1,000 (100_000 cents). Existing NC CSV scenarios (all at $500K liability) are unaffected.

**Independent Test**: Run `bundle exec rspec` — all existing NC scenarios must produce identical results. Manually verify per quickstart.md verification command 4. New scenarios exercising the minimum and rounding boundaries require human-provided expected values and are blocked by FR-007; a placeholder note is included in T007.

### Implementation for User Story 3

- [x] T006 [US3] In `lib/ratenode/state_rules.rb`, inside the NC → underwriters → DEFAULT block: change `minimum_premium_cents` from `0` to `5_600` (line 66) and change `rounding_increment_cents` from `1_000_000` to `100_000` (line 64). No other values in this block should change. (Note: the `:homeowner` → `:homeowners` rename in the same block is handled by T003.)

- [x] T007 [US3] **🚧 HUMAN GATE — documented, not code.** Document the following scenario stubs in a comment at the bottom of `specs/004-fix-nc-config/quickstart.md` (below the existing "New test scenarios" table): the three scenarios NC_minimum_premium_edge, NC_rounding_1000, and NC_rounding_exact require a human to calculate expected premiums from the NC rate manual (PR-1) and add them as rows to `spec/fixtures/scenarios_input.csv`. This task is a reminder, not a code change.

**Checkpoint**: US3 configuration is live after T006. Full validation awaits human-provided expected values (T007).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Reseed, run the full suite, and verify all contracts from `contracts/README.md` hold.

- [x] T008 Reseed the database and run the full test suite: `bundle exec bin/ratenode seed && bundle exec rspec`. All tests must pass with zero failures and zero modifications to `spec/fixtures/scenarios_input.csv`.
- [x] T009 Run each of the four verification commands from `quickstart.md` and confirm output matches expected values. Report any discrepancies.

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
  └── Phase 2 (T002 — NC endorsement seed)
        ├── Phase 3 (US1 checkpoint — no additional code)
        └── Phase 5 (T006 — NC state rules, same file block as T003)

Phase 1 (Setup)
  └── Phase 4 (T003, T004, T005 — US2, all independent files)

Phase 3 + Phase 4 + Phase 5
  └── Phase 6 (Polish — full reseed + test suite)
```

### User Story Dependencies

- **User Story 1 (P1)**: Depends only on Phase 1. Single task (T002). No dependency on US2 or US3.
- **User Story 2 (P2)**: Depends only on Phase 1. T003–T005 are mutually independent and independent of US1/US3.
- **User Story 3 (P3)**: Depends on Phase 1. T006 edits the same NC block in `state_rules.rb` that T003 touches — run T003 first (or together, since they edit different keys in the same block and do not conflict).

### Parallel Opportunities

```
After T001 passes:
  ├── T002 (US1 — nc_rates.rb)               ← independent file
  ├── T003 (US2 — state_rules.rb keys)       ← independent keys
  ├── T004 (US2 — policy_type.rb)            ← independent file
  └── T005 (US2 — 4 calculator files)        ← independent files

After T002 + T003:
  └── T006 (US3 — state_rules.rb values)     ← same block, different keys from T003

After T002 + T003 + T004 + T005 + T006:
  └── T008 → T009 (Polish)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Run T001 — confirm baseline green
2. Run T002 — replace NC endorsement seed data
3. Reseed + run tests — confirm US1 is independently valid
4. **STOP and VALIDATE**: NC endorsement catalogue is corrected. Ship if only P1 is needed.

### Incremental Delivery

1. T001 → T002 (US1 complete) → validate
2. T003 + T004 + T005 in parallel (US2 complete) → validate
3. T006 (US3 config live) → validate existing tests
4. T007 (human gate) — wait for rate-manual expected values
5. T008 + T009 (full reseed + verification)

---

## Notes

- [P] tasks touch different files (or different keys) and can run in parallel
- [Story] label maps each task to its user story for traceability
- `spec/fixtures/scenarios_input.csv` MUST NOT be modified by any task here (Principle V)
- T007 is a human-gate marker; it produces no code change
- DEFAULT_STATE_RULES in `state_rules.rb` is intentionally left unchanged (out of scope per spec Assumptions)
- After T003 + T004, the database `policy_types` table will still contain rows with `name = "homeowner"` from prior seeds. A `db:seed` (T008) will re-insert with the correct `"homeowners"` name via `INSERT OR IGNORE`; the old rows are harmless because `multiplier_for` checks `STATE_RULES` before the database.
