# Tasks: Extract State Calculators into Plugin Architecture

**Input**: Design documents from `/specs/001-extract-state-calculators/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: No test tasks included (not explicitly requested in specification). Existing CSV scenario tests serve as the regression safety net.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Per plan.md structure:
- Source: `lib/ratenode/calculators/`
- States: `lib/ratenode/calculators/states/`
- Utilities: `lib/ratenode/calculators/utilities/`
- Specs: `spec/unit/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure

- [ ] T001 Create directory structure `lib/ratenode/calculators/states/` and `lib/ratenode/calculators/utilities/`
- [ ] T002 Create `spec/unit/` directory for unit tests with subdirectory `spec/unit/utilities/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Implement `BaseStateCalculator` abstract contract in `lib/ratenode/calculators/base_state_calculator.rb` per contracts/base_state_calculator.rb
- [ ] T004 Implement `StateCalculatorFactory` in `lib/ratenode/calculators/state_calculator_factory.rb` per contracts/state_calculator_factory.rb (initially with empty state list)
- [ ] T005 [P] Implement `Utilities::Rounding` module in `lib/ratenode/calculators/utilities/rounding.rb` per contracts/utilities.rb
- [ ] T006 [P] Implement `Utilities::TierLookup` module in `lib/ratenode/calculators/utilities/tier_lookup.rb` per contracts/utilities.rb
- [ ] T007 Add require statements to `lib/ratenode/ratenode.rb` for new calculators, utilities, and states modules
- [ ] T008 Verify foundation with `bundle exec rspec` - all existing tests must still pass (no behavioral changes yet)

**Checkpoint**: Foundation ready - state calculator implementation can now begin

**⏸️ PAUSE**: Confirm foundation works before proceeding.

---

## Phase 3: User Story 3 - Calculate Premium Using Correct State Logic (Priority: P1) 🎯 MVP

**Goal**: Route premium calculation requests to the correct state-specific calculator based on state parameter

**Why First**: This story requires implementing all 5 state calculators - it's the core runtime functionality that US1 and US2 depend on

**Independent Test**: Call factory with each supported state code and verify correct calculator handles the request

### Implementation for User Story 3

#### State Calculator: Arizona (AZ)

- [ ] T009 [P] [US3] Create `States::AZ` calculator in `lib/ratenode/calculators/states/az.rb` implementing `calculate_owners_premium` with hold-open logic, TRG/ORT region handling, rounding per existing `az_calculator.rb`
- [ ] T010 [P] [US3] Implement `calculate_lenders_premium` in `lib/ratenode/calculators/states/az.rb` with flat fee and concurrent ELC config logic

#### State Calculator: Florida (FL)

- [ ] T011 [P] [US3] Create `States::FL` calculator in `lib/ratenode/calculators/states/fl.rb` implementing `calculate_owners_premium` with reissue rate table split calculation logic from `owners_policy.rb`
- [ ] T012 [P] [US3] Implement `calculate_lenders_premium` in `lib/ratenode/calculators/states/fl.rb` with flat fee + excess rate when loan > owner logic

#### State Calculator: California (CA)

- [ ] T013 [P] [US3] Create `States::CA` calculator in `lib/ratenode/calculators/states/ca.rb` implementing `calculate_owners_premium` with simple calculation and $3M+ handling logic from `owners_policy.rb`
- [ ] T014 [P] [US3] Implement `calculate_lenders_premium` in `lib/ratenode/calculators/states/ca.rb` with flat fee + excess rate logic

#### State Calculator: Texas (TX)

- [ ] T015 [P] [US3] Create `States::TX` calculator in `lib/ratenode/calculators/states/tx.rb` implementing `calculate_owners_premium` with formula-based rates (>$100k) and no rounding per `owners_policy.rb` and `rate_tier.rb`
- [ ] T016 [P] [US3] Implement `calculate_lenders_premium` in `lib/ratenode/calculators/states/tx.rb` with flat fee + excess rate logic

#### State Calculator: North Carolina (NC)

- [ ] T017 [P] [US3] Create `States::NC` calculator in `lib/ratenode/calculators/states/nc.rb` implementing `calculate_owners_premium` with percentage-based reissue discount (50%) per `owners_policy.rb` - preserve current behavior, add TODO for NC reissue bug (FR-013)
- [ ] T018 [P] [US3] Implement `calculate_lenders_premium` in `lib/ratenode/calculators/states/nc.rb` with always flat fee when concurrent logic

#### Factory Integration

- [ ] T019 [US3] Update `StateCalculatorFactory` in `lib/ratenode/calculators/state_calculator_factory.rb` to register all 5 state calculators (AZ, FL, CA, TX, NC)
- [ ] T020 [US3] Add require statements for all state calculators in `lib/ratenode/ratenode.rb`

#### Integration with Existing Callers

- [ ] T021 [US3] Update `lib/ratenode/calculator.rb` to use `StateCalculatorFactory.for(state)` instead of direct `AZCalculator` or `OwnersPolicy` instantiation
- [ ] T022 [US3] Update `lib/ratenode/calculators/base_rate.rb` to delegate rounding to `Utilities::Rounding`
- [ ] T023 [US3] Update `lib/ratenode/calculators/lenders_policy.rb` to delegate state logic to appropriate state calculators via factory
- [ ] T024 [US3] Update `lib/ratenode/calculators/cpl_calculator.rb` to delegate state logic to appropriate state calculators via factory
- [ ] T025 [US3] Update `lib/ratenode/models/rate_tier.rb` to delegate TX formula logic to `States::TX` calculator

#### Verification

- [ ] T026 [US3] Run `bundle exec rspec spec/integration/csv_scenarios_spec.rb` - all 40+ CSV scenario tests must pass
- [ ] T027 [US3] Verify factory returns correct calculator type for each state code (AZ, FL, CA, TX, NC)
- [ ] T028 [US3] Verify `UnsupportedStateError` raised for invalid state codes

**Checkpoint**: User Story 3 complete - premium routing works for all 5 states, all existing tests pass

**⏸️ IMPLEMENTATION PAUSE POINT**: Stop here after Phase 3. MVP is complete and verified. Resume in new conversation if needed.

---

## Phase 4: User Story 2 - Fix State-Specific Bug Without Risk (Priority: P1)

**Goal**: Enable bug fixes in one state's calculation without affecting other states

**Why After US3**: Requires state calculators to exist before demonstrating isolation

**Independent Test**: Modify NC calculator and verify only NC-related behavior can change

### Implementation for User Story 2

- [ ] T029 [US2] Document NC reissue rate bug location with TODO comment in `lib/ratenode/calculators/states/nc.rb` including reproduction steps from research.md
- [ ] T030 [US2] Verify state isolation: confirm each state calculator file has no imports from other state calculators
- [ ] T031 [US2] Verify no cross-state conditionals exist in individual state calculator files

**Checkpoint**: User Story 2 complete - state calculators are isolated, NC bug documented for future fix

**⏸️ PAUSE**: Confirm isolation before proceeding.

---

## Phase 5: User Story 1 - Add a New State Calculator (Priority: P1)

**Goal**: Enable adding new state support by creating a single file without modifying existing code

**Why After US3**: Architecture must be proven working before validating extensibility

**Independent Test**: Create a mock state calculator, register it, verify it works without touching existing states

### Implementation for User Story 1

- [ ] T032 [US1] Verify `BaseStateCalculator` contract is documented with YARD in `lib/ratenode/calculators/base_state_calculator.rb` so developers understand required methods
- [ ] T033 [US1] Verify quickstart.md "Adding a New State" guide matches actual implementation patterns
- [ ] T034 [US1] Confirm file/naming convention is established: `lib/ratenode/calculators/states/{state_code}.rb` with class `States::{STATE_CODE}`

**Checkpoint**: User Story 1 complete - new states can be added by creating one file + factory registration

**⏸️ PAUSE**: Confirm extensibility before proceeding.

---

## Phase 6: User Story 4 - Access Shared Utilities Across States (Priority: P2)

**Goal**: Enable state calculators to use shared utilities without code duplication

**Why Last**: Lower priority, builds on foundation already established

**Independent Test**: Verify multiple state calculators use same utility functions and produce consistent results

### Implementation for User Story 4

- [ ] T035 [US4] Verify `Utilities::Rounding.round_up` is used by AZ (TRG: $5k, ORT: $20k), CA, FL, NC (default $10k)
- [ ] T036 [US4] Verify `Utilities::Rounding` is not used by TX (no rounding) - TX passes through unchanged
- [ ] T037 [US4] Verify `Utilities::TierLookup.calculate_tiered_rate` is used by FL and NC for tiered rates
- [ ] T038 [US4] Verify `Utilities::TierLookup.find_bracket` is used by CA for bracket lookup
- [ ] T039 [US4] Confirm duplicate `rounded_liability` logic removed from `base_rate.rb` and consolidated in `Utilities::Rounding`

**Checkpoint**: User Story 4 complete - shared utilities consolidated, no duplicate rounding logic

**⏸️ PAUSE**: Confirm utilities before cleanup.

---

## Phase 7: Cleanup & Removal

**Purpose**: Remove deprecated code paths after migration is verified complete

- [ ] T040 [P] Delete `lib/ratenode/calculators/az_calculator.rb` - logic migrated to `states/az.rb`
- [ ] T041 [P] Delete `lib/ratenode/calculators/owners_policy.rb` - logic split across `states/fl.rb`, `states/ca.rb`, `states/tx.rb`, `states/nc.rb`
- [ ] T042 Run final verification: `bundle exec rspec` - all tests must pass after file removal
- [ ] T043 Verify no remaining references to deleted `AZCalculator` or `OwnersPolicy` classes in codebase

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation

- [ ] T044 [P] Verify Constitution compliance: all 6 principles pass per plan.md checklist, specifically confirm Principle I (no cross-state imports in `states/*.rb`), Principle III (only Rounding/TierLookup extracted), Principle V (`scenarios_input.csv` unchanged)
- [ ] T045 [P] Run quickstart.md validation - verify all code examples work as documented
- [ ] T046 Create tracking issue for NC reissue rate bug fix (post-refactor task per FR-013)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 3 (Phase 3)**: Depends on Foundational - FIRST because it implements core functionality
- **User Story 2 (Phase 4)**: Depends on User Story 3 - verifies isolation after calculators exist
- **User Story 1 (Phase 5)**: Depends on User Story 3 - validates extensibility of working architecture
- **User Story 4 (Phase 6)**: Depends on User Story 3 - validates utility sharing
- **Cleanup (Phase 7)**: Depends on all user stories - removes deprecated code
- **Polish (Phase 8)**: Depends on Cleanup - final validation

### Within Phase 3 (State Calculators)

- All state calculator tasks (T009-T018) can run in parallel - different files
- Factory integration (T019-T020) must wait for state calculators
- Caller updates (T021-T025) can run in parallel after factory integration
- Verification (T026-T028) must be last

### Parallel Opportunities

**Phase 2 (Foundational)**:
```
T003 BaseStateCalculator
T004 StateCalculatorFactory
T005 Utilities::Rounding       [P]
T006 Utilities::TierLookup     [P]
```

**Phase 3 (State Calculators)** - All 5 states can be implemented in parallel:
```
T009-T010 States::AZ           [P]
T011-T012 States::FL           [P]
T013-T014 States::CA           [P]
T015-T016 States::TX           [P]
T017-T018 States::NC           [P]
```

**Phase 3 (Caller Updates)** - All caller updates can run in parallel:
```
T021 calculator.rb             [P]
T022 base_rate.rb              [P]
T023 lenders_policy.rb         [P]
T024 cpl_calculator.rb         [P]
T025 rate_tier.rb              [P]
```

**Phase 7 (Cleanup)** - Deletions can run in parallel:
```
T040 Delete az_calculator.rb   [P]
T041 Delete owners_policy.rb   [P]
```

---

## Implementation Strategy

### MVP First (User Story 3 - Core Routing)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T008)
3. Complete Phase 3: User Story 3 - All state calculators + integration (T009-T028)
4. **STOP and VALIDATE**: Run `bundle exec rspec` - all 40+ CSV tests must pass
5. This delivers a working plugin architecture with all 5 states

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. User Story 3 → Core routing works → **MVP complete!**
3. User Story 2 → Bug isolation verified → Confidence in isolation
4. User Story 1 → Extensibility documented → Ready for new states
5. User Story 4 → Utilities validated → No code duplication
6. Cleanup → Remove deprecated code → Clean codebase
7. Polish → Final validation → Ready for merge

### Critical Constraints

- **CSV scenarios protected**: Do not modify `spec/fixtures/scenarios_input.csv` (Constitution Principle V)
- **No cross-state dependencies**: State calculators must not import from each other
- **Utilities limited**: Only pre-approved utilities (rounding, tier lookup) per Constitution Principle III
- **Preserve behavior**: This is a pure structural refactor - all existing tests must pass unchanged

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- NC reissue bug preserved during refactor, tracked separately (FR-013)
- All 40+ existing CSV scenario tests serve as regression safety net
- No new test scenarios needed (refactor only, no behavioral changes)
