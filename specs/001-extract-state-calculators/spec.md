# Feature Specification: Extract State Calculators into Plugin Architecture

**Feature Branch**: `001-extract-state-calculators`
**Created**: 2026-02-03
**Status**: Draft
**Input**: User description: "Extract state calculators into plugin architecture with BaseStateCalculator contract, shared utilities module, and isolated per-state implementations (AZ, FL, CA, TX, NC). See docs/implementation_notes/proposal.md. Note that there is currently a bug with NC reissue rates that will need to be addressed either in the refactor or afterwards."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add a New State Calculator (Priority: P1)

As a developer, I need to add rate calculation support for a new state (e.g., Colorado) by creating a single file that implements a well-defined contract, without modifying existing state calculators or core logic.

**Why this priority**: This is the primary value proposition of the plugin architecture - making state additions isolated, predictable, and safe. If a developer can add CO without touching AZ/FL/CA/TX/NC code, the architecture is working.

**Independent Test**: Can be fully tested by creating a new state calculator file, registering it with the factory, and verifying it calculates premiums correctly while all existing state tests continue to pass unchanged.

**Acceptance Scenarios**:

1. **Given** the plugin architecture is in place, **When** a developer creates a new state calculator implementing `BaseStateCalculator`, **Then** the new state is automatically available through the factory without modifying existing code
2. **Given** a new state calculator is added, **When** existing state tests are run, **Then** all existing tests pass without modification
3. **Given** a developer needs to implement state-specific logic, **When** they examine the `BaseStateCalculator` contract, **Then** they understand exactly what methods must be implemented

---

### User Story 2 - Fix State-Specific Bug Without Risk (Priority: P1)

As a developer, I need to fix a bug in one state's calculation (e.g., NC reissue rates) with confidence that my fix cannot affect any other state's behavior.

**Why this priority**: Bug isolation is the second core value of this architecture. The NC reissue rate bug mentioned in requirements demonstrates why this matters - a fix should be quarantined to NC only.

**Independent Test**: Can be tested by modifying NC calculator logic and running the full test suite, verifying only NC-related tests are affected while AZ/FL/CA/TX tests remain unchanged.

**Acceptance Scenarios**:

1. **Given** a bug exists in the NC reissue rate calculation, **When** a developer modifies the NC state calculator, **Then** no code paths in AZ, FL, CA, or TX calculators are executed or changed
2. **Given** state calculators are isolated, **When** a developer reviews a fix for one state, **Then** they only need to review that state's file and shared utilities (if used)
3. **Given** the NC calculator has a bug fix applied, **When** the test suite runs, **Then** only NC scenario tests reflect changed behavior

---

### User Story 3 - Calculate Premium Using Correct State Logic (Priority: P1)

As a rate calculation system, I need to route premium calculation requests to the correct state-specific calculator based on the state parameter, ensuring each state's unique rules are applied.

**Why this priority**: This is the core runtime functionality - without correct routing, the architecture provides no value to end users.

**Independent Test**: Can be tested by calling the factory with each supported state code and verifying the correct calculator type handles the request and produces expected output.

**Acceptance Scenarios**:

1. **Given** a premium calculation request for Arizona, **When** the factory routes the request, **Then** the AZ-specific calculator handles it using AZ rate rules
2. **Given** a premium calculation request for Florida, **When** the factory routes the request, **Then** the FL-specific calculator handles it using FL reissue rate table logic
3. **Given** a premium calculation request for an unsupported state, **When** the factory attempts to route, **Then** an appropriate error indicates the state is not supported

---

### User Story 4 - Access Shared Utilities Across States (Priority: P2)

As a state calculator implementation, I need access to common utility functions (rounding, tier lookup) without duplicating code, while maintaining the ability to override behavior when state-specific rules differ.

**Why this priority**: Reduces code duplication and maintenance burden, but is secondary to establishing isolation. Shared utilities only emerge after patterns prove themselves.

**Independent Test**: Can be tested by verifying multiple state calculators use the same utility function and produce consistent results for identical inputs.

**Acceptance Scenarios**:

1. **Given** AZ and FL both need to round premiums up, **When** they use the shared rounding utility, **Then** both produce identical rounding behavior for the same input
2. **Given** a state has unique rounding rules, **When** that state's calculator is implemented, **Then** it can override the default utility behavior without affecting other states
3. **Given** duplicate logic exists in current codebase (e.g., `rounded_liability`), **When** the refactor completes, **Then** that logic exists in exactly one place in the utilities module

---

### Edge Cases

- What happens when a state code is provided that doesn't have a registered calculator? System returns clear error indicating unsupported state.
- How does system handle case sensitivity in state codes (e.g., "az" vs "AZ")? State codes are normalized before lookup.
- What happens if a state calculator fails to implement a required contract method? System raises `NotImplementedError` at call time (Ruby behavior; `BaseStateCalculator` methods raise if not overridden).
- How does system handle underwriter variance (TRG vs ORT) within a state? Handled via configuration or parameters passed to state calculator, not separate sub-classes (unless logic diverges significantly).
- How does system handle product type variance (purchase vs refinance)? Passed as parameter to calculator methods; state implementation decides how to apply.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `BaseStateCalculator` base class that defines the contract all state calculators implement
- **FR-002**: System MUST provide methods in the contract for `calculate_owners_premium` and `calculate_lenders_premium` only; each state MAY define additional methods (e.g., simultaneous issue, reissue rate) as needed; all methods accept a single parameter object/hash containing calculation inputs
- **FR-003**: System MUST provide a utilities module containing extracted common functions (rounding, tier lookup)
- **FR-004**: System MUST implement isolated state calculators for: AZ, FL, CA, TX, NC
- **FR-005**: Each state calculator MUST inherit from `BaseStateCalculator` and implement the required contract methods
- **FR-006**: System MUST provide a factory method (`StateCalculator.for(state_code, ...)`) that returns a cached singleton calculator instance per state (calculators must be stateless)
- **FR-007**: The factory MUST return an appropriate error for unsupported state codes
- **FR-008**: State calculators MUST NOT share mutable state or have dependencies on other state calculators
- **FR-009**: System MUST migrate existing `AZCalculator` logic to the new `States::AZ` calculator and remove the old `AZCalculator` class
- **FR-010**: System MUST extract `OwnersPolicy` state-specific logic into respective state calculators (FL, CA, TX, NC) and remove the old `OwnersPolicy` class
- **FR-011**: System MUST establish file/naming conventions for adding future states (e.g., `states/co.rb` for Colorado)
- **FR-012**: Existing CSV scenario tests (37 scenarios) MUST continue to pass after refactor
- **FR-013**: The NC reissue rate calculation bug MUST be documented and tracked, addressed either during or after the refactor

### Key Entities

- **BaseStateCalculator**: Abstract base class defining the contract (required methods, utility access) that all state implementations must follow
- **State Calculator (States::XX)**: Concrete implementation for a specific state containing all rate calculation logic unique to that state
- **Utilities Module**: Collection of pure functions for common operations (rounding, tier lookup) shared across calculators
- **Calculator Factory**: Routing mechanism that accepts a state code and returns the appropriate state calculator instance

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 5 state calculators (AZ, FL, CA, TX, NC) implement the `BaseStateCalculator` contract
- **SC-002**: 100% of existing CSV scenario tests pass after the refactor (no behavioral regression)
- **SC-003**: Adding a new state requires creating only 1 new file plus test scenarios (no modifications to existing state files)
- **SC-004**: A bug fix to any single state calculator touches only that state's file (and optionally shared utilities)
- **SC-005**: Zero code duplication of rounding logic across state calculators (consolidated in utilities)
- **SC-006**: The NC reissue rate bug is documented with a clear reproduction path, even if not fixed during initial refactor

## Clarifications

### Session 2026-02-03

- Q: Should the BaseStateCalculator contract include additional methods beyond owners/lenders premium (e.g., simultaneous issue, reissue rate)? → A: Let each state define its own additional methods beyond the two core ones
- Q: Should the factory create new calculator instances per request or return cached singletons? → A: Factory returns singleton/cached calculator per state (stateless)
- Q: Should old entry points (AZCalculator, OwnersPolicy) be preserved as deprecated wrappers or removed? → A: Remove old classes entirely; all callers use new factory pattern
- Q: How should calculation parameters be passed to contract methods? → A: Single parameter object/hash containing all calculation inputs
- Q: Should underwriter variance (TRG vs ORT) be handled as parameters or allow sub-classes? → A: Always parameters/config within state calculator; no underwriter sub-classes

## Assumptions

- The existing CSV scenario tests provide adequate coverage for validating no behavioral regression
- Underwriter variance (TRG vs ORT) and product type variance (purchase vs refinance) will always be handled as parameters/configuration within state calculators; no underwriter or product-type sub-classes will be created
- "Isolation over consolidation" is the guiding principle - even states with similar logic today get separate implementations
- Shared utilities only contain logic proven across 2+ states; speculative abstractions are avoided
