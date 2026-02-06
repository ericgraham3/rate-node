---
description: "Task list for CA Over-$3M Formulas and Minimum Premium implementation"
---

# Tasks: Fix CA Over-$3M Formulas and Minimum Premium

**Feature Branch**: `008-fix-ca-3m-formulas`
**Input**: Design documents from `/specs/008-fix-ca-3m-formulas/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/calculation_api.md, quickstart.md

**Tests**: Tests are OPTIONAL in this feature. The existing CSV scenario test infrastructure will be used to validate all changes.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

This is a Ruby CLI application with the following structure:
- **Implementation**: `lib/ratenode/`
- **Tests**: `spec/`
- **Rate manuals**: `docs/rate_manuals/ca/`

---

## Phase 1: Setup (Configuration Foundation)

**Purpose**: Add underwriter-specific formula parameters to state rules that all user stories depend on

- [x] T001 Add TRG formula parameters to state_rules.rb (7 parameters: minimum_premium_cents, over_3m_base_cents, over_3m_per_10k_cents, elc_over_3m_base_cents, elc_over_3m_per_10k_cents, refinance_over_10m_base_cents, refinance_over_10m_per_million_cents) in lib/ratenode/state_rules.rb
- [x] T002 Add ORT formula parameters to state_rules.rb (same 7 parameters as TRG but with ORT-specific values) in lib/ratenode/state_rules.rb

**Checkpoint**: Configuration ready - all formula parameters available via state_rules lookup

---

## Phase 2: Foundational (Core Formula Methods)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T003 Remove hardcoded TRG-only constants (OVER_3M_BASE_CENTS, OVER_3M_PER_10K_CENTS) from lib/ratenode/models/rate_tier.rb
- [x] T004 Update calculate_over_3m_rate method signature to accept state and underwriter parameters in lib/ratenode/models/rate_tier.rb
- [x] T005 Update calculate_over_3m_rate method body to retrieve parameters from state_rules using RateNode.rules_for in lib/ratenode/models/rate_tier.rb
- [x] T006 Rename calculate_elc_over_3m to calculate_elc_over_3m_rate and update signature to accept state and underwriter parameters in lib/ratenode/models/rate_tier.rb
- [x] T007 Update calculate_elc_over_3m_rate method body to retrieve parameters from state_rules using RateNode.rules_for in lib/ratenode/models/rate_tier.rb

**Checkpoint**: Foundation ready - formula methods accept underwriter parameters and retrieve correct configuration

---

## Phase 3: User Story 1 - Calculate Accurate Premiums for High-Value Properties (Priority: P1) 🎯 MVP

**Goal**: Enable accurate title insurance premium calculations for properties valued over $3 million in California, with different rates applied correctly for TRG and ORT underwriters.

**Independent Test**: Provide property values above $3M for both TRG and ORT underwriters and compare calculated premiums against rate manual specifications.

**Acceptance Scenarios**:
- TRG at $3.5M: $4,473.50 (base $4,211 + $5.25 per $10K increment × 50 = $262.50)
- ORT at $3.5M: $4,738 (base $4,438 + $6.00 per $10K increment × 50 = $300)
- Both underwriters produce different results per their respective rate manuals

### Implementation for User Story 1

- [x] T008 [US1] Update RateTier.calculate_rate call site to pass state and underwriter parameters when calling calculate_over_3m_rate (check for liability_cents > THREE_MILLION_CENTS && state == "CA") in lib/ratenode/models/rate_tier.rb
- [x] T009 [US1] Verify CA calculator's lookup_base_rate already passes underwriter through BaseRate initialization (no changes expected) in lib/ratenode/calculators/states/ca.rb
- [x] T010 [US1] Add unit test for calculate_over_3m_rate with TRG underwriter at $3.5M expecting 447_350 cents in spec/calculators/states/ca_spec.rb
- [x] T011 [US1] Add unit test for calculate_over_3m_rate with ORT underwriter at $3.5M expecting 473_800 cents in spec/calculators/states/ca_spec.rb
- [x] T012 [US1] Add unit test for calculate_over_3m_rate with TRG at $5M expecting 526_350 cents in spec/calculators/states/ca_spec.rb
- [x] T013 [US1] Add unit test for boundary condition at exactly $3M using tier lookup (not formula) in spec/calculators/states/ca_spec.rb
- [x] T014 [US1] Run existing CSV scenario tests to verify no regressions (spec/integration/csv_scenarios_spec.rb should pass within $2 tolerance)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Owner premiums above $3M calculate correctly for both underwriters.

---

## Phase 4: User Story 2 - Calculate Accurate Extended Lender Concurrent (ELC) Rates Above $3M (Priority: P1)

**Goal**: Enable correct ELC premium calculations for concurrent lender policies on high-value properties, with underwriter-specific formulas applied.

**Why critical**: Current formula produces rates that are ~99% too low (cents instead of dollars), making this a critical revenue leak.

**Independent Test**: Request concurrent lender policies above $3M and validate ELC premiums against rate manual specifications for each underwriter.

**Acceptance Scenarios**:
- ORT at $3.5M: $2,700 (base $2,550 + $3.00 per $10K increment × 50 = $150)
- TRG at $3.5M: $2,682 (base $2,472 + $4.20 per $10K increment × 50 = $210)
- ELC premiums are in thousands of dollars, not cents

### Implementation for User Story 2

- [x] T015 [US2] Update BaseRate.calculate_elc call site to pass state and underwriter parameters when calling calculate_elc_over_3m_rate for amounts > $3M in lib/ratenode/calculators/base_rate.rb
- [x] T016 [US2] Update RateTier.calculate_extended_lender_concurrent_rate to call calculate_elc_over_3m_rate with state and underwriter parameters for amounts > THREE_MILLION_CENTS in lib/ratenode/models/rate_tier.rb
- [x] T017 [US2] Add unit test for calculate_elc_over_3m_rate with TRG at $3.5M expecting 268_200 cents in spec/calculators/states/ca_spec.rb
- [x] T018 [US2] Add unit test for calculate_elc_over_3m_rate with ORT at $3.5M expecting 270_000 cents in spec/calculators/states/ca_spec.rb
- [x] T019 [US2] Add unit test for calculate_elc_over_3m_rate with TRG at $5M expecting 331_200 cents in spec/calculators/states/ca_spec.rb
- [x] T020 [US2] Add unit test for ELC boundary condition at exactly $3M using tier lookup (not formula) in spec/calculators/states/ca_spec.rb
- [x] T021 [US2] Run CSV scenario tests for concurrent lender policies above $3M to verify ELC premiums in thousands of dollars range

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently. ELC premiums calculate correctly and are in dollars, not cents.

---

## Phase 5: User Story 3 - Apply Correct Minimum Premium Floor (Priority: P2)

**Goal**: Enforce minimum premium for low-value properties to ensure compliance with underwriter rate schedules.

**Independent Test**: Calculate premiums for properties at very low liability amounts ($10K, $50K) and verify the minimum premium is enforced for each underwriter.

**Acceptance Scenarios**:
- TRG at $10K: $609 minimum enforced
- ORT at $10K: $725 minimum enforced
- Minimum applied before multipliers/surcharges

### Implementation for User Story 3

- [x] T022 [US3] Update calculate_standard method to retrieve minimum_premium_cents from state_rules after base_rate calculation in lib/ratenode/calculators/states/ca.rb
- [x] T023 [US3] Apply minimum premium floor using [base_rate, minimum].max after base_rate lookup but before policy_type multiplier in lib/ratenode/calculators/states/ca.rb
- [x] T024 [US3] Update calculate_homeowners method to retrieve and apply minimum_premium_cents in lib/ratenode/calculators/states/ca.rb
- [x] T025 [US3] Update calculate_extended method to retrieve and apply minimum_premium_cents in lib/ratenode/calculators/states/ca.rb
- [x] T026 [US3] Add unit test for TRG minimum premium enforcement at $10K expecting exactly 60_900 cents in spec/calculators/states/ca_spec.rb
- [x] T027 [US3] Add unit test for ORT minimum premium enforcement at $10K expecting exactly 72_500 cents in spec/calculators/states/ca_spec.rb
- [x] T028 [US3] Add unit test verifying minimum is applied before hold-open surcharge (minimum + surcharge, not base + surcharge) in spec/calculators/states/ca_spec.rb
- [x] T029 [US3] Add unit test verifying minimum is applied before policy-type multipliers in spec/calculators/states/ca_spec.rb
- [x] T030 [US3] Run CSV scenario tests to verify minimum premium enforcement does not break existing calculations

**Checkpoint**: All three user stories (US1, US2, US3) should now be independently functional. Minimum premiums are enforced correctly.

---

## Phase 6: User Story 4 - Calculate Refinance Premiums Above $10M with Progressive Rates (Priority: P3)

**Goal**: Enable accurate refinance premium calculations for ultra-high-value properties with incremental rates applied above $10 million.

**Note**: This affects the smallest subset of transactions but is important for accurate pricing on large commercial deals.

**Independent Test**: Calculate refinance premiums for properties above $10M and validate the progressive rate formula against rate manuals.

**Acceptance Scenarios**:
- TRG at $12M: $8,800 (base $7,200 + $800 per million × 2)
- ORT at $15M: $12,610 (base $7,610 + $1,000 per million × 5)
- Boundary at exactly $10M uses tier lookup, not formula

### Implementation for User Story 4

- [x] T031 [US4] Add calculate_ca_over_10m_refinance private method to RefinanceRate that retrieves parameters from state_rules in lib/ratenode/models/refinance_rate.rb
- [x] T032 [US4] Update RefinanceRate.calculate_rate to check if state == "CA" && liability_cents > 1_000_000_000 and call calculate_ca_over_10m_refinance in lib/ratenode/models/refinance_rate.rb
- [x] T033 [US4] Implement calculate_ca_over_10m_refinance formula logic (base + millions_over_10m × rate_per_million) in lib/ratenode/models/refinance_rate.rb
- [x] T034 [US4] Add unit test for TRG refinance at $12M expecting 880_000 cents in spec/calculators/states/ca_spec.rb
- [x] T035 [US4] Add unit test for ORT refinance at $15M expecting 1_261_000 cents in spec/calculators/states/ca_spec.rb
- [x] T036 [US4] Add unit test for refinance boundary condition at exactly $10M using tier lookup (not formula) in spec/calculators/states/ca_spec.rb
- [x] T037 [US4] Add unit test for refinance at $10M + $1 using formula in spec/calculators/states/ca_spec.rb

**Checkpoint**: All user stories (US1-US4) should now be independently functional. Refinance premiums calculate correctly for ultra-high-value properties.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validation and documentation improvements

- [x] T038 [P] Run full test suite to verify all existing tests continue passing (bundle exec rspec)
- [x] T039 [P] Run CSV scenario tests to verify all scenarios pass within $2 tolerance (bundle exec rspec spec/integration/csv_scenarios_spec.rb)
- [x] T040 [P] Verify no regressions in other states by running AZ, FL, NC, TX calculator specs
- [ ] T041 Manual smoke test: Calculate TRG owner premium at $3.5M expecting ~$4,473.50 via CLI
- [ ] T042 Manual smoke test: Calculate ORT concurrent lender at $3.5M expecting ELC in thousands of dollars via CLI
- [ ] T043 Manual smoke test: Calculate TRG minimum at $10K expecting exactly $609 via CLI
- [x] T044 [P] Add code comments referencing rate manual sections for formula parameters in lib/ratenode/state_rules.rb
- [x] T045 Verify quickstart.md implementation guide is accurate by following steps manually
- [x] T046 Update CLAUDE.md with formula parameter pattern learned from this feature

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
  - Configuration parameters are foundational and must be added first
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
  - Formula methods must be updated to accept parameters before any user story can use them
- **User Stories (Phase 3-6)**: All depend on Foundational phase completion
  - User stories CAN proceed in parallel after Foundational phase (if staffed)
  - Or sequentially in priority order (P1 → P1 → P2 → P3)
- **Polish (Phase 7)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - Independent of US1 (different calculation method)
- **User Story 3 (P2)**: Can start after Foundational (Phase 2) - Independent of US1/US2 (applies to all premiums)
- **User Story 4 (P3)**: Can start after Foundational (Phase 2) - Independent of US1/US2/US3 (separate refinance workflow)

### Within Each User Story

- Configuration changes before implementation changes
- Implementation changes before test additions
- Unit tests before integration test validation
- Story complete before moving to next priority

### Parallel Opportunities

- Phase 1: T001 and T002 can run in parallel (different underwriter sections)
- Phase 2: T004-T005 can run in parallel with T006-T007 (different methods)
- User Stories 1 and 2 can be implemented in parallel (different calculation paths)
- User Story 3 can be implemented in parallel with US1/US2 if careful (affects calculate_standard only)
- User Story 4 can be implemented in parallel with US1/US2/US3 (separate file: refinance_rate.rb)
- Phase 7: T038, T039, T040, T044 can all run in parallel

---

## Parallel Example: Phase 1 (Setup)

```bash
# Launch both configuration tasks together:
Task T001: "Add TRG formula parameters to state_rules.rb"
Task T002: "Add ORT formula parameters to state_rules.rb"
```

## Parallel Example: User Stories (After Foundational)

```bash
# If multiple developers available, all stories can start in parallel:
Developer A: User Story 1 (Tasks T008-T014)
Developer B: User Story 2 (Tasks T015-T021)
Developer C: User Story 3 (Tasks T022-T030)
Developer D: User Story 4 (Tasks T031-T037)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T007) - CRITICAL, blocks all stories
3. Complete Phase 3: User Story 1 (T008-T014)
4. **STOP and VALIDATE**: Test User Story 1 independently with $3.5M properties
5. Deploy/demo if ready

**MVP Scope**: User Story 1 delivers the core high-value property calculation fix, which is the primary business requirement.

### Incremental Delivery (Recommended)

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Merge (MVP!)
3. Add User Story 2 → Test independently → Merge (fixes critical ELC revenue leak)
4. Add User Story 3 → Test independently → Merge (compliance with minimum premiums)
5. Add User Story 4 → Test independently → Merge (refinance ultra-high-value support)
6. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (critical path)
2. Once Foundational is done (after T007):
   - Developer A: User Story 1 (owner premiums >$3M)
   - Developer B: User Story 2 (ELC >$3M)
   - Developer C: User Story 3 (minimum premiums)
   - Developer D: User Story 4 (refinance >$10M)
3. Stories complete and merge independently

---

## Validation Checklist

Before submitting PR:

- [x] All formula parameters added to state_rules.rb (both TRG and ORT)
- [x] Hardcoded constants removed from rate_tier.rb
- [x] calculate_over_3m_rate accepts underwriter parameter
- [x] calculate_elc_over_3m renamed to calculate_elc_over_3m_rate + accepts underwriter
- [x] Minimum premium enforcement added to CA calculator
- [x] Refinance over-$10M formula implemented (if US4 included)
- [x] All unit tests pass (bundle exec rspec spec/calculators/states/ca_spec.rb)
- [x] CSV scenario tests pass within $2 tolerance (bundle exec rspec spec/integration/csv_scenarios_spec.rb)
- [x] No regressions in other states (AZ, FL, NC, TX tests pass)
- [ ] Manual smoke tests successful for all implemented user stories

---

## Success Criteria (from spec.md)

- **SC-001**: Premium calculations for properties valued at $3.5M, $5M, and $10M match expected values from TRG and ORT rate manual summaries within $2.00 tolerance
- **SC-002**: ELC premium calculations for concurrent policies at $3.5M and $5M produce values in thousands of dollars (not cents) matching rate manual specifications within $2.00 tolerance
- **SC-003**: Minimum premium enforcement for properties at $10K and $50K liability returns exactly $609 for TRG and $725 for ORT
- **SC-004**: Refinance premium calculations above $10M produce progressive rates matching manual specifications (e.g., $12M refinance = $8,800 TRG, not flat $7,200)
- **SC-005**: All existing CSV scenario tests continue to pass with updated formulas (within $2.00 tolerance)
- **SC-006**: All existing unit tests for CA calculator continue to pass with no regressions

---

## Notes

- **[P] tasks**: Different files, no dependencies - can run in parallel
- **[Story] label**: Maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Boundary conditions: Use `>` not `>=` for $3M and $10M thresholds (tier at boundary, formula above)
- Always `.round` results of float multiplications per Memory.md guidance
- CSV test tolerance: $2.00 allowed for rounding differences

## Task Count Summary

- **Total Tasks**: 46
- **Phase 1 (Setup)**: 2 tasks
- **Phase 2 (Foundational)**: 5 tasks (BLOCKS all user stories)
- **Phase 3 (User Story 1)**: 7 tasks
- **Phase 4 (User Story 2)**: 7 tasks
- **Phase 5 (User Story 3)**: 9 tasks
- **Phase 6 (User Story 4)**: 7 tasks
- **Phase 7 (Polish)**: 9 tasks
- **Parallel Opportunities**: 15 tasks marked [P] can run in parallel with other tasks

## Suggested MVP Scope

**Recommended MVP**: Phase 1 + Phase 2 + Phase 3 (User Story 1 only)
- **Why**: Delivers core high-value property calculation fix (primary business requirement)
- **Task Count**: 14 tasks
- **Estimated Effort**: 1-2 days for experienced Ruby developer
- **Value**: Fixes premiums for properties >$3M, affects highest revenue transactions

**Extended MVP**: Add Phase 4 (User Story 2)
- **Why**: Fixes critical ELC revenue leak (~99% undercharging)
- **Task Count**: 21 tasks total
- **Additional Effort**: +0.5 days
- **Value**: Prevents significant revenue loss on concurrent lender policies
