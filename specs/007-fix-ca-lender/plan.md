# Implementation Plan: Fix CA Lender Policy Calculation Bugs

**Branch**: `007-fix-ca-lender` | **Date**: 2026-02-05 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-fix-ca-lender/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Fix four critical calculation errors in California lender policy pricing: (1) apply underwriter-specific multipliers (80% TRG / 75% ORT) to standalone lender policies, (2) calculate concurrent Standard lender excess as $150 + percentage × rate_difference (not ELC lookup on excess), (3) support Extended concurrent lender policies via full ELC rate lookup, and (4) skip lender policy calculation when is_binder_acquisition flag is true. These bugs cause quote overcharges ranging from 20-109% and prevent certain product offerings.

## Technical Context

**Language/Version**: Ruby 3.4.8
**Primary Dependencies**: Sequel ORM, thor ~> 1.3, sqlite3 ~> 1.6, rspec ~> 3.12
**Storage**: SQLite database with rate_tiers table for tiered rate lookups
**Testing**: RSpec with CSV-driven scenario tests in spec/fixtures/scenarios_input.csv
**Target Platform**: CLI application (Linux/macOS)
**Project Type**: Single-project Ruby CLI application
**Performance Goals**: Sub-second quote generation for typical residential transactions
**Constraints**: All monetary calculations in cents (integers) to avoid floating-point errors; must match published CA rate manuals (TRG and ORT) exactly
**Scale/Scope**: Single state (CA), 2 underwriters (TRG, ORT), 4 lender policy types (standalone Standard/Extended, concurrent Standard/Extended), ~8 file modifications expected

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Initial Check (Pre-Research)

✅ **Principle I (State Isolation)**: Changes isolated to CA calculator (`lib/ratenode/calculators/states/ca.rb`) and CA state rules (`lib/ratenode/state_rules.rb` CA section). No cross-state dependencies introduced.

✅ **Principle II (Contract-First Design)**: CA calculator implements `BaseStateCalculator` contract. Changes to `calculate_lenders_premium` method maintain existing signature.

✅ **Principle III (Prove Before Extracting)**: No new abstractions or shared utilities proposed. All changes are CA-specific implementations.

✅ **Principle IV (Configuration Over Conditionals)**: New underwriter-specific percentages (concurrent_standard_excess_percent_trg, concurrent_standard_excess_percent_ort) will be added to `state_rules.rb` CA section.

⚠️ **Principle V (CSV Scenario Coverage)**: New test scenarios required for concurrent excess and Extended concurrent cases. Human must provide expected values from rate manuals (per constitution, agents cannot self-validate).

✅ **Principle VI (Documentation Accessibility)**: Changes reference specific rate manual sections (TRG CA pages 176-240, ORT CA pages 275-348). Comments will explain calculation logic in plain language.

### Violations / Justifications

None. All changes conform to constitution principles.

### Post-Design Check

**Phase 1 Complete** - Re-evaluation after design artifacts created:

✅ **Principle I (State Isolation)**: Design confirms changes isolated to CA calculator and CA state rules. No cross-state dependencies in data model or contracts.

✅ **Principle II (Contract-First Design)**: `calculate_lenders_premium` contract documented. Method signature unchanged - only internal implementation modified. Maintains BaseStateCalculator interface.

✅ **Principle III (Prove Before Extracting)**: No new abstractions created. All logic remains CA-specific. Future extraction (if 2+ states share lender calculation patterns) would require human direction.

✅ **Principle IV (Configuration Over Conditionals)**: Three new configuration keys added to state_rules.rb CA section (standalone_lender_standard_percent, standalone_lender_extended_percent, concurrent_standard_excess_percent). Underwriter-specific values prevent hardcoded conditionals in calculator.

⚠️ **Principle V (CSV Scenario Coverage)**: Data model identifies 8+ new scenario types required. Contracts document expected inputs/outputs. CSV structure requires 2 new columns (lender_policy_type, is_binder_acquisition). **Human approval required before CSV modification**. Expected values must come from human validation against rate manuals.

✅ **Principle VI (Documentation Accessibility)**: Quickstart.md created with plain-language examples. Rate manual references documented (TRG lines 176-240, ORT lines 252-348). Example calculations show before/after for each bug fix.

**Result**: All constitution principles satisfied. No violations. Ready to proceed to Phase 2 (tasks generation).

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
lib/ratenode/
├── calculators/
│   ├── base_rate.rb                    # Base rate lookup (used by lender calculations)
│   ├── states/
│   │   └── ca.rb                       # ⚠️ MODIFY: Fix 4 lender policy bugs
│   └── base_state_calculator.rb
├── state_rules.rb                       # ⚠️ MODIFY: Add underwriter-specific concurrent percentages
└── models/
    └── policy_type.rb                   # ⚠️ CHECK: May need lender multipliers

spec/
├── fixtures/
│   └── scenarios_input.csv              # ⚠️ MODIFY: Add new test scenarios (human-provided values)
└── calculators/
    └── states/
        └── ca_spec.rb                   # ⚠️ MODIFY: Add unit tests for new logic

docs/rate_manuals/ca/
├── CA_TRG_rate_summary.md               # 📖 REFERENCE: Lines 176-240 (lender policies)
└── CA_ORT_rate_summary.md               # 📖 REFERENCE: Lines 275-348 (lender policies)
```

**Structure Decision**: Single-project Ruby CLI. All changes confined to CA-specific calculator (`lib/ratenode/calculators/states/ca.rb`) and CA state rules configuration. CSV scenario file requires human input for new test cases per Principle V.

## Complexity Tracking

> **No violations - this section left empty per instructions**

N/A - All constitution checks passed without violations.

---

## Implementation Summary

### Phase 0: Research (Complete ✅)

**Output**: `research.md`

All NEEDS CLARIFICATION items resolved:
- Underwriter-specific multipliers documented (TRG: 80%/90%, ORT: 75%/85%)
- Concurrent Standard excess formula clarified (rate difference, not ELC lookup)
- Extended concurrent calculation confirmed (full ELC rate lookup)
- Binder acquisition logic precedence rules established
- Edge cases and error handling strategies defined
- BaseRate API usage pattern identified
- CSV testing strategy with human validation requirements documented

### Phase 1: Design & Contracts (Complete ✅)

**Outputs**:
- `data-model.md` - Entities, fields, validation rules, state transitions, example calculations
- `contracts/calculate_lenders_premium.rb` - Method signature contract with examples
- `contracts/state_rules_ca.rb` - Configuration schema with new keys
- `quickstart.md` - Developer guide with examples and testing strategy
- `CLAUDE.md` updated with new technologies

**Key Design Decisions**:
1. Add 3 new configuration keys per underwriter (TRG/ORT) to state_rules.rb
2. Rewrite calculate_lenders_premium method with 4 distinct code paths:
   - Standalone Standard/Extended (with multipliers)
   - Concurrent Standard (with $150 + excess formula)
   - Concurrent Extended (with full ELC lookup)
3. Add lender_policy_type parameter for coverage type routing
4. Add guard clauses for is_binder_acquisition and include_lenders_policy flags
5. CSV schema requires 2 new columns (human approval needed)

### Phase 2: Tasks Generation (Next Step)

**Command**: `/speckit.tasks`

Will generate `tasks.md` with:
- Dependency-ordered implementation tasks
- Test-first approach per Constitution Principle V
- File modification breakdown
- Acceptance criteria per task
- Estimated complexity ratings

---

## Plan Completion Status

| Phase | Status | Artifacts |
|-------|--------|-----------|
| Phase 0: Research | ✅ Complete | research.md |
| Phase 1: Design & Contracts | ✅ Complete | data-model.md, contracts/, quickstart.md |
| Phase 2: Tasks Generation | ⏸️ Next | Run `/speckit.tasks` |

**Next Action**: Execute `/speckit.tasks` to generate implementation task breakdown.
