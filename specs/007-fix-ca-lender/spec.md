# Feature Specification: Fix CA Lender Policy Calculation Bugs

**Feature Branch**: `007-fix-ca-lender`
**Created**: 2026-02-05
**Status**: Draft
**Input**: User description: "Fix CA lender policy calculation bugs identified during validation against TRG and ORT rate manuals."

## Clarifications

### Session 2026-02-05

- Q: When `is_binder_acquisition: true` but `include_lenders_policy: true` is also set, which flag takes precedence? → A: `is_binder_acquisition: true` always takes precedence (never include lender policy for cash purchases, regardless of `include_lenders_policy` value)
- Q: When calculating concurrent Standard lender excess as $150 + percentage × (rate_loan - rate_owner), what should happen if the percentage calculation yields a value less than $150? → A: Use max($150, $150 + percentage × rate_difference) - the total premium cannot be less than $150
- Q: How should the system handle standalone lender policy calculations when the loan amount is $0? → A: Return $0 premium (no loan means no lender policy premium)
- Q: When calculating lender policies, if a base rate lookup fails (e.g., database unavailable, rate not found for liability amount), how should the system respond? → A: Raise error and reject the quote request (fail fast to prevent incorrect quotes)
- Q: How should the system handle negative loan amounts (e.g., -$500,000) when calculating lender policy premiums? → A: Reject as invalid input (loan amounts must be ≥ $0)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Accurate Standalone Lender Policy Rates (Priority: P1)

When a user requests a standalone lender policy quote (non-concurrent with owner's policy), they receive a rate that correctly applies the underwriter-specific multiplier based on the policy coverage type.

**Why this priority**: This is the most fundamental calculation error affecting all standalone lender policies. Without the correct multiplier, every standalone quote is overcharged by 20-25%, directly impacting quote accuracy and customer trust.

**Independent Test**: Can be fully tested by requesting a standalone lender policy quote for any loan amount and verifying the rate is 80% (TRG) or 75% (ORT) of the base rate for Standard coverage, or 90% (TRG) or 85% (ORT) for Extended coverage. Delivers immediate value by fixing quote accuracy for all standalone scenarios.

**Acceptance Scenarios**:

1. **Given** a TRG underwriter and Standard lender policy coverage, **When** calculating a standalone lender policy for a $500,000 loan, **Then** the system returns 80% of the base rate
2. **Given** an ORT underwriter and Standard lender policy coverage, **When** calculating a standalone lender policy for a $500,000 loan, **Then** the system returns 75% of the base rate
3. **Given** a TRG underwriter and Extended lender policy coverage, **When** calculating a standalone lender policy for a $500,000 loan, **Then** the system returns 90% of the base rate
4. **Given** an ORT underwriter and Extended lender policy coverage, **When** calculating a standalone lender policy for a $500,000 loan, **Then** the system returns 85% of the base rate
5. **Given** any underwriter and any coverage type, **When** calculating a standalone lender policy for a $0 loan, **Then** the system returns $0 premium

---

### User Story 2 - Correct Concurrent Lender Excess Calculation (Priority: P1)

When a user requests a concurrent lender policy quote where the loan amount exceeds the owner's policy liability, they receive a rate calculated as $150 plus a percentage of the rate difference between the two policies, not an ELC lookup on the excess amount.

**Why this priority**: This bug causes significant overcharges on concurrent policies with excess coverage. In the example provided, the current calculation returns $648 when the correct amount is $310 - a 109% overcharge. This affects any transaction where loan > owner liability.

**Independent Test**: Can be fully tested by requesting a concurrent lender policy quote with loan amount > owner liability (e.g., owner $400K, loan $500K) and verifying the premium equals $150 + 80% × (rate(loan) - rate(owner)) for TRG or $150 + 75% × (rate(loan) - rate(owner)) for ORT. Delivers immediate value by fixing excess calculation accuracy.

**Acceptance Scenarios**:

1. **Given** a TRG underwriter, owner policy of $400,000, and concurrent Standard lender policy of $500,000, **When** calculating the lender policy premium, **Then** the system returns max($150, $150 + 80% × (rate($500K) - rate($400K)))
2. **Given** an ORT underwriter, owner policy of $400,000, and concurrent Standard lender policy of $500,000, **When** calculating the lender policy premium, **Then** the system returns max($150, $150 + 75% × (rate($500K) - rate($400K)))
3. **Given** any underwriter and concurrent Standard lender policy where loan ≤ owner liability, **When** calculating the lender policy premium, **Then** the system returns $150 flat fee (rate difference is ≤ 0)
4. **Given** a TRG underwriter, owner $400K, loan $500K, **When** rate($500K) = $1,571 and rate($400K) = $1,372, **Then** the lender policy premium equals max($150, $150 + 80% × ($1,571 - $1,372)) = max($150, $309.20) = $309.20
5. **Given** any scenario where the calculated excess $150 + percentage × rate_difference yields less than $150, **When** calculating the lender policy premium, **Then** the system returns $150 (the minimum)

---

### User Story 3 - Extended Concurrent Lender Policy Support (Priority: P2)

When a user requests an Extended Coverage concurrent lender policy quote, the system calculates the rate using the full ELC rate table lookup on the loan amount, rather than the $150 + excess formula used for Standard coverage.

**Why this priority**: Extended concurrent policies are currently unsupported, meaning users cannot obtain quotes for this coverage type. While less common than Standard concurrent, this is a valid product offering that should be available.

**Independent Test**: Can be fully tested by requesting a concurrent Extended lender policy quote for any loan amount and verifying the rate is calculated using the full ELC rate table (not $150 + excess). Delivers value by enabling a previously unsupported product type.

**Acceptance Scenarios**:

1. **Given** any underwriter and Extended concurrent lender policy coverage, **When** calculating the lender policy for any loan amount, **Then** the system looks up the full loan amount in the ELC rate table
2. **Given** a TRG underwriter and Extended concurrent lender policy of $500,000, **When** calculating the premium, **Then** the system uses ELC rate for $500,000 (not $150 + excess calculation)
3. **Given** any underwriter and Extended concurrent lender policy, **When** the loan amount equals the owner liability, **Then** the system still uses the full ELC rate lookup (not $150 flat)

---

### User Story 4 - No Lender Policy on Cash Acquisitions (Priority: P2)

When Opendoor acquires a property via cash purchase (binder acquisition), the system does not calculate or include a lender policy in the quote, since no financing is involved at the acquisition stage.

**Why this priority**: This is a business logic error that causes incorrect quotes for Opendoor's acquisition workflow. While it doesn't affect the accuracy of individual rate calculations, it includes an unnecessary and incorrect line item in acquisition quotes.

**Independent Test**: Can be fully tested by requesting a quote for a cash purchase (is_binder_acquisition: true) and verifying no lender policy is included in the output. Delivers value by fixing quote accuracy for acquisition transactions.

**Acceptance Scenarios**:

1. **Given** a transaction with is_binder_acquisition: true, **When** calculating the title insurance quote, **Then** the system does not calculate or include a lender policy
2. **Given** a transaction with include_lenders_policy: false, **When** calculating the title insurance quote, **Then** the system does not calculate or include a lender policy
3. **Given** a transaction with is_binder_acquisition: true AND include_lenders_policy: true (conflict), **When** calculating the title insurance quote, **Then** the system does not calculate or include a lender policy (is_binder_acquisition takes precedence)
4. **Given** a resale transaction (is_binder_acquisition: false) with a loan amount, **When** calculating the title insurance quote, **Then** the system does calculate and include a lender policy
5. **Given** a purchase transaction with include_lenders_policy: true and a loan amount, **When** calculating the title insurance quote, **Then** the system does calculate and include a lender policy

---

### Edge Cases

- What happens when the loan amount equals the owner liability exactly (should return $150 flat for Standard concurrent)?
- How does the system handle Extended concurrent when loan amount equals owner liability (should use full ELC rate, not $150)?
- When `is_binder_acquisition: true` and `include_lenders_policy: true` conflict, `is_binder_acquisition` takes precedence and no lender policy is included
- Standalone lender policies with $0 loan amount return $0 premium (no loan means no lender policy premium)
- Negative loan amounts are rejected as invalid input (loan amounts must be ≥ $0)
- The concurrent Standard lender premium uses max($150, $150 + percentage × rate_difference) to ensure the total premium cannot be less than $150
- When base rate lookups fail (database unavailable, rate not found), the system raises an error and rejects the quote request to prevent incorrect quotes

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST apply underwriter-specific rate multipliers to standalone lender policy calculations (80% TRG / 75% ORT for Standard; 90% TRG / 85% ORT for Extended)
- **FR-002**: System MUST calculate concurrent Standard lender policy premium as max($150, $150 + X% × (rate(loan) - rate(owner))) where X is the underwriter-specific percentage (80% TRG / 75% ORT), ensuring the total premium cannot be less than $150
- **FR-003**: System MUST use the rate difference between loan and owner policies, not an ELC lookup on the excess amount, when calculating concurrent Standard lender excess
- **FR-004**: System MUST support Extended concurrent lender policies by performing full ELC rate table lookup on the loan amount
- **FR-005**: System MUST differentiate between Standard and Extended concurrent lender policies via a lender_policy_type parameter
- **FR-006**: System MUST skip lender policy calculation when is_binder_acquisition flag is true, regardless of include_lenders_policy value (is_binder_acquisition takes precedence)
- **FR-007**: System MUST skip lender policy calculation when include_lenders_policy flag is false (and is_binder_acquisition is not true)
- **FR-008**: System MUST store underwriter-specific concurrent excess percentages in state rules configuration
- **FR-009**: System MUST return $150 flat fee for Standard concurrent lender policies where loan ≤ owner liability
- **FR-010**: System MUST preserve all existing CSV test scenario results (most use Standard concurrent with loan ≤ owner where $150 flat is correct)
- **FR-011**: System MUST return $0 premium for standalone lender policies when loan amount is $0
- **FR-012**: System MUST raise an error and reject quote requests when base rate lookups fail (database unavailable, rate not found), preventing incorrect quotes from being generated
- **FR-013**: System MUST reject quote requests with negative loan amounts as invalid input (loan amounts must be ≥ $0)

### Key Entities

- **Lender Policy**: A title insurance policy covering the lender's interest in the property, with coverage types (Standard or Extended) and issuance types (standalone or concurrent with owner's policy)
- **Rate Multiplier**: Underwriter-specific percentage applied to base rates for standalone lender policies (e.g., 80% for TRG Standard, 75% for ORT Standard)
- **Concurrent Excess Percentage**: Underwriter-specific percentage applied to the rate difference when loan > owner liability (e.g., 80% for TRG, 75% for ORT)
- **Underwriter Rules**: State-specific configuration containing rate multipliers and concurrent excess percentages for each underwriter (TRG, ORT)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All standalone lender policy quotes return rates that match the rate manual specifications within $1 (80%/75% for Standard, 90%/85% for Extended)
- **SC-002**: All concurrent Standard lender policy quotes with excess coverage return rates calculated as $150 + percentage × rate difference, matching rate manual examples within $1
- **SC-003**: Extended concurrent lender policy quotes can be generated and return rates based on full ELC table lookup
- **SC-004**: Cash acquisition transactions (is_binder_acquisition: true) produce quotes with zero lender policy line items
- **SC-005**: 100% of existing CSV test scenarios continue to produce the same results (regression testing)
- **SC-006**: Manual validation of the TRG $400K owner / $500K loan example produces $310 (not $648), confirming the excess calculation fix
- **SC-007**: System correctly differentiates between Standard and Extended concurrent policies based on coverage type parameter

## Assumptions *(mandatory)*

1. **Rate Manual Authority**: The TRG and ORT rate manuals referenced in docs/rate_manuals/ca/ are the authoritative sources for CA lender policy calculations
2. **Underwriter Identification**: The system can reliably identify whether a quote is for TRG or ORT underwriter to apply the correct percentages
3. **ELC Table Availability**: The ELC (Extended Loan Coverage) rate table is already implemented and accessible for Extended concurrent lookups
4. **Base Rate Calculation**: The BaseRate.calculate method used in standalone policies is working correctly and only needs a multiplier parameter
5. **Concurrent Detection**: The system can reliably detect when a lender policy is concurrent vs. standalone based on the presence of an owner's policy
6. **Coverage Type Input**: The system has or will have a way to receive the lender_policy_type parameter (Standard vs. Extended) as input to the calculation
7. **Flag Precedence**: When is_binder_acquisition: true and include_lenders_policy: true conflict, is_binder_acquisition always takes precedence and no lender policy is included (cash purchases never have lenders)
8. **Minimum Premium**: The $150 concurrent premium is always the minimum, even if the percentage calculation yields a lower amount
9. **Backward Compatibility**: Existing CSV test scenarios use Standard concurrent with loan ≤ owner, where $150 flat is correct, so they should pass without modification

## Dependencies *(if applicable)*

- **Rate Manual References**: CA_TRG_rate_summary.md and CA_ORT_rate_summary.md in docs/rate_manuals/ca/ must be accurate and up-to-date
- **State Rules Configuration**: lib/ratenode/state_rules.rb must support adding underwriter-specific concurrent_standard_excess_percent values
- **ELC Rate Table**: Extended concurrent implementation depends on the ELC rate table being accessible via existing lookup methods
- **Test Data**: New test scenarios for concurrent excess and Extended concurrent require human-provided expected values per constitution Principle V

## Out of Scope *(if applicable)*

- Changes to owner's policy rate calculations
- Changes to base rate tables or ELC rate tables
- Rate calculations for states other than CA
- Changes to endorsement pricing
- UI/UX changes for displaying lender policy options
- Validation of loan-to-value ratios or other business rules beyond rate calculation
- Changes to non-CA underwriter rules or rate structures
