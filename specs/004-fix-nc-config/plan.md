# Implementation Plan: Fix NC Rate Configuration and Cross-State Policy Type Symbol

**Branch**: `004-fix-nc-config` | **Date**: 2026-02-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-fix-nc-config/spec.md`

## Summary

This feature addresses three categories of NC rate configuration discrepancies identified during validation:

1. **P1 - Endorsement List**: NC endorsement catalogue contains 46 entries from various states' rate manuals but should contain exactly 3 per NC rate manual PR-10 (ALTA 5, ALTA 8.1, ALTA 9 at $23.00 flat each)
2. **P2 - Policy Type Symbol**: Arizona uses `homeowners` while NC/CA/FL/TX use `homeowner`; standardize to `homeowners` to match AZ CSV fixtures
3. **P3 - Minimum Premium & Rounding**: NC minimum premium is 0 (should be $56.00) and rounding is $10,000 (should be $1,000)

Technical approach: Configuration-driven changes to `state_rules.rb` and `nc_rates.rb` seed data; symbol rename in `policy_type.rb` and all state calculators. No algorithmic changes required.

## Technical Context

**Language/Version**: Ruby 3.4.8
**Primary Dependencies**: sqlite3 ~> 1.6, thor ~> 1.3, csv (stdlib), rspec ~> 3.12
**Storage**: SQLite with Sequel ORM for rate tier and endorsement lookups
**Testing**: RSpec with CSV-driven scenario tests (`spec/fixtures/scenarios_input.csv`)
**Target Platform**: CLI tool (Linux/macOS)
**Project Type**: Single project (CLI tool)
**Performance Goals**: N/A (batch calculation tool)
**Constraints**: CSV fixture file must not be modified (per constitution Principle V)
**Scale/Scope**: 5 states currently implemented (AZ, CA, FL, NC, TX)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. State Isolation | ✅ PASS | Changes are NC-specific (endorsements, minimum, rounding) or cross-state config alignment (policy type symbol). No cross-state dependencies introduced. |
| II. Contract-First Design | ✅ PASS | No interface changes. All state calculators already implement `BaseStateCalculator`. |
| III. Prove Before Extracting | ✅ PASS | No new abstractions. Editing existing configuration. |
| IV. Configuration Over Scattered Conditionals | ✅ PASS | All changes go to `state_rules.rb` or seed data files, not scattered conditionals. |
| V. CSV Scenario Coverage | ✅ PASS | Existing CSV tests must pass without modification. New test scenarios for minimum/rounding require human-provided expected values (FR-007). |
| VI. Documentation Accessibility | ✅ PASS | Changes are to configuration values referencing NC rate manual sections (PR-1, PR-10). |

**Pre-Phase 0 Gate**: PASSED

**Post-Phase 1 Re-check**: PASSED (2026-02-05)
- No new abstractions introduced
- All changes remain configuration-driven
- CSV fixtures remain unmodified
- State isolation maintained (NC-specific changes isolated, cross-state symbol change is alignment only)

## Project Structure

### Documentation (this feature)

```text
specs/004-fix-nc-config/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output (minimal - config changes only)
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/ratenode/
├── state_rules.rb                    # NC minimum_premium_cents, rounding_increment_cents, policy_type_multipliers
├── models/
│   └── policy_type.rb                # TYPES and NC_TYPES constants (homeowner → homeowners)
└── calculators/states/
    ├── az.rb                         # format_policy_type display (already uses homeowners)
    ├── ca.rb                         # format_policy_type display (homeowner → homeowners)
    ├── fl.rb                         # format_policy_type display (homeowner → homeowners)
    ├── nc.rb                         # format_policy_type display (homeowner → homeowners)
    └── tx.rb                         # format_policy_type display (homeowner → homeowners)

db/seeds/data/
└── nc_rates.rb                       # ENDORSEMENTS array (reduce 46 → 3)

spec/fixtures/
└── scenarios_input.csv               # DO NOT MODIFY (human-controlled)
```

**Structure Decision**: Single project layout. All changes are to existing configuration files and seed data. No new files needed.

## Complexity Tracking

No constitution violations requiring justification. This is a straightforward configuration correction feature.
