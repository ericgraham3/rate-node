# Feature Specification: Explicit Seed Unit Declaration

**Feature Branch**: `006-explicit-seed-units`
**Created**: 2026-02-05
**Status**: Implemented
**Input**: User description: "Replace the fragile seed unit auto-detection heuristic in the rate tier seeder with an explicit declaration."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer adds a new state without silent misclassification (Priority: P1)

A developer onboarding a new state into the shared rate-tier seeding path declares the unit convention for that state's tier data explicitly, alongside the tier data itself. The seeder reads that declaration and applies the correct conversion (or none). There is no inspection of tier values to guess the unit. A misplaced or missing declaration is a clear, loud failure — not a silent 100x error in seeded rates.

**Why this priority**: This is the core risk the change eliminates. The current heuristic silently misclassifies any state whose first tier min falls in the ambiguous range (>= $1,000 in dollars or < $1,000 in cents). Every new state that routes through the shared seeder is exposed to this until the heuristic is removed.

**Independent Test**: Seed the database using the existing NC, CA, and TX data with the new explicit declarations in place. Compare every seeded rate-tier row against the values produced by the current code. Zero rows should differ.

**Acceptance Scenarios**:

1. **Given** a state module declares its rate tiers are in dollars, **When** the shared seeder processes that state, **Then** all min, max, base, and elc values are multiplied by 100 before insertion.
2. **Given** a state module declares its rate tiers are in cents, **When** the shared seeder processes that state, **Then** all values are inserted as-is with no conversion.
3. **Given** a new state module is added without any unit declaration, **When** the shared seeder attempts to process it, **Then** the seeder raises an explicit error rather than guessing.

---

### User Story 2 - Existing scenario tests remain green after the change (Priority: P2)

All CSV-driven scenario tests that exercise NC, CA, and TX rate calculations continue to pass without modification. This confirms that no seeded values shifted as a result of the structural change.

**Why this priority**: This is the primary validation gate. If any seeded value drifts, downstream premium calculations will produce wrong results and scenario tests will catch it.

**Independent Test**: Run the full CSV scenario test suite. All previously passing scenarios must pass.

**Acceptance Scenarios**:

1. **Given** the explicit unit declarations are in place and the heuristic is removed, **When** the scenario test suite is executed, **Then** every NC, CA, and TX scenario produces the same output as before the change.

---

### Edge Cases

- What happens when a state module defines `RATE_TIERS` but omits the unit declaration entirely? The seeder must fail with an explicit error, not fall back to guessing.
- What happens when the unit declaration disagrees with the actual data (e.g., declares dollars but data is already in cents)? This is a developer error with no runtime safeguard. The scenario test suite is the intended detection mechanism — a mismatch will surface as failing assertions.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each state module that participates in the shared rate-tier seeding path MUST include an explicit unit declaration for its rate tier data, co-located with the data it describes.
- **FR-002**: The shared seeder MUST read the unit declaration from the state module and use it as the sole basis for deciding whether to convert values or pass them through unchanged.
- **FR-003**: The shared seeder MUST NOT inspect any tier value to determine the unit convention. The value-inspection heuristic must be removed entirely.
- **FR-004**: The shared seeder MUST raise an error if the unit declaration is missing or carries an unrecognized value, rather than applying a default conversion silently.
- **FR-005**: NC and CA MUST declare their rate tiers as dollars. TX MUST declare its rate tiers as cents. These match the conventions already present in their data.
- **FR-006**: FL and AZ are out of scope. They use dedicated seed methods and do not route through the shared seeder.
- **FR-007**: No seeded data values (min, max, base, per_thousand, elc) for NC, CA, or TX shall change as a result of this work.

### Key Entities

- **State Module**: A module (NC, CA, TX) that owns rate tier data and, after this change, an explicit unit declaration consumed by the shared seeder.
- **Shared Rate-Tier Seeder**: The method responsible for inserting rate tiers into the database for states that share a common seeding path. Its unit-handling logic is the sole target of this change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero seeded rate-tier rows differ between a run with the current heuristic and a run with the explicit declarations, across all three affected states (NC, CA, TX).
- **SC-002**: All CSV scenario tests that pass before the change continue to pass after — zero regressions.
- **SC-003**: Attempting to seed a state that omits the unit declaration produces an explicit error at seed time rather than silently incorrect data.

## Assumptions

- The unit declaration is implemented as an explicit constant in each state seed module (e.g., `RATE_TIERS_UNIT = :dollars`), consumed by the shared seeder. This is preferred over a call-site parameter because it keeps the declaration co-located with the data it describes.
- FL and AZ are excluded. They already use dedicated seed methods that handle unit conventions independently.
- The developer is responsible for setting the declaration to match the actual data. There is no runtime cross-check. Correctness is validated by the scenario test suite.
- NC and CA tier data is in dollars; TX tier data is in cents. These are the conventions already in effect and must not change.
