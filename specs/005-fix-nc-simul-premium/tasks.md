# Tasks: Fix NC Simultaneous Issue Base Premium Liability

**Input**: Design documents from `/specs/005-fix-nc-simul-premium/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/nc_owners_premium.md, quickstart.md

**Tests**: No test tasks generated. The spec does not request TDD. New CSV scenario rows require human input per Constitution Principle V (see Phase 4, T006).

**Organization**: Two user stories. US2 (P2) is the data-flow prerequisite; it is placed in the Foundational phase because US1 cannot function without it. US1 (P1) is the value-delivering rule change.

## Phase 1: Setup (Baseline Verification)

**Purpose**: Confirm the existing test suite passes before any code changes. This is the safety net referenced by Constitution Principle V — if scenarios fail now, the database may need re-seeding before proceeding.

- [X] T001 Run full scenario test suite via `bundle exec rspec` from repo root and confirm all 38 existing scenarios pass (green baseline)

---

## Phase 2: Foundational (Blocking Prerequisite)

**Purpose**: Pass `loan_amount_cents` from the orchestrator into the state calculator params hash. This is the data-flow change that enables the PR-4 rule. No state calculator other than NC will read the new key.

**⚠️ CRITICAL**: Phase 3 (US1) cannot function until this task is complete.

- [X] T002 [US2] In `lib/ratenode/calculator.rb`, method `calculate_owners_policy` (line 82–105): add `loan_amount_cents: include_lenders_policy ? loan_amount_cents : nil` to the `params` hash that is passed to `calculator.calculate_owners_premium`. Per research.md §4, pass it unconditionally in the hash (no state conditional) — other state calculators ignore unknown keys, satisfying FR-004.

**Checkpoint**: The orchestrator now forwards loan coverage to all state calculators. No behaviour changes yet — no calculator reads the new key.

---

## Phase 3: User Story 1 — NC Simultaneous Issue Base Premium Computed on Correct Liability (Priority: P1) 🎯 MVP

**Goal**: Apply the PR-4 max rule inside the NC state calculator so that the base premium is computed on `max(owner_liability, loan_amount)` for simultaneous issue transactions.

**Independent Test**: Submit an NC simultaneous issue with Owner $300,000 / Loan $350,000. Expected: owner premium $820.50, lender charge $28.50, total $849.00. Verify via CLI: `bundle exec ruby bin/ratenode quote --state NC --underwriter TRG --transaction-type purchase --purchase-price 300000 --loan-amount 350000 --owners-policy-type standard --include-lenders-policy`

### Implementation

- [X] T003 [US1] In `lib/ratenode/calculators/states/nc.rb`, method `calculate_owners_premium` (line 25–34): read `@loan_amount_cents = params[:loan_amount_cents]` alongside the existing instance variable assignments. This is the only new instance variable.

- [X] T004 [US1] In `lib/ratenode/calculators/states/nc.rb`, private method `calculate_standard` (line 105–121): introduce a local variable `premium_input` that holds the PR-4-adjusted liability. Logic: if `@loan_amount_cents` is present and greater than zero, set `premium_input = [@liability_cents, @loan_amount_cents].max`; otherwise set `premium_input = @liability_cents`. Then change the `Calculators::BaseRate.new(...)` call on line 106 to use `premium_input` as its first argument instead of `@liability_cents`. All other references to `@liability_cents` in this file (reissue discount, output) remain unchanged — per FR-002 and research.md §3, the reissue discount must continue to operate on the owner's actual coverage.

**Checkpoint**: The PR-4 rule is now active. NC simultaneous issue transactions where loan > owner will produce the correct base premium. All other paths (owner ≥ loan, no loan, reissue) are unchanged.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Regression validation and the required human action for CSV scenario coverage.

- [X] T005 Run the full scenario test suite via `bundle exec rspec` from repo root. All 38 existing scenarios must pass without modification. This confirms FR-004 (no other state affected) and SC-002/SC-004 (NC regression-free).

- [X] T006 ⚠️ HUMAN ACTION — Add the new CSV scenario row to `spec/fixtures/scenarios_input.csv` in the NC block. The exact row (verified against PR-2 tiers in research.md §2):
  ```
  NC_purchase_loan_exceeds_owner,NC,TRG,purchase,300000,350000,,,standard,standard,,,FALSE,,820.5,28.5,,,,849
  ```
  Then run `bundle exec rspec` again to confirm the new scenario passes. Per Constitution Principle V, this row must not be added by the agent.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 green baseline — BLOCKS Phase 3
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion (T002 must be done before T003/T004)
- **Polish (Phase 4)**: Depends on Phase 3 completion

### Within User Story 1

- T003 before T004 — `@loan_amount_cents` must be assigned before `calculate_standard` can reference it
- T005 (regression run) after T004 — validates the change end-to-end
- T006 (CSV row) after T005 — only add the new scenario after existing scenarios confirm green

### Parallel Opportunities

This feature has no parallelisable tasks. The two code changes (T002, T003/T004) are in different files but are logically sequential: the NC calculator cannot apply the max rule until the orchestrator passes the loan amount. The feature is small enough (4 lines of code across 2 files) that sequential execution is the correct approach.

---

## Implementation Strategy

### MVP (complete feature — this is the full scope)

1. T001 — confirm green baseline
2. T002 — wire loan amount through orchestrator
3. T003 + T004 — apply PR-4 max rule in NC calculator
4. T005 — regression validation
5. T006 — human adds CSV scenario, final validation

### Rollback

If T005 fails (regression detected), revert T003/T004 first. If still failing, revert T002. The changes are isolated to two files; a `git checkout` on either file restores the pre-feature state exactly.

---

## Notes

- This feature touches exactly 2 source files: `lib/ratenode/calculator.rb` and `lib/ratenode/calculators/states/nc.rb`
- No new files, no new models, no schema changes, no new columns in the CSV
- T006 is a human-only task per Constitution Principle V — the agent must stop and hand off
- All monetary values are in cents (integers); the expected $820.50 owner premium is 82,050 cents internally
