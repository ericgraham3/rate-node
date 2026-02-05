# Tasks: Fix NC Reissue Discount Calculation

**Input**: Design documents from `/specs/003-fix-nc-reissue/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Not explicitly requested — no test tasks generated. CSV scenario coverage is a human task per Constitution Principle V.

**Organization**: Tasks grouped by user story. US1 is the core calculation fix; US2 is the multiplier consistency concern addressed within the same method.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

---

## Phase 1: Setup

**Purpose**: No project initialization required — this is a targeted bug fix in an existing codebase. All tooling, dependencies, and database schema are already in place.

**Checkpoint**: Nothing to do. Proceed to Phase 2.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Remove the stale TODO marker that documents the now-in-scope bug. This must happen before the fix so the code does not carry contradictory signals.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T001 Remove the FR-013 TODO block (lines 12-28) in `lib/ratenode/calculators/states/nc.rb` — this bug is being fixed in this PR, not deferred

**Checkpoint**: Stale TODO removed. US1 implementation can begin.

---

## Phase 3: User Story 1 — Reissue Discount Correctly Reflects Tiered Rates (Priority: P1) 🎯 MVP

**Goal**: Replace the proportional approximation in `calculate_reissue_discount()` with a call to `RateTier.calculate_rate()` on the discountable portion, so the discount is computed from the actual tiered rate schedule.

**Independent Test**: Calculate NC owner's premium for liability $400,000 / prior policy $250,000 (standard policy). Expected: premium $627.25, discount $301.75. Verify both `calculate_owners_premium` and `reissue_discount_amount` return matching values.

### Implementation for User Story 1

- [x] T002 [US1] Rewrite `calculate_reissue_discount` in `lib/ratenode/calculators/states/nc.rb`: (a) remove the `full_premium` parameter — it is no longer used after this change; (b) replace the `if/else` proportional approximation block with a direct call to `Models::RateTier.calculate_rate(discountable_portion_cents, state: "NC", underwriter: @underwriter, as_of_date: @as_of_date)` to get the true tiered rate; (c) update both call sites that pass `full_premium` — `calculate_standard` (line 146) and `reissue_discount_amount` (line 125) — to call `calculate_reissue_discount` with no arguments
- [x] T003 [US1] Update the discount formula in `calculate_reissue_discount()` in `lib/ratenode/calculators/states/nc.rb`: apply the policy type multiplier to the tiered rate before multiplying by discount percentage, so the full expression is `(tiered_rate * multiplier * discount_percent).round`
- [x] T004 [US1] Run `bundle exec rspec` from the repo root and verify all existing NC scenarios pass — the liability-equals-prior case must produce the same result as before (the tiered rate on full liability equals full_premium / multiplier, so the math is equivalent for that case)

**Checkpoint**: User Story 1 is complete. The core reissue discount bug is fixed. Proceed to US2.

---

## Phase 4: User Story 2 — Discount Calculation Consistent Across All Policy Types (Priority: P2)

**Goal**: Confirm that the policy type multiplier is correctly woven into the discount amount so that non-standard policy types (homeowner 1.2×, extended 1.2×) produce a mathematically consistent net premium.

**Independent Test**: Trace the discount calculation for a homeowner policy type (multiplier 1.2) and verify the discount amount includes the 1.2× factor. No new fixture data needed — this is a code-path verification.

### Implementation for User Story 2

- [x] T005 [US2] Verify in `lib/ratenode/calculators/states/nc.rb` that the multiplier lookup in `calculate_reissue_discount()` uses the same call signature as `calculate_standard()` (i.e., `Models::PolicyType.multiplier_for(@policy_type, state: "NC", underwriter: @underwriter, as_of_date: @as_of_date)`) — if T003 already introduced this, confirm it is correct; otherwise add it
- [x] T006 [US2] Confirm that `reissue_discount_amount()` (the public standalone method in `lib/ratenode/calculators/states/nc.rb`) reaches the same `calculate_reissue_discount()` method as the internal path in `calculate_standard()` — both code paths must return the same discount value (FR-007). If there is any divergence, unify them

**Checkpoint**: US2 is complete. Both code paths produce the same multiplier-aware discount.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and human handoff.

- [x] T007 Run `bundle exec rspec` one final time to confirm all scenarios pass with no regressions across any state
- [x] T008 Run `quickstart.md` manual verification: call `calculate_owners_premium` and `reissue_discount_amount` with the spec example inputs (liability $400,000 / prior $250,000 / standard / TRG) and confirm premium = 62725 cents and discount = 30175 cents
- [ ] T009 **HUMAN TASK**: Add CSV test scenarios to `spec/fixtures/scenarios_input.csv` for partial-reissue cases (liability > prior) with verified expected values from NC rate manual (per Constitution Principle V — agent must not create expected values)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundational (Phase 2)**: No dependencies — start immediately
- **User Story 1 (Phase 3)**: Depends on Phase 2 (T001) completion
- **User Story 2 (Phase 4)**: Depends on Phase 3 (T002, T003) completion — US2's multiplier concern is in the same method US1 rewrites
- **Polish (Phase 5)**: Depends on both US1 and US2 completion

### Task-Level Dependencies

```
T001 (remove TODO)
  └── T002 (rewrite discount base — tiered rate lookup)
        └── T003 (apply multiplier to discount)
              ├── T004 (run rspec — US1 checkpoint)
              └── T005 (verify multiplier call signature)
                    └── T006 (verify standalone vs internal path parity)
                          ├── T007 (final rspec run)
                          └── T008 (manual verification)

T009 (human flag) — no code dependency, can be noted at any time
```

### Parallel Opportunities

This feature has a single target file (`nc.rb`) and a linear method rewrite, so there are no meaningful parallel opportunities within the implementation tasks. T004 and T005 could theoretically run in parallel (read-only verification on different concerns) but both depend on T003 completing first.

---

## Parallel Example: User Story 1

```text
# T002 and T003 are sequential (T003 builds on T002's output in the same method)
# T004 can run after T003 completes:
Task: T004 — run rspec to validate US1

# After T003, T005 is also unblocked:
Task: T005 — verify multiplier call signature (read-only check)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 2: Remove stale TODO (T001)
2. Complete Phase 3: Rewrite `calculate_reissue_discount()` (T002, T003, T004)
3. **STOP and VALIDATE**: Confirm the spec example produces $627.25 / $301.75
4. This is a shippable fix for the core bug

### Full Delivery

1. Complete MVP (above)
2. Complete Phase 4: Verify multiplier consistency (T005, T006)
3. Complete Phase 5: Polish and human handoff (T007, T008, T009)

---

## Notes

- [P] tasks = different files, no dependencies (none in this feature — single-file fix)
- [Story] label maps task to specific user story for traceability
- T009 is a human task per Constitution Principle V — agents must not create CSV test values
- The fix is confined to one private method; `calculate_standard()` and `reissue_discount_amount()` both call it, so both code paths are corrected by a single change
- Total tasks: 9 | US1 tasks: 3 | US2 tasks: 2 | Foundational: 1 | Polish: 3
