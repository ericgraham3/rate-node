# Feature Specification: Fix CA Over-$3M Formulas and Minimum Premium

**Feature Branch**: `008-fix-ca-3m-formulas`
**Created**: 2026-02-05
**Status**: Draft
**Input**: User description: "Fix CA over-$3M formulas, minimum premium, and refinance cap. Consolidates remaining work from original Passes B, C, and D after the 007-fix-ca-lender implementation."

## Clarifications

### Session 2026-02-05

- Q: TRG ELC per-$10K increment above $3M was estimated at $2.75. What is the exact value from the rate manual? → A: TRG schedule of rates (base rate) is $5.25 per $10K over $3M; TRG Extended Lender Concurrent (ELC) is $4.20 per $10K over $3M
- Q: When should minimum premium be applied? FR-004 says "after policy-type multipliers but before hold-open surcharges" but User Story 3 says "before multipliers/surcharges". Which is correct? → A: Apply minimum to base rate first, then apply all multipliers and surcharges
- Q: At exactly $3,000,000, should the system use tier-based rate from seed data or the over-$3M formula? → A: Use tier-based rate from seed data; over-$3M formula applies only to amounts > $3,000,000
- Q: Refinance rates under $10M use tier lookups but over $10M use runtime formulas. How should this dual approach be implemented? → A: Keep runtime calculation for >$10M as stated; calculator branches based on amount threshold
- Q: Should refinance formula parameters also be stored in state_rules.rb like over-$3M parameters? → A: Store all formula parameters in state_rules.rb including refinance parameters for consistency

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Calculate Accurate Premiums for High-Value Properties (Priority: P1)

Users need accurate title insurance premium calculations for properties valued over $3 million in California, with different rates applied correctly for TRG and ORT underwriters.

**Why this priority**: This is the core business requirement. Incorrect premium calculations for high-value properties can result in significant revenue loss or overcharging customers, potentially leading to legal and compliance issues.

**Independent Test**: Can be fully tested by providing property values above $3M for both TRG and ORT underwriters and comparing calculated premiums against rate manual specifications.

**Acceptance Scenarios**:

1. **Given** a CA property with TRG underwriter and liability amount of $3,500,000, **When** calculating the standard owner premium, **Then** the system applies TRG's over-$3M formula (base $4,211 + $5.25 per $10K increment)
2. **Given** a CA property with ORT underwriter and liability amount of $3,500,000, **When** calculating the standard owner premium, **Then** the system applies ORT's over-$3M formula (base $4,438 + $6.00 per $10K increment)
3. **Given** a CA property with liability amount of $5,000,000, **When** calculating premiums for both underwriters, **Then** each underwriter's specific rate formula produces different results per their respective rate manuals

---

### User Story 2 - Calculate Accurate Extended Lender Concurrent (ELC) Rates Above $3M (Priority: P1)

Users need correct ELC premium calculations for concurrent lender policies on high-value properties, with underwriter-specific formulas applied.

**Why this priority**: ELC is a common product for commercial transactions. The current formula produces rates that are ~99% too low (cents instead of dollars), making this a critical revenue leak.

**Independent Test**: Can be fully tested by requesting concurrent lender policies above $3M and validating ELC premiums against rate manual specifications for each underwriter.

**Acceptance Scenarios**:

1. **Given** a CA property with ORT underwriter and concurrent lender policy at $3,500,000, **When** calculating the ELC rate, **Then** the system applies ORT's formula ($2,550 base + $3.00 per $10K increment)
2. **Given** a CA property with TRG underwriter and concurrent lender policy at $3,500,000, **When** calculating the ELC rate, **Then** the system applies TRG's formula ($2,472 base + $4.20 per $10K increment)
3. **Given** a CA property with liability amount of $5,000,000, **When** calculating ELC rates for both underwriters, **Then** the ELC premium is in the range of thousands of dollars, not cents

---

### User Story 3 - Apply Correct Minimum Premium Floor (Priority: P2)

Users need minimum premium enforcement for low-value properties to ensure compliance with underwriter rate schedules.

**Why this priority**: While less common than high-value calculations, minimum premiums protect against revenue loss on small transactions and ensure regulatory compliance.

**Independent Test**: Can be fully tested by calculating premiums for properties at very low liability amounts ($10K, $50K) and verifying the minimum premium is enforced for each underwriter.

**Acceptance Scenarios**:

1. **Given** a CA property with TRG underwriter and liability amount of $10,000, **When** calculating the standard owner premium, **Then** the system returns the minimum premium of $609
2. **Given** a CA property with ORT underwriter and liability amount of $10,000, **When** calculating the standard owner premium, **Then** the system returns the minimum premium of $725
3. **Given** a CA property with calculated premium below the minimum, **When** applying policy-type multipliers or hold-open surcharges, **Then** the minimum is applied before multipliers/surcharges

---

### User Story 4 - Calculate Refinance Premiums Above $10M with Progressive Rates (Priority: P3)

Users need accurate refinance premium calculations for ultra-high-value properties with incremental rates applied above $10 million.

**Why this priority**: This affects the smallest subset of transactions (refinances above $10M) but is still important for accurate pricing on large commercial deals.

**Independent Test**: Can be fully tested by calculating refinance premiums for properties above $10M and validating the progressive rate formula against rate manuals.

**Acceptance Scenarios**:

1. **Given** a CA refinance transaction with TRG underwriter and liability amount of $12,000,000, **When** calculating the refinance premium, **Then** the system applies TRG's formula ($7,200 base + $800 per million over $10M = $8,800)
2. **Given** a CA refinance transaction with ORT underwriter and liability amount of $15,000,000, **When** calculating the refinance premium, **Then** the system applies ORT's formula ($7,610 base + $1,000 per million over $10M = $12,610)
3. **Given** a CA refinance transaction at exactly $10,000,001, **When** calculating the refinance premium, **Then** the system correctly handles the boundary condition

---

### Edge Cases

- At exactly $3,000,000: System uses tier-based rate from seed data; over-$3M formula applies only to amounts strictly greater than $3,000,000 (boundary is exclusive)
- At exactly $10,000,000: System uses top tier flat rate from seed data; progressive refinance formula applies only to amounts strictly greater than $10,000,000
- Minimum premium with hold-open surcharge: Minimum is applied to base calculated rate first, then hold-open surcharge is added to the post-minimum amount
- ELC at exactly $3,000,000: System uses $3M tier rate from seed data; ELC over-$3M formula applies only to amounts > $3,000,000
- Concurrent lender policies with mixed liability ranges: Each policy (owner and lender) uses the appropriate calculation method (tier-based or formula-based) for its own liability amount independently

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST calculate owner premiums above $3M using underwriter-specific formulas (TRG: $4,211 base + $5.25 per $10K; ORT: $4,438 base + $6.00 per $10K)
- **FR-002**: System MUST calculate Extended Lender Concurrent (ELC) premiums above $3M using underwriter-specific formulas (TRG: $2,472 base + $4.20 per $10K; ORT: $2,550 base + $3.00 per $10K)
- **FR-003**: System MUST enforce minimum premium requirements (TRG: $609; ORT: $725) on all standard owner policy calculations
- **FR-004**: System MUST apply minimum premium floor to base calculated rate before applying any policy-type multipliers or hold-open surcharges
- **FR-005**: System MUST calculate refinance premiums above $10M using progressive formulas (TRG: $7,200 + $800/million; ORT: $7,610 + $1,000/million)
- **FR-006**: System MUST pass underwriter identifier through the calculation pipeline to enable formula selection in rate_tier.rb methods
- **FR-007**: System MUST store all formula parameters in state_rules.rb configuration for each underwriter (over_3m_base_cents, over_3m_per_10k_cents, elc_over_3m_base_cents, elc_over_3m_per_10k_cents, refinance_over_10m_base_cents, refinance_over_10m_per_million_cents, minimum_premium_cents)
- **FR-008**: System MUST remove hardcoded TRG-only constants from rate_tier.rb (OVER_3M_BASE_CENTS, OVER_3M_PER_10K_CENTS)
- **FR-009**: System MUST support refinance calculations with both tier-based rates (≤$10M) and formula-based rates (>$10M)
- **FR-010**: System MUST use tier-based rates at boundary thresholds (exactly $3,000,000 and exactly $10,000,000); formula-based calculations apply only to amounts strictly greater than threshold values
- **FR-011**: Refinance calculator MUST branch on $10M threshold: use rate_tiers table lookup for amounts ≤$10M, use runtime progressive formula for amounts >$10M

### Key Entities

- **Rate Tier**: Represents tiered premium rates for liability amount ranges; includes over-$3M formula parameters specific to each underwriter
- **State Rules**: Configuration defining underwriter-specific calculation parameters stored in state_rules.rb; includes minimum premiums, over-$3M owner formulas, ELC over-$3M formulas, and refinance over-$10M formulas (all parameters in cents for consistency with existing codebase)
- **Refinance Rate**: Represents refinance premium rates with support for both fixed tiers and progressive formulas above threshold amounts
- **Underwriter**: Identifier (TRG or ORT) that determines which rate formulas and parameters to apply

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Premium calculations for properties valued at $3.5M, $5M, and $10M match expected values from TRG and ORT rate manual summaries within $2.00 tolerance
- **SC-002**: ELC premium calculations for concurrent policies at $3.5M and $5M produce values in thousands of dollars (not cents) matching rate manual specifications within $2.00 tolerance
- **SC-003**: Minimum premium enforcement for properties at $10K and $50K liability returns exactly $609 for TRG and $725 for ORT
- **SC-004**: Refinance premium calculations above $10M produce progressive rates matching manual specifications (e.g., $12M refinance = $8,800 TRG, not flat $7,200)
- **SC-005**: All existing CSV scenario tests continue to pass with updated formulas (within $2.00 tolerance)
- **SC-006**: All existing unit tests for CA calculator continue to pass with no regressions

## Assumptions *(mandatory)*

- TRG over-$3M rates from rate manual: Schedule of rates (owner base) is $4,211 base + $5.25 per $10K; Extended Lender Concurrent (ELC) is $2,472 base + $4.20 per $10K
- Minimum premium is applied to the base calculated rate before any policy-type multipliers or hold-open surcharges (calculation order: base rate → apply minimum floor → multiply by policy-type factor → add hold-open surcharge)
- The $2.00 tolerance in CSV scenario tests accounts for rounding differences and `round_up_to_dollar` grand total adjustment
- Refinance calculations use dual approach: tier-based lookup from rate_tiers table for amounts ≤$10M, runtime formula calculation for amounts >$10M (refinance calculator branches on threshold)
- Underwriter parameter will be available throughout the calculation pipeline from initial Calculator call through to rate_tier.rb methods

## Constraints

- Must maintain backward compatibility with existing calculation pipeline architecture
- Must not break existing tests for other states (AZ, FL, NC)
- Must preserve current hold-open/binder workflow implemented in 007-fix-ca-lender
- Must work within existing Sequel ORM and rate_tiers table schema
- Configuration changes limited to state_rules.rb; no database schema modifications required

## Dependencies

- Requires rate manual documentation at `docs/rate_manuals/ca/CA_TRG_rate_summary.md` and `CA_ORT_rate_summary.md`
- Requires existing CSV scenario test infrastructure at `spec/integration/csv_scenarios_spec.rb`
- Requires existing CA unit tests at `spec/calculators/states/ca_spec.rb`
- Depends on underwriter parameter being available from Calculator → BaseRate → RateTier call chain
- Depends on state_rules.rb `rules_for(state, underwriter:)` method for retrieving underwriter-specific configuration

## Out of Scope

- Changes to other states' calculation logic (AZ, FL, NC)
- Modifications to lender policy calculation logic (already completed in 007-fix-ca-lender)
- Changes to hold-open/binder workflow (already completed in 007-fix-ca-lender)
- Database schema changes or migrations
- New endorsement types or rate products
- User interface changes
- Changes to CSV test input format or tolerance values
- Performance optimization (calculation accuracy is the priority)
