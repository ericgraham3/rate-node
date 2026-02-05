# Feature Specification: Fix NC Simultaneous Issue Base Premium Liability

**Feature Branch**: `005-fix-nc-simul-premium`
**Created**: 2026-02-05
**Status**: Draft
**Input**: User description: "Implement the NC simultaneous issue base premium rule (PR-4) identified during validation against the NC rate manual."

## Clarifications

### Session 2026-02-05

- Q: Does this feature need to add multi-loan input support, or should the PR-4 max rule apply only to the single loan_amount_cents that already exists (treating it as the total)? → A: Single loan only. The PR-4 rule applies to the existing single loan_amount_cents. No multi-loan input support is added. The max comparison is max(owner_coverage, loan_amount_cents).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - NC Simultaneous Issue Base Premium Computed on Correct Liability (Priority: P1)

A compliance reviewer validating North Carolina simultaneous issue transactions against the NC rate manual (PR-4) discovers that when the Loan Policy coverage amount exceeds the Owner's Policy coverage, the base premium is under-calculated. PR-4 mandates that the single base premium for a simultaneous issue transaction be computed on the **higher of** the Owner's Policy coverage or the Loan Policy coverage. The reviewer needs the system to apply this rule so that NC simultaneous issue premiums match the promulgated schedule.

**Why this priority**: This is the core correctness issue. Any NC simultaneous issue transaction where loan coverage exceeds owner coverage produces an incorrect (too-low) base premium. This is a promulgated rate rule that must be followed exactly.

**Independent Test**: Can be verified by submitting an NC simultaneous issue transaction where the single loan amount exceeds the owner's coverage and confirming the base premium is computed on the loan amount, not the owner's coverage. The constructed validation example (Owner's $300,000 / Loan $350,000) yields a base premium of $820.50 per PR-2 tiers, plus a $28.50 simultaneous issue charge, for a total of $849.00.

**Acceptance Scenarios**:

1. **Given** an NC simultaneous issue with Owner's coverage of $300,000 and a single Loan of $350,000, **When** the Owner's Policy premium is calculated, **Then** the base premium is $820.50 (computed on $350,000 per PR-2 tiers: $100k × $2.78 + $250k × $2.17), and the Loan Policy charge is $28.50, for a combined total of $849.00
2. **Given** the same transaction as above, **When** the Owner's Policy output is examined, **Then** the `liability_cents` field reflects the actual Owner's coverage ($300,000), not the adjusted premium-calculation input ($350,000)
3. **Given** an NC simultaneous issue where the Owner's coverage equals or exceeds the Loan coverage, **When** the Owner's Policy premium is calculated, **Then** the base premium is computed on the Owner's coverage amount (behaviour unchanged from current)

---

### User Story 2 - Loan Amount Passed Through to NC State Calculator (Priority: P2)

The NC state calculator currently has no visibility into the total loan amount — it only receives the owner's liability. To apply the PR-4 rule, the calculator needs the total loan coverage as an additional input so it can determine which value drives the base premium.

**Why this priority**: This is the prerequisite data-flow change that enables the P1 rule. Without the loan amount reaching the NC calculator, the max comparison cannot be performed. No other state calculator is affected.

**Independent Test**: Can be verified by confirming that the NC state calculator receives the total loan amount as a parameter on simultaneous issue transactions, and that no other state's calculator interface or behaviour is changed.

**Acceptance Scenarios**:

1. **Given** a purchase transaction with a lender's policy in NC, **When** the owner's premium is calculated, **Then** the total loan amount is available to the NC state calculator as an input
2. **Given** a purchase transaction in any state other than NC, **When** the owner's premium is calculated, **Then** the state calculator receives exactly the same inputs as before this change (no new parameters)

---

### Out of Scope

- **Multiple loan policies per transaction**: The system currently accepts a single `loan_amount_cents` per transaction. Adding array-of-loans input support is out of scope for this feature. The PR-4 max rule operates on the single existing loan amount. If multi-loan support is needed in the future, it will be a separate feature.

---

### Edge Cases

- What happens when owner's coverage exactly equals the loan coverage? The max of two equal values is that value; behaviour is unchanged and no special handling is needed.
- What happens when there are no Loan Policies (owner-only transaction)? The PR-4 rule does not apply; the base premium is computed on the owner's coverage as normal.
- What happens when a simultaneous issue transaction is in a state other than NC? The rule is NC-specific; no other state's premium calculation is affected.
- What happens when the loan amount is zero but a lender's policy flag is set? This is a malformed input; the system should behave as if no lender's policy is present (existing guard).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: For NC simultaneous issue transactions, the base premium MUST be calculated on the greater of the Owner's Policy coverage amount or the single Loan Policy coverage amount
- **FR-002**: The `liability_cents` field in the Owner's Policy output MUST continue to reflect the actual Owner's Policy coverage amount, regardless of which value was used for the base premium calculation
- **FR-003**: The total loan coverage amount MUST be passed as an input to the NC state calculator when a lender's policy is included in a purchase transaction
- **FR-004**: No state calculator other than NC MUST receive any new parameters or exhibit any change in behaviour as a result of this feature
- **FR-005**: The $28.50 simultaneous issue charge per Loan Policy MUST continue to be applied as before; only the base premium input is affected by this change
- **FR-006**: The base premium MUST be computed using the PR-2 tiered rate structure, which is the established source of truth for NC rate tiers; expected values for new test scenarios MUST be derived from PR-2 tiers, not from PR-4 illustrative examples

### Key Entities

- **Owner's Policy Coverage**: The liability amount insured under the Owner's title insurance policy; used as the reported liability in output and as one of the two values compared under PR-4
- **Loan Policy Coverage**: The liability amount insured under the Loan Policy; compared against the Owner's Policy coverage to determine which value drives the base premium under PR-4
- **Base Premium**: The single premium computed on the PR-2 tiered rate schedule; its input liability is determined by the PR-4 max rule for NC simultaneous issue transactions
- **Simultaneous Issue Charge**: The flat $28.50 fee applied per Loan Policy when issued concurrently with an Owner's Policy in NC

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of NC simultaneous issue transactions where loan coverage exceeds owner's coverage produce a base premium calculated on the loan coverage, verifiable against PR-2 tier calculations
- **SC-002**: 100% of NC simultaneous issue transactions where owner's coverage equals or exceeds loan coverage produce results identical to current behaviour (zero regression)
- **SC-003**: The Owner's Policy `liability_cents` output field matches the owner's actual coverage amount in all NC simultaneous issue transactions, regardless of which value drove the base premium
- **SC-004**: All existing NC scenario tests (purchase, reissue, endorsement) continue to pass without modification
- **SC-005**: No change in calculated premiums for any state other than NC

## Assumptions

- The PR-2 tiered rate structure already in the system is correct and validated by existing passing tests; it is the source of truth for NC base premium calculations.
- PR-4 illustrative examples in the NC rate summary contain known errors in their intermediate base premium values; expected values for this feature are constructed independently from PR-2 tiers.
- New test scenarios exercising the loan-exceeds-owner path require human-provided expected values before they can be added to the CSV scenario suite, per constitution Principle V.
- "Simultaneous issue" is equivalent to "concurrent" in the system's existing terminology — a purchase transaction that includes both an Owner's Policy and a Loan Policy.
- The system accepts a single `loan_amount_cents` per transaction. Multi-loan input support is not in scope; the PR-4 max rule operates on this single value.
- The existing $28.50 concurrent base fee in the NC state rules is correct and is not affected by this change.
