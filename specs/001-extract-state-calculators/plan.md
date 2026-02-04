# Implementation Plan: Extract State Calculators into Plugin Architecture

**Branch**: `001-extract-state-calculators` | **Date**: 2026-02-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-extract-state-calculators/spec.md`

## Summary

Extract state-specific rate calculation logic from the monolithic `OwnersPolicy` and `AZCalculator` classes into isolated, per-state calculator plugins. Create a `BaseStateCalculator` contract, a factory for routing, and a shared utilities module for common operations (rounding, tier lookup). This enables adding new states without modifying existing ones and ensures bug fixes are quarantined to affected states only.

## Technical Context

**Language/Version**: Ruby 3.4.8
**Primary Dependencies**: sqlite3 ~> 1.6, thor ~> 1.3, csv (stdlib), rspec ~> 3.12
**Storage**: SQLite with custom Database singleton (`lib/ratenode/database.rb`)
**Testing**: RSpec with CSV-driven scenario tests (37 scenarios in `spec/fixtures/scenarios_input.csv`)
**Target Platform**: CLI tool (Linux/macOS)
**Project Type**: Single Ruby project with CLI interface
**Performance Goals**: No regression from current behavior (pure structural refactor)
**Constraints**: All existing CSV scenario tests must pass after refactor
**Scale/Scope**: 5 state calculators (AZ, FL, CA, TX, NC), ~1,227 lines of calculator/model code to refactor

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. State Isolation | ✅ ALIGNED | This refactor directly implements state isolation - each state gets its own calculator file |
| II. Contract-First Design | ✅ ALIGNED | BaseStateCalculator defines the contract; implementations own their logic |
| III. Prove Before Extracting | ✅ ALIGNED | Only extracting utilities proven across 2+ states (rounding, tier lookup) |
| IV. Configuration Over Scattered Conditionals | ✅ ALIGNED | State-specific rules remain in `state_rules.rb`; case statements eliminated |
| V. CSV Scenario Coverage | ✅ ALIGNED | Existing 37 scenarios serve as regression safety net; no new scenarios needed for refactor |
| VI. Documentation Accessibility | ✅ ALIGNED | No documentation changes required for internal refactor |

**Agent Constraints Verification**:
- [ ] Will NOT create cross-state dependencies
- [ ] Will NOT create shared base classes with logic (only abstract contract)
- [ ] Will NOT modify CSV scenario file
- [ ] Utilities extraction limited to pre-approved: rounding, tier lookup

**Quality Gates (pre-merge)**:
- [ ] All CSV scenario tests pass
- [ ] State-specific logic isolated (no cross-state conditionals)
- [ ] Factory returns correct calculator per state

## Project Structure

### Documentation (this feature)

```text
specs/001-extract-state-calculators/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── base_state_calculator.rb
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
lib/ratenode/
├── ratenode.rb                    # Main module (no changes)
├── calculator.rb                  # UPDATE: Use factory instead of direct instantiation
├── state_rules.rb                 # State configuration (no changes)
├── database.rb                    # SQLite singleton (no changes)
│
├── calculators/
│   ├── base_state_calculator.rb   # NEW: Abstract contract
│   ├── state_calculator_factory.rb # NEW: Factory with singleton caching
│   ├── utilities/                 # NEW: Shared utilities
│   │   ├── rounding.rb           # Extract from AZCalculator, BaseRate
│   │   └── tier_lookup.rb        # Extract from RateTier
│   ├── states/                    # NEW: Per-state implementations
│   │   ├── az.rb                 # Migrate from az_calculator.rb
│   │   ├── fl.rb                 # Extract from owners_policy.rb
│   │   ├── ca.rb                 # Extract from owners_policy.rb
│   │   ├── tx.rb                 # Extract from owners_policy.rb
│   │   └── nc.rb                 # Extract from owners_policy.rb
│   │
│   ├── base_rate.rb              # UPDATE: Delegate rounding to utilities
│   ├── lenders_policy.rb         # UPDATE: Delegate state logic to calculators
│   ├── cpl_calculator.rb         # UPDATE: Delegate state logic to calculators
│   └── endorsement_calculator.rb # No changes
│
├── models/                        # Minimal changes
│   ├── rate_tier.rb              # UPDATE: Delegate TX formula to States::TX
│   └── ...                       # Other models unchanged
│
└── output/                        # No changes

spec/
├── integration/
│   └── csv_scenarios_spec.rb     # Existing test suite (no changes to tests)
├── fixtures/
│   └── scenarios_input.csv       # Protected - no agent modifications
└── unit/                         # NEW: Unit tests for new components
    ├── base_state_calculator_spec.rb
    ├── state_calculator_factory_spec.rb
    └── utilities/
        ├── rounding_spec.rb
        └── tier_lookup_spec.rb
```

**Structure Decision**: Single Ruby project. New `calculators/states/` directory contains isolated per-state calculators. New `calculators/utilities/` contains pre-approved shared functions.

## Files to Remove (after migration complete)

| File | Reason |
|------|--------|
| `lib/ratenode/calculators/az_calculator.rb` | Logic migrated to `states/az.rb` |
| `lib/ratenode/calculators/owners_policy.rb` | Logic split across `states/fl.rb`, `states/ca.rb`, `states/tx.rb`, `states/nc.rb` |

## Complexity Tracking

No constitution violations to justify. This refactor:
- Reduces complexity by eliminating cross-state conditionals
- Follows "isolation over consolidation" principle
- Only extracts pre-approved utilities (rounding, tier lookup)

---

## Post-Design Constitution Re-Check

*Verified after Phase 1 design artifacts generated.*

| Principle | Status | Design Artifact Compliance |
|-----------|--------|---------------------------|
| I. State Isolation | ✅ PASS | Each state has dedicated file in `states/`. No cross-state imports in contracts. |
| II. Contract-First Design | ✅ PASS | `BaseStateCalculator` defines interface. States implement, factory routes. |
| III. Prove Before Extracting | ✅ PASS | Utilities limited to pre-approved: `Rounding`, `TierLookup`. No domain logic extracted. |
| IV. Configuration Over Conditionals | ✅ PASS | Factory uses case statement for routing only. State logic reads `STATE_RULES`. |
| V. CSV Scenario Coverage | ✅ PASS | Design does not modify CSV. Quickstart marks new scenarios as human task. |
| VI. Documentation Accessibility | ✅ PASS | Quickstart uses plain language. Contracts have YARD documentation. |

**Design Artifacts Generated**:
- `research.md` - Technical decisions documented
- `data-model.md` - Entity relationships mapped
- `contracts/base_state_calculator.rb` - Abstract contract with YARD docs
- `contracts/state_calculator_factory.rb` - Factory with error handling
- `contracts/utilities.rb` - Rounding and TierLookup modules
- `quickstart.md` - Developer guide with examples

**Ready for**: `/speckit.tasks` to generate implementation tasks
