# Feature Specification: Fix FL Rate Calculator Discrepancies

**Feature Branch**: `002-fix-fl-rates`
**Created**: 2026-02-04
**Status**: Draft
**Input**: Corrections to Florida endorsement pricing and reissue eligibility identified during validation against the FL rate manual.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - ALTA 6 Endorsements Charged Correctly (Priority: P1)

A rate calculator user runs a Florida lender policy that includes an ALTA 6 or ALTA 6.2 endorsement. Currently the system returns $0.00 for these endorsements. Per the FL rate manual, each should carry a flat $25.00 fee. The user expects the output to include that charge.

**Why this priority**: ALTA 6 is among the most commonly requested lender endorsements. Undercharging on every policy that includes it produces a systematic revenue shortfall and a compliance discrepancy with filed rates.

**Independent Test**: Can be fully tested by requesting a single lender policy with an ALTA 6 endorsement and verifying the endorsement line item equals $25.00, without any other changes to the calculator.

**Acceptance Scenarios**:

1. **Given** a Florida lender policy request includes ALTA 6, **When** the rate is calculated, **Then** the ALTA 6 endorsement charge is exactly $25.00.
2. **Given** a Florida lender policy request includes ALTA 6.2, **When** the rate is calculated, **Then** the ALTA 6.2 endorsement charge is exactly $25.00.
3. **Given** a Florida lender policy request includes both ALTA 6 and ALTA 6.2, **When** the rate is calculated, **Then** each endorsement is charged $25.00 independently (total $50.00 for both).

---

### User Story 2 - ALTA 9-Series Endorsements Priced at 10% (Priority: P1)

A rate calculator user runs a Florida policy that includes an ALTA 9.1, 9.2, or 9.3 endorsement. Currently ALTA 9.3 returns $0.00 and ALTA 9.1/9.2 are not recognized at all. Per the FL rate manual, all three should be priced identically to ALTA 9: 10% of the combined underlying policy premium with a $25.00 minimum.

**Why this priority**: Missing or zeroed endorsements on 9-series forms produce both undercharging and silent omissions in rate output, making validation against the rate manual impossible for these endorsements.

**Independent Test**: Can be fully tested by requesting a policy with a single ALTA 9.3 endorsement and verifying the charge equals 10% of the combined policy premium (or $25.00 if that amount is lower), independent of other changes.

**Acceptance Scenarios**:

1. **Given** a Florida policy with ALTA 9.3 and a combined premium above $250.00, **When** the rate is calculated, **Then** ALTA 9.3 is charged at 10% of the combined premium.
2. **Given** a Florida policy with ALTA 9.3 and a combined premium at or below $250.00, **When** the rate is calculated, **Then** ALTA 9.3 is charged the $25.00 minimum.
3. **Given** a Florida policy request includes ALTA 9.1, **When** the rate is calculated, **Then** ALTA 9.1 is recognized and charged at 10% of the combined premium (minimum $25.00).
4. **Given** a Florida policy request includes ALTA 9.2, **When** the rate is calculated, **Then** ALTA 9.2 is recognized and charged at 10% of the combined premium (minimum $25.00).

---

### User Story 3 - Reissue Eligibility Boundary Is Exclusive (Priority: P2)

A rate calculator user submits a Florida reissue request where the prior policy is exactly three years old (to the day). Currently the system grants reissue rates in this case. Per the FL rate manual the window is "less than three years," meaning a prior policy that is exactly three years old should no longer qualify.

**Why this priority**: This is a boundary-condition correction. It affects a narrow set of policies (those falling on the exact eligibility boundary) but produces an incorrect rate discount when it does fire, and is a direct contradiction of the filed rate manual.

**Independent Test**: Can be fully tested by submitting a reissue request with a prior policy date exactly equal to the eligibility cutoff and confirming standard (non-reissue) rates are returned.

**Acceptance Scenarios**:

1. **Given** a Florida reissue request where the prior policy is exactly 3 years old, **When** the rate is calculated, **Then** standard (non-reissue) rates are applied.
2. **Given** a Florida reissue request where the prior policy is 2 years and 364 days old, **When** the rate is calculated, **Then** reissue rates are applied.
3. **Given** a Florida reissue request where the prior policy is more than 3 years old, **When** the rate is calculated, **Then** standard (non-reissue) rates are applied.

---

### Edge Cases

- What happens when ALTA 9.1 or 9.2 is requested on a policy where the combined premium is exactly $250.00 (the point at which 10% equals the $25.00 minimum)?
- What happens when a reissue request has no prior policy date supplied — does the boundary change affect the fallback path?
- What happens when both ALTA 9 and ALTA 9.3 are requested on the same policy — are they charged independently?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The rate definition for ALTA 6 MUST specify a flat charge of $25.00 (not no-charge).
- **FR-002**: The rate definition for ALTA 6.2 MUST specify a flat charge of $25.00 (not no-charge).
- **FR-003**: The rate definition for ALTA 9.3 MUST specify a percentage-of-combined-premium charge at 10% with a $25.00 minimum (not no-charge).
- **FR-004**: Rate definitions for ALTA 9.1 and ALTA 9.2 MUST be added, each with percentage-of-combined-premium pricing at 10% and a $25.00 minimum, matching the existing ALTA 9 structure.
- **FR-005**: The reissue eligibility check MUST use a strict less-than comparison against the eligibility-year threshold, excluding policies that are exactly at the boundary.
- **FR-006**: All existing scenario tests that currently pass MUST continue to pass after these changes.
- **FR-007**: New edge-case test scenarios for the boundary condition and the corrected endorsements MUST use expected values provided by a human reviewer (per project Principle V — no AI-generated expected rate values).

### Key Entities

- **Endorsement Definition**: A rate-table entry describing an endorsement's code, name, pricing type, and pricing parameters. Affected entries: ALTA 6, ALTA 6.2, ALTA 9.1 (new), ALTA 9.2 (new), ALTA 9.3.
- **Reissue Eligibility Window**: The maximum age of a prior policy (in years) that still qualifies for reissue discount pricing. The boundary condition changes from inclusive to exclusive.
- **Combined Policy Premium**: The sum of owner and lender policy premiums, used as the base for percentage-style endorsement charges on the 9-series endorsements.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every Florida policy containing an ALTA 6 or ALTA 6.2 endorsement produces a $25.00 charge per endorsement in rate output — zero instances of $0.00 for these endorsements.
- **SC-002**: Every Florida policy containing an ALTA 9.1, 9.2, or 9.3 endorsement produces a charge equal to 10% of the combined premium (or $25.00 minimum) — zero instances of $0.00 or "endorsement not found" for these endorsements.
- **SC-003**: A reissue request with a prior policy exactly at the eligibility boundary returns standard rates, not reissue rates. Policies one day inside the boundary continue to return reissue rates.
- **SC-004**: All pre-existing CSV scenario tests pass without modification after the changes are applied.

## Assumptions

- The $25.00 minimum for ALTA 9-series endorsements is expressed in cents internally as 2500, consistent with the existing ALTA 9 definition and the flat-fee convention used by ALTA 6/6.2.
- ALTA 9.1 and ALTA 9.2 share the same pricing structure as ALTA 9 and ALTA 9.3: `percentage_combined` at 10%, minimum $25.00. No other attributes (e.g., `lender_only`) are specified in the rate manual for these endorsements, so they are assumed to be owner-and-lender endorsements unless the rate manual review indicates otherwise.
- The eligibility year threshold value (currently 3) is unchanged; only the comparison operator changes from inclusive (<=) to exclusive (<).
- New edge-case test scenarios will be authored with placeholder expected values and flagged for human review before the feature is merged, per project Principle V.
