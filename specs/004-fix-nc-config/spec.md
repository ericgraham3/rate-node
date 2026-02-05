# Feature Specification: Fix NC Rate Configuration and Cross-State Policy Type Symbol

**Feature Branch**: `004-fix-nc-config`
**Created**: 2026-02-05
**Status**: Draft
**Input**: User description: "Fix the following NC rate configuration discrepancies and cross-state symbol inconsistency identified during validation."

## Clarifications

### Session 2026-02-05

- Q: What should happen when a now-removed NC endorsement (e.g., ALTA 17) is requested? → A: Raise an error. The miss must be loud and explicit; a silent $0 or nil is the class of bug this feature is correcting.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - NC Endorsement List Corrected to Rate Manual (Priority: P1)

A rate analyst auditing North Carolina endorsement definitions discovers that the endorsement catalogue contains dozens of entries from other states' rate manuals. Per NC rate manual PR-10, residential policies support exactly three endorsements, each priced as a flat fee. The analyst needs the system to reflect only the endorsements that are valid and priced for NC.

**Why this priority**: Incorrect endorsements produce wrong charges on NC policies and create confusion for agents selecting endorsements. This is the highest-impact data correctness issue in the batch.

**Independent Test**: Can be verified by querying the NC endorsement catalogue and confirming exactly three entries exist (ALTA 5, ALTA 8.1, ALTA 9), each with a flat charge of $23.00. Delivers immediate data integrity for NC policies.

**Acceptance Scenarios**:

1. **Given** the NC endorsement catalogue is loaded, **When** the available endorsements are listed, **Then** exactly three endorsements appear: ALTA 5 (Planned Unit Development), ALTA 8.1 (Environmental Protection), and ALTA 9 (Restrictions, Encroachments, Minerals)
2. **Given** an NC residential policy requests any of the three valid endorsements, **When** the endorsement charge is calculated, **Then** each endorsement costs exactly $23.00 (flat, regardless of liability amount)
3. **Given** an NC policy previously could select endorsements such as ALTA 17, CLTA 100, or ALTA 28, **When** the updated catalogue is in effect, **Then** those endorsements are no longer available for NC policies

---

### User Story 2 - Policy Type Symbol Unified Across All States (Priority: P2)

A developer running cross-state calculations notices that Arizona uses the policy type identifier `homeowners` while North Carolina, California, Florida, and Texas all use `homeowner` (without the trailing "s"). CSV test fixtures for Arizona already reference `homeowners`. The inconsistency risks lookup failures when the rate engine resolves policy type multipliers. All states need to agree on a single identifier.

**Why this priority**: A symbol mismatch causes silent failures — the system may return a 1.0 default multiplier instead of the correct state-specific value. This affects rate accuracy across all states that use non-standard policy types.

**Independent Test**: Can be verified by requesting a homeowners-type policy multiplier for each of NC, CA, FL, TX, and AZ and confirming the correct state-specific multiplier is returned (not a 1.0 fallback). All existing CSV scenario tests must continue to pass unchanged.

**Acceptance Scenarios**:

1. **Given** a policy is rated as type `homeowners` in any state (NC, CA, FL, TX, AZ), **When** the policy type multiplier is looked up, **Then** the correct state-specific multiplier is returned (NC: 1.20, CA: 1.10, FL: 1.10, TX: 1.10, AZ: 1.10)
2. **Given** the AZ CSV test fixtures already use the string `homeowners`, **When** all scenario tests are executed, **Then** all tests pass without modification to the CSV fixture files
3. **Given** the identifier was previously `homeowner` in NC, CA, FL, and TX, **When** the system is updated to `homeowners`, **Then** no other state's rate calculations are affected

---

### User Story 3 - NC Minimum Premium and Rounding Enforced (Priority: P3)

A compliance reviewer comparing NC policy outputs against the NC rate manual (PR-1) finds that policies with very low liability amounts produce premiums below the state-mandated $56.00 minimum. The same reviewer notes that liability amounts are being rounded to $10,000 increments instead of the manual-specified $1,000 increments. Both corrections are needed to match the promulgated rate schedule.

**Why this priority**: These are configuration corrections with clear manual references. They do not affect any current test scenarios (all existing NC scenarios have liability amounts well above the minimum and rounding thresholds), so they carry no regression risk. New scenario test cases with human-provided expected values are required before these changes can be fully validated, per constitution Principle V.

**Independent Test**: Minimum premium can be verified by calculating an NC policy with a liability amount low enough that the tiered rate produces a premium below $56.00 and confirming the output is clamped to $56.00. Rounding can be verified by submitting a liability amount that is not a multiple of $1,000 and confirming it rounds up to the next $1,000.

**Acceptance Scenarios**:

1. **Given** an NC policy with a liability amount whose tiered premium would be less than $56.00, **When** the premium is calculated, **Then** the policy premium is $56.00
2. **Given** an NC policy with a liability amount of, for example, $105,500, **When** the liability is rounded for rate lookup, **Then** it rounds up to $106,000 (the next $1,000 increment), not $110,000
3. **Given** existing NC scenario tests (purchase/loan/reissue at $500,000 liability), **When** all tests are run after the rounding and minimum changes, **Then** all results are unchanged (these scenarios are unaffected by the corrected thresholds)

---

### Edge Cases

- What happens when an NC policy liability amount is exactly a multiple of $1,000? The rounding increment should leave it unchanged (round-up of an exact multiple is a no-op).
- What happens when an NC policy premium equals exactly $56.00 before the minimum check? It should pass through unchanged — the minimum is inclusive.
- What happens if a caller requests a policy type of `homeowner` (old identifier) after the rename? The system should not silently return a 1.0 fallback; this should be treated as an unrecognized type. New scenarios validating this behavior require human-provided expected values per Principle V.
- What happens to endorsement charges on an NC policy that requests a now-removed endorsement (e.g., ALTA 17)? The endorsement is no longer in the catalogue; the system MUST raise an error. A silent $0 or nil return is explicitly prohibited — the caller must be forced to handle the miss.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The NC endorsement catalogue MUST contain exactly three endorsements: ALTA 5 (Planned Unit Development), ALTA 8.1 (Environmental Protection), and ALTA 9 (Restrictions, Encroachments, Minerals). All other previously defined NC endorsements MUST be removed.
- **FR-002**: Each of the three NC endorsements MUST be priced as a flat fee of $23.00, independent of policy liability amount or policy type.
- **FR-003**: The policy type identifier used across all states (NC, CA, FL, TX, AZ) MUST be standardized to `homeowners`. The previous identifier `homeowner` MUST no longer appear in any state's policy type configuration or constants.
- **FR-004**: The NC minimum premium MUST be set to $56.00. Any NC policy whose calculated premium falls below this threshold MUST have its premium raised to exactly $56.00.
- **FR-005**: The NC liability rounding increment MUST be $1,000 (round up). Liability amounts that are not exact multiples of $1,000 MUST be rounded up to the next $1,000 before rate tier lookup.
- **FR-006**: All existing CSV scenario tests MUST pass after all changes are applied. The CSV fixture file MUST NOT be modified.
- **FR-007**: New test scenarios exercising the minimum premium (FR-004) and rounding increment (FR-005) corrections MUST NOT be authored by an agent. Expected values for these scenarios MUST be provided by a human referencing the NC rate manual, per constitution Principle V.

### Key Entities

- **Endorsement**: A coverage add-on available for a state's policies. Defined by code, name, pricing type (flat/percentage/no_charge), and base amount. NC endorsements are scoped to residential policies only.
- **Policy Type**: A classification that applies a multiplier to the base premium (e.g., standard, homeowners, extended). Identified by a symbol that must be consistent across all states.
- **State Rules**: The centralized configuration record for a state, containing rounding increments, minimum premiums, policy type multipliers, and other rate parameters.

## Assumptions

- The NC rate manual sections referenced (PR-1 for minimum premium, PR-10 for endorsements) are the authoritative source. This spec assumes those sections have been correctly read and interpreted by the user who filed the issues.
- The `homeowners` identifier (with trailing "s") is chosen as the standard because it already matches the AZ CSV test fixtures, which are human-controlled and must not be modified.
- Issues 1 (minimum premium) and 2 (rounding increment) do not affect any currently-passing NC scenario tests. The existing NC scenarios all use $500,000 liability with `standard` policy type, which is well above both the $56.00 minimum and the $1,000 rounding boundary.
- The `DEFAULT_STATE_RULES` fallback in state_rules.rb also uses `:homeowner`; this is out of scope for this feature unless it causes a test failure. It is noted for future cleanup.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of existing CSV scenario tests pass after all changes, with zero modifications to the CSV fixture file.
- **SC-002**: The NC endorsement catalogue contains exactly 3 endorsements, each priced at exactly $23.00 flat.
- **SC-003**: The policy type identifier `homeowners` resolves to the correct multiplier for all 5 states (NC, CA, FL, TX, AZ) without any state falling back to a default of 1.0.
- **SC-004**: NC policies with liability amounts below the rounding and minimum thresholds produce outputs consistent with the NC rate manual (validated by human-provided expected values before merge).
