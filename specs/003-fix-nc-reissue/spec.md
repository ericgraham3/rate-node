# Feature Specification: Fix NC Reissue Discount Calculation

**Feature Branch**: `003-fix-nc-reissue`
**Created**: 2026-02-04
**Status**: Draft
**Input**: User description: "Fix the NC reissue discount calculation identified during validation against the NC rate manual (PR-5)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reissue Discount Correctly Reflects Tiered Rates (Priority: P1)

A rate calculator user requests an NC owner's policy where the current liability exceeds the prior policy amount. The reissue discount must be computed from the actual tiered rate schedule applied to coverage up to the prior policy amount — not from a linear proportion of the full premium. Coverage above the prior policy amount is charged at the full undiscounted rate.

**Why this priority**: This is the core defect. The proportional shortcut produces incorrect premiums for any NC reissue where liability differs from the prior policy amount, because NC rates are incremental and tiered rather than flat.

**Independent Test**: Can be fully tested by calculating the NC owner's premium for a reissue scenario where liability exceeds the prior policy amount and comparing the returned premium against the known manual example (PR-5 Example 2). Delivers the correct premium without requiring changes to any other state or policy type.

**Acceptance Scenarios**:

1. **Given** a reissue request with liability $400,000 and prior policy amount $250,000, **When** the NC owner's premium is calculated, **Then** the reissue discount equals 50% of the tiered rate on $250,000 ($301.75) and the total premium is $627.25.
2. **Given** a reissue request where liability equals the prior policy amount, **When** the NC owner's premium is calculated, **Then** the discount applies to the full tiered rate on that amount (existing behavior is preserved — this is the case where the proportional shortcut happened to be correct).
3. **Given** a reissue request where liability is less than the prior policy amount, **When** the NC owner's premium is calculated, **Then** the discount applies to the tiered rate on the full liability amount (the discountable portion is capped at liability).

---

### User Story 2 - Discount Calculation Consistent Across All Policy Types (Priority: P2)

The reissue discount amount must remain correct regardless of the policy type multiplier in use. If a non-standard policy type applies a multiplier to the base rate, that same multiplier must be reflected in the discount amount so that the net premium math stays consistent.

**Why this priority**: Current test scenarios all use standard policies (multiplier 1.0), so this code path is not exercised by tests. A silent error here would produce incorrect premiums for homeowner's or extended policies at reissue and only surface when a real policy is priced.

**Independent Test**: Can be validated by tracing the discount calculation logic for a non-standard policy type and confirming the multiplier is applied to the discount. Manual verification against a constructed example is sufficient; no new fixture data is required.

**Acceptance Scenarios**:

1. **Given** a reissue request with a non-standard policy type (multiplier not equal to 1.0), **When** the discount is calculated, **Then** the discount amount includes the policy type multiplier applied to the tiered rate on the discountable portion.
2. **Given** a reissue request with a standard policy type (multiplier = 1.0), **When** the discount is calculated, **Then** the discount amount equals the raw tiered rate on the discountable portion times the discount percentage (multiplier has no observable effect).

---

### Edge Cases

- What happens when the prior policy amount is zero or not provided? The reissue discount must not apply; the full undiscounted premium is returned.
- What happens when the prior policy date falls outside the eligibility window? No discount is applied; the full tiered rate is charged.
- What happens when liability equals the prior policy amount exactly? The entire premium is discountable. The tiered rate on the full liability is the discount base. This must produce the same result as the current system for this case.
- What happens when liability is less than the prior policy amount? The discountable portion is capped at liability. The discount base is the tiered rate on the full liability amount.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST calculate the NC reissue discount by applying the discount percentage to the actual tiered rate on the discountable portion of coverage, not by linearly scaling the full premium.
- **FR-002**: The discountable portion of coverage MUST be defined as the lesser of the current policy liability and the prior policy amount.
- **FR-003**: Coverage above the discountable portion MUST be charged at the full undiscounted tiered rate.
- **FR-004**: The discount percentage MUST be sourced from the NC state rules (currently 50%) and remain configurable — it must not be hardcoded.
- **FR-005**: The discount amount MUST include the policy type multiplier so that the net premium calculation (full premium minus discount) remains mathematically consistent for all policy types.
- **FR-006**: Reissue eligibility checks (prior policy date within the eligibility window, prior policy amount present) MUST continue to gate the discount. No change to eligibility logic is in scope.
- **FR-007**: The publicly exposed reissue discount query and the discount used internally during premium calculation MUST return the same value, ensuring consistency between the line-item breakdown and the total premium.

### Key Entities

- **Tiered Rate**: The incremental rate produced by applying the NC rate schedule to a given coverage amount. Each coverage tier has its own per-unit rate; the total is a sum across tiers, not a single linear rate.
- **Discountable Portion**: The coverage amount eligible for the reissue discount — the lesser of current liability and prior policy amount.
- **Policy Type Multiplier**: A factor applied to the base tiered rate to produce the final premium for a given policy type (standard, homeowner's, extended). Equal to 1.0 for standard.
- **Reissue Discount**: The discount amount, defined as the tiered rate on the discountable portion, multiplied by both the discount percentage and the policy type multiplier.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The PR-5 Example 2 validation case (liability $400,000 / prior policy $250,000) produces a total premium of exactly $627.25 and a reissue discount of exactly $301.75.
- **SC-002**: All existing NC reissue test scenarios continue to pass without modification to their expected values. The fix must not regress the liability-equals-prior case.
- **SC-003**: For any NC reissue scenario where liability differs from the prior policy amount, the discount amount matches the value produced by manually applying the tiered rate schedule to the discountable portion and multiplying by the discount percentage and policy type multiplier.
- **SC-004**: The discount returned by the standalone discount query matches the discount subtracted during the full premium calculation — no internal inconsistency between the two code paths.

## Assumptions

- The NC rate tiers and discount percentage (50%) referenced in this fix are the same ones already configured in the system and referenced by PR-5.
- The eligibility window logic (date-based check) is correct and is not in scope for this fix.
- The CSV scenario `NC_purchase_loan_reissue` has a known fixture date issue being corrected separately; this spec does not depend on that scenario passing.
- New partial-reissue test scenarios (liability > prior) that require human-provided expected values are tracked as a follow-up per project constitution Principle V.
- The standalone reissue discount query and the internal discount path within the premium calculation share the same underlying logic — any correction applies to both.
