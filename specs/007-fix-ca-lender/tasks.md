# Tasks: Fix CA Lender Policy Calculation Bugs

**Input**: Design documents from `/specs/007-fix-ca-lender/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: This feature includes RSpec unit tests. CSV scenario tests require human-provided expected values per Constitution Principle V.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each bug fix.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- Ruby CLI application at repository root
- Source: `lib/ratenode/`
- Tests: `spec/`
- Configuration: `lib/ratenode/state_rules.rb`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: No project initialization needed - this is a bug fix to existing code

*No setup tasks required - all infrastructure already exists*

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Configuration changes that ALL user stories depend on

**⚠️ CRITICAL**: These configuration keys must be added before ANY bug fix can be implemented

- [x] T001 Add standalone_lender_standard_percent (80.0) for TRG in lib/ratenode/state_rules.rb CA section
- [x] T002 Add standalone_lender_extended_percent (90.0) for TRG in lib/ratenode/state_rules.rb CA section
- [x] T003 Add concurrent_standard_excess_percent (80.0) for TRG in lib/ratenode/state_rules.rb CA section
- [x] T004 Add standalone_lender_standard_percent (75.0) for ORT in lib/ratenode/state_rules.rb CA section
- [x] T005 Add standalone_lender_extended_percent (85.0) for ORT in lib/ratenode/state_rules.rb CA section
- [x] T006 Add concurrent_standard_excess_percent (75.0) for ORT in lib/ratenode/state_rules.rb CA section

**Checkpoint**: Configuration ready - bug fix implementation can now begin

---

## Phase 3: User Story 1 - Accurate Standalone Lender Policy Rates (Priority: P1) 🎯

**Goal**: Fix standalone lender policy calculations to apply underwriter-specific multipliers (80% TRG / 75% ORT for Standard; 90% TRG / 85% ORT for Extended)

**Independent Test**: Request a standalone lender policy quote for any loan amount and verify the rate is 80% (TRG) or 75% (ORT) of the base rate for Standard coverage, or 90% (TRG) or 85% (ORT) for Extended coverage.

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T007 [P] [US1] Add RSpec test for TRG Standard standalone (80% multiplier) in spec/calculators/states/ca_spec.rb
- [x] T008 [P] [US1] Add RSpec test for ORT Standard standalone (75% multiplier) in spec/calculators/states/ca_spec.rb
- [x] T009 [P] [US1] Add RSpec test for TRG Extended standalone (90% multiplier) in spec/calculators/states/ca_spec.rb
- [x] T010 [P] [US1] Add RSpec test for ORT Extended standalone (85% multiplier) in spec/calculators/states/ca_spec.rb
- [x] T011 [P] [US1] Add RSpec test for $0 loan amount returns $0 premium in spec/calculators/states/ca_spec.rb

### Implementation for User Story 1

- [x] T012 [US1] Modify calculate_lenders_premium to detect standalone (non-concurrent) lender policies in lib/ratenode/calculators/states/ca.rb
- [x] T013 [US1] Add logic to fetch standalone_lender_standard_percent or standalone_lender_extended_percent from state rules based on lender_policy_type in lib/ratenode/calculators/states/ca.rb
- [x] T014 [US1] Implement standalone calculation as (BaseRate.calculate × multiplier / 100.0).round in lib/ratenode/calculators/states/ca.rb
- [x] T015 [US1] Add guard clause to return 0 when loan_amount_cents == 0 in lib/ratenode/calculators/states/ca.rb
- [x] T016 [US1] Verify all US1 tests pass - run bundle exec rspec spec/calculators/states/ca_spec.rb

**Checkpoint**: Standalone lender policy calculations now apply correct underwriter multipliers - US1 complete and independently testable

---

## Phase 4: User Story 2 - Correct Concurrent Lender Excess Calculation (Priority: P1)

**Goal**: Fix concurrent Standard lender policy excess calculation to use $150 + percentage × (rate_difference) instead of ELC lookup on excess amount

**Independent Test**: Request a concurrent lender policy quote with loan > owner liability (e.g., owner $400K, loan $500K) and verify the premium equals $150 + 80% × (rate(loan) - rate(owner)) for TRG or $150 + 75% × (rate(loan) - rate(owner)) for ORT.

### Tests for User Story 2 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T017 [P] [US2] Add RSpec test for TRG concurrent Standard with excess (loan > owner) expecting $150 + 80% × rate_diff in spec/calculators/states/ca_spec.rb
- [x] T018 [P] [US2] Add RSpec test for ORT concurrent Standard with excess (loan > owner) expecting $150 + 75% × rate_diff in spec/calculators/states/ca_spec.rb
- [x] T019 [P] [US2] Add RSpec test for concurrent Standard with loan <= owner expecting $150 flat fee in spec/calculators/states/ca_spec.rb
- [x] T020 [P] [US2] Add RSpec test for $150 minimum enforcement using max(concurrent_fee, total) in spec/calculators/states/ca_spec.rb
- [x] T021 [P] [US2] Add RSpec test for TRG $400K owner / $500K loan returning $309.20 (validates bug fix) in spec/calculators/states/ca_spec.rb

### Implementation for User Story 2

- [x] T022 [US2] Modify calculate_lenders_premium to detect concurrent Standard lender policies (concurrent: true && lender_policy_type: :standard) in lib/ratenode/calculators/states/ca.rb
- [x] T023 [US2] Add check for loan_amount_cents <= owner_liability_cents to return concurrent_base_fee_cents ($150) in lib/ratenode/calculators/states/ca.rb
- [x] T024 [US2] For loan > owner, calculate rate_loan and rate_owner using BaseRate.calculate for both amounts in lib/ratenode/calculators/states/ca.rb
- [x] T025 [US2] Calculate rate_diff = rate_loan - rate_owner in lib/ratenode/calculators/states/ca.rb
- [x] T026 [US2] Fetch concurrent_standard_excess_percent from state rules and calculate excess_rate = (rate_diff × percent / 100.0).round in lib/ratenode/calculators/states/ca.rb
- [x] T027 [US2] Calculate final premium as [concurrent_base_fee_cents, concurrent_base_fee_cents + excess_rate].max to enforce $150 minimum in lib/ratenode/calculators/states/ca.rb
- [x] T028 [US2] Remove old ELC lookup logic for concurrent Standard excess (this was the bug) in lib/ratenode/calculators/states/ca.rb
- [x] T029 [US2] Verify all US2 tests pass - run bundle exec rspec spec/calculators/states/ca_spec.rb

**Checkpoint**: Concurrent Standard lender excess now uses rate difference formula - US2 complete and independently testable

---

## Phase 5: User Story 3 - Extended Concurrent Lender Policy Support (Priority: P2)

**Goal**: Enable Extended concurrent lender policies via full ELC rate table lookup (not $150 + excess formula)

**Independent Test**: Request a concurrent Extended lender policy quote for any loan amount and verify the rate is calculated using the full ELC rate table (not $150 + excess).

### Tests for User Story 3 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T030 [P] [US3] Add RSpec test for TRG Extended concurrent using full ELC rate lookup in spec/calculators/states/ca_spec.rb
- [x] T031 [P] [US3] Add RSpec test for ORT Extended concurrent using full ELC rate lookup in spec/calculators/states/ca_spec.rb
- [x] T032 [P] [US3] Add RSpec test verifying Extended concurrent does NOT use $150 + excess formula in spec/calculators/states/ca_spec.rb

### Implementation for User Story 3

- [x] T033 [US3] Modify calculate_lenders_premium to detect concurrent Extended lender policies (concurrent: true && lender_policy_type: :extended) in lib/ratenode/calculators/states/ca.rb
- [x] T034 [US3] Add routing logic: if Extended concurrent, use full ELC rate lookup via BaseRate.calculate_elc(loan_amount_cents) in lib/ratenode/calculators/states/ca.rb
- [x] T035 [US3] Ensure Standard concurrent still uses $150 + excess formula (maintains US2 fix) in lib/ratenode/calculators/states/ca.rb
- [x] T036 [US3] Verify all US3 tests pass - run bundle exec rspec spec/calculators/states/ca_spec.rb

**Checkpoint**: Extended concurrent lender policies now supported via ELC lookup - US3 complete and independently testable

---

## Phase 6: User Story 4 - No Lender Policy on Cash Acquisitions (Priority: P2)

**Goal**: Skip lender policy calculation when is_hold_open flag is true (cash purchases don't have lenders)

**Independent Test**: Request a quote for a cash purchase (is_hold_open: true) and verify no lender policy is included in the output.

### Tests for User Story 4 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T037 [P] [US4] Add RSpec test for is_hold_open: true returning $0 lender premium in spec/calculators/states/ca_spec.rb
- [x] T038 [P] [US4] Add RSpec test for include_lenders_policy: false returning $0 lender premium in spec/calculators/states/ca_spec.rb
- [x] T039 [P] [US4] Add RSpec test for is_hold_open: true taking precedence over include_lenders_policy: true in spec/calculators/states/ca_spec.rb

### Implementation for User Story 4

- [x] T040 [US4] Add guard clause at start of calculate_lenders_premium: return 0 if params[:is_hold_open] == true in lib/ratenode/calculators/states/ca.rb
- [x] T041 [US4] Add guard clause: return 0 if params[:include_lenders_policy] == false (after is_hold_open check) in lib/ratenode/calculators/states/ca.rb
- [x] T042 [US4] Verify all US4 tests pass - run bundle exec rspec spec/calculators/states/ca_spec.rb

**Checkpoint**: Cash acquisitions now correctly skip lender policy calculation - US4 complete and independently testable

---

## Phase 7: Edge Cases & Validation

**Goal**: Handle edge cases and add input validation

**Independent Test**: Verify system handles invalid inputs and edge cases gracefully

### Tests for Edge Cases ⚠️

- [x] T043 [P] Add RSpec test for negative loan amount raising ArgumentError in spec/calculators/states/ca_spec.rb
- [x] T044 [P] Add RSpec test for missing underwriter raising ArgumentError in spec/calculators/states/ca_spec.rb
- [x] T045 [P] Add RSpec test for invalid lender_policy_type raising ArgumentError in spec/calculators/states/ca_spec.rb
- [x] T046 [P] Add RSpec test for rate lookup failure propagating error in spec/calculators/states/ca_spec.rb

### Implementation for Edge Cases

- [x] T047 Add validation: raise ArgumentError if loan_amount_cents < 0 in lib/ratenode/calculators/states/ca.rb
- [x] T048 Add validation: raise ArgumentError if lender_policy_type not in [:standard, :extended] in lib/ratenode/calculators/states/ca.rb
- [x] T049 Add validation: raise ArgumentError if concurrent && loan > owner but owner_liability_cents missing in lib/ratenode/calculators/states/ca.rb
- [x] T050 Verify edge case tests pass - run bundle exec rspec spec/calculators/states/ca_spec.rb

**Checkpoint**: Edge cases handled, input validation complete

---

## Phase 8: CSV Scenario Testing (Human Input Required)

**Purpose**: Add CSV test scenarios with human-validated expected values

**⚠️ CRITICAL**: Per Constitution Principle V, human must provide expected values from rate manuals

### CSV Schema Updates

- [ ] T051 Stop and notify user: CSV schema change needed - add lender_policy_type column to spec/fixtures/scenarios_input.csv
- [ ] T052 Stop and notify user: CSV schema change needed - add is_hold_open column to spec/fixtures/scenarios_input.csv
- [ ] T053 Wait for user to approve CSV schema changes before proceeding

### CSV Test Scenarios (After Human Approval)

- [ ] T054 [P] Add CSV scenario for TRG standalone Standard lender $500K (expected: human-provided from rate manual) in spec/fixtures/scenarios_input.csv
- [ ] T055 [P] Add CSV scenario for ORT standalone Standard lender $500K (expected: human-provided from rate manual) in spec/fixtures/scenarios_input.csv
- [ ] T056 [P] Add CSV scenario for TRG standalone Extended lender $500K (expected: human-provided from rate manual) in spec/fixtures/scenarios_input.csv
- [ ] T057 [P] Add CSV scenario for ORT standalone Extended lender $500K (expected: human-provided from rate manual) in spec/fixtures/scenarios_input.csv
- [ ] T058 [P] Add CSV scenario for TRG concurrent Standard with excess - owner $400K, loan $500K (expected: $309.20 from rate manual) in spec/fixtures/scenarios_input.csv
- [ ] T059 [P] Add CSV scenario for ORT concurrent Standard with excess - owner $400K, loan $500K (expected: human-provided from rate manual) in spec/fixtures/scenarios_input.csv
- [ ] T060 [P] Add CSV scenario for TRG concurrent Standard no excess - owner $500K, loan $400K (expected: $150 flat) in spec/fixtures/scenarios_input.csv
- [ ] T061 [P] Add CSV scenario for TRG Extended concurrent with Standard owner (expected: human-provided from ELC table) in spec/fixtures/scenarios_input.csv
- [ ] T062 [P] Add CSV scenario for cash acquisition is_hold_open: true (expected: $0 lender premium) in spec/fixtures/scenarios_input.csv
- [ ] T063 [P] Add CSV scenario for $0 loan amount (expected: $0 lender premium) in spec/fixtures/scenarios_input.csv
- [ ] T064 Run CSV scenario tests - bundle exec rspec spec/scenario_spec.rb

**Checkpoint**: CSV scenarios validated against rate manuals - all tests pass

---

## Phase 9: Polish & Documentation

**Purpose**: Code cleanup, documentation, and final validation

- [ ] T065 [P] Add rate manual references as comments in calculate_lenders_premium method (TRG lines 176-240, ORT lines 252-348) in lib/ratenode/calculators/states/ca.rb
- [ ] T066 [P] Add plain-language explanation comments for each calculation path in lib/ratenode/calculators/states/ca.rb
- [ ] T067 [P] Update CLAUDE.md with new configuration keys from this feature
- [x] T068 Run full test suite - bundle exec rspec
- [ ] T069 Validate quickstart.md examples manually
- [ ] T070 Manual validation: TRG $400K owner / $500K loan returns $309.20 (not $648) - confirms Bug Fix 2

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Not applicable - infrastructure exists
- **Foundational (Phase 2)**: No dependencies - can start immediately - BLOCKS all user stories
- **User Stories (Phase 3-6)**: All depend on Foundational phase (T001-T006) completion
  - User Story 1 (US1): Can start after Phase 2 - No dependencies on other stories
  - User Story 2 (US2): Can start after Phase 2 - No dependencies on other stories
  - User Story 3 (US3): Can start after Phase 2 - No dependencies on other stories
  - User Story 4 (US4): Can start after Phase 2 - No dependencies on other stories
- **Edge Cases (Phase 7)**: Can start after Phase 2 - No dependencies on user stories
- **CSV Testing (Phase 8)**: Depends on ALL user stories being complete (Phase 3-6)
- **Polish (Phase 9)**: Depends on all previous phases

### User Story Dependencies

- **User Story 1 (P1)**: Independent - can test standalone lender multipliers alone
- **User Story 2 (P1)**: Independent - can test concurrent excess formula alone
- **User Story 3 (P2)**: Independent - can test Extended concurrent alone
- **User Story 4 (P2)**: Independent - can test binder acquisition flag alone

**Note**: All user stories fix different code paths within the same method, so while they are logically independent, they modify the same file (lib/ratenode/calculators/states/ca.rb) and must be implemented sequentially.

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Implementation tasks must be done in order (guard clauses → detection logic → calculation logic → validation)
- Tests must pass before moving to next user story

### Parallel Opportunities

- Phase 2 (T001-T006): All state_rules.rb additions can be done together in one edit
- Tests within a user story: All test tasks marked [P] can be written in parallel
- Edge case tests (T043-T046): Can all be written in parallel
- CSV scenarios (T054-T063): Can all be added in parallel (after human provides expected values)
- Documentation tasks (T065-T067): Can be done in parallel

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
# - RSpec test for TRG Standard standalone (80% multiplier)
# - RSpec test for ORT Standard standalone (75% multiplier)
# - RSpec test for TRG Extended standalone (90% multiplier)
# - RSpec test for ORT Extended standalone (85% multiplier)
# - RSpec test for $0 loan amount returns $0 premium
```

---

## Implementation Strategy

### MVP First (User Stories 1 & 2 Only - Both P1)

1. Complete Phase 2: Foundational (state_rules.rb configuration)
2. Complete Phase 3: User Story 1 (standalone multipliers)
3. **VALIDATE**: Test standalone lender policies independently
4. Complete Phase 4: User Story 2 (concurrent excess formula)
5. **VALIDATE**: Test the $400K owner / $500K loan example - should return $309.20 not $648
6. **STOP**: MVP addresses the two most critical bugs (20-109% overcharges)

### Full Feature Delivery

1. Complete Foundational → Configuration ready
2. Add User Story 1 → Test independently → Validates standalone calculations
3. Add User Story 2 → Test independently → Validates concurrent excess (fixes 109% overcharge)
4. Add User Story 3 → Test independently → Enables Extended concurrent product
5. Add User Story 4 → Test independently → Fixes cash acquisition quotes
6. Add Edge Cases → Validates input handling
7. Add CSV Scenarios → Comprehensive regression testing
8. Polish & Documentation → Production ready

### Sequential Implementation (Recommended)

Since all user stories modify the same method (calculate_lenders_premium), implement sequentially:

1. Complete Phase 2 (Foundational)
2. Complete Phase 3 (US1) → Validate → Commit
3. Complete Phase 4 (US2) → Validate → Commit
4. Complete Phase 5 (US3) → Validate → Commit
5. Complete Phase 6 (US4) → Validate → Commit
6. Complete Phase 7 (Edge Cases) → Validate → Commit
7. Complete Phase 8 (CSV Testing - requires human input)
8. Complete Phase 9 (Polish)

---

## Task Summary

- **Total Tasks**: 70
- **Foundational Tasks**: 6 (configuration keys)
- **User Story 1 (P1)**: 10 tasks (5 tests + 5 implementation)
- **User Story 2 (P1)**: 13 tasks (5 tests + 8 implementation)
- **User Story 3 (P2)**: 7 tasks (3 tests + 4 implementation)
- **User Story 4 (P2)**: 6 tasks (3 tests + 3 implementation)
- **Edge Cases**: 8 tasks (4 tests + 4 implementation)
- **CSV Testing**: 14 tasks (schema updates + 10 scenarios + test run)
- **Polish**: 6 tasks (documentation + validation)

**Parallel Opportunities Identified**:
- 6 state_rules.rb additions (Phase 2)
- 5 test tasks per user story (Phases 3-6)
- 4 edge case tests (Phase 7)
- 10 CSV scenario additions (Phase 8, after human approval)
- 3 documentation tasks (Phase 9)

**Independent Test Criteria**:
- US1: Standalone lender quotes return 80%/75% (Standard) or 90%/85% (Extended) of base rate
- US2: Concurrent excess returns $150 + percentage × rate_difference (not ELC lookup)
- US3: Extended concurrent uses ELC rate lookup (not $150 + formula)
- US4: Cash acquisitions return $0 lender premium

**Suggested MVP Scope**:
- Phase 2 (Foundational) + Phase 3 (US1) + Phase 4 (US2)
- This addresses the two most critical bugs causing overcharges (P1 priorities)
- Can deploy after validating the TRG $400K/$500K example returns $309.20

---

## Notes

- [P] tasks = different files, no dependencies (can run in parallel)
- [US#] label maps task to specific user story for traceability
- Each user story fixes a distinct bug and is independently testable
- All user stories modify lib/ratenode/calculators/states/ca.rb - implement sequentially
- CSV testing requires human-provided expected values per Constitution Principle V
- Verify tests fail before implementing (TDD approach)
- Commit after each user story completion
- Stop at any checkpoint to validate bug fix independently
