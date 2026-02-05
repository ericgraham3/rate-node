# Implementation Plan: Explicit Seed Unit Declaration

**Branch**: `006-explicit-seed-units` | **Date**: 2026-02-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-explicit-seed-units/spec.md`

## Summary

Replace the fragile value-inspection heuristic in `seed_rate_tiers()` with an explicit `RATE_TIERS_UNIT` constant declaration in each state module. NC and CA declare `:dollars`, TX declares `:cents`. The seeder reads this declaration and applies the correct conversion (or none). A missing or unrecognized declaration is a clear error, not a silent misclassification.

## Technical Context

**Language/Version**: Ruby 3.4.8
**Primary Dependencies**: thor ~> 1.3, sqlite3 ~> 1.6
**Storage**: SQLite database with `rate_tiers` table
**Testing**: RSpec ~> 3.12 with CSV-driven scenario tests
**Target Platform**: CLI tool (Linux/macOS)
**Project Type**: Single Ruby project
**Performance Goals**: N/A (one-time seed operation)
**Constraints**: Zero change to seeded data values; all CSV scenario tests must pass unchanged
**Scale/Scope**: 3 state modules (NC, CA, TX); 1 shared seeder method

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design — all principles still pass.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. State Isolation | ✅ Pass | Change is to state module declarations and shared seeder. Each state gets its own declaration co-located with its data. No cross-state dependencies introduced. |
| II. Contract-First Design | ✅ Pass | No calculator contract changes. This is purely seed infrastructure. |
| III. Prove Before Extracting | ✅ Pass | Not extracting any abstraction. The constant convention is the simplest possible approach. |
| IV. Configuration Over Scattered Conditionals | ✅ Pass | Unit declaration is co-located configuration, not a scattered conditional. |
| V. CSV Scenario Coverage | ✅ Pass | No CSV changes required. Existing scenarios validate that seeded values remain identical. |
| VI. Documentation Accessibility | ✅ Pass | The constant name (`RATE_TIERS_UNIT = :dollars`) is self-documenting. |

**Post-Design Re-check**: ✅ All principles still pass. The design adds explicit declarations without introducing cross-state dependencies, premature abstractions, or scattered conditionals.

**Quality Gates Verification**:
- [ ] All CSV scenario tests pass (`bundle exec rspec`)
- [ ] State-specific logic is isolated (no cross-state conditionals added)
- [ ] Rate calculations match published/promulgated rate manuals exactly

## Project Structure

### Documentation (this feature)

```text
specs/006-explicit-seed-units/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
└── quickstart.md        # Phase 1 output
```

### Source Code (repository root)

```text
db/
└── seeds/
    ├── rates.rb                    # Shared seeder (MODIFY: remove heuristic, read RATE_TIERS_UNIT)
    └── data/
        ├── nc_rates.rb             # NC state module (MODIFY: add RATE_TIERS_UNIT = :dollars)
        ├── ca_rates.rb             # CA state module (MODIFY: add RATE_TIERS_UNIT = :dollars)
        ├── tx_rates.rb             # TX state module (MODIFY: add RATE_TIERS_UNIT = :cents)
        ├── fl_rates.rb             # Out of scope (dedicated seeder)
        └── az_rates.rb             # Out of scope (dedicated seeder)

spec/
└── fixtures/
    └── scenarios_input.csv         # Existing test scenarios (NO CHANGE)
```

**Structure Decision**: Uses existing project structure. No new directories or files needed. Changes are limited to 4 existing Ruby files.

## Complexity Tracking

> No constitution violations. Table omitted.
