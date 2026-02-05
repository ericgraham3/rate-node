# Implementation Plan: Fix FL Rate Calculator Discrepancies

**Branch**: `002-fix-fl-rates` | **Date**: 2026-02-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-fix-fl-rates/spec.md`

## Summary

Three targeted corrections to the Florida rate calculator: (1) ALTA 6 and 6.2 endorsements change from `no_charge` to flat $25.00; (2) ALTA 9.3 changes from `no_charge` to 10%-of-combined-premium with $25 minimum, and ALTA 9.1/9.2 are added as owner endorsements with the same pricing; (3) the reissue eligibility boundary operator in `fl.rb` changes from `<=` to `<`. All changes are configuration-level or single-operator fixes within FL-isolated files. No new abstractions, no cross-state impact.

## Technical Context

**Language/Version**: Ruby 3.4.8
**Primary Dependencies**: thor ~> 1.3, sqlite3 ~> 1.6, csv (stdlib)
**Storage**: SQLite — endorsement rows are seeded from `db/seeds/data/fl_rates.rb` via `Models::Endorsement.seed`; reissue logic lives in the FL calculator
**Testing**: RSpec ~> 3.12; sole test authority is `spec/integration/csv_scenarios_spec.rb` driven by `spec/fixtures/scenarios_input.csv`
**Target Platform**: Linux (CLI tool)
**Project Type**: Single project
**Performance Goals**: N/A — rate lookup, not high-throughput
**Constraints**: All monetary values in cents (integers). CSV scenario suite must pass without modification (Principle V). No agent modifications to `scenarios_input.csv`.
**Scale/Scope**: 3 endorsement-definition edits, 2 endorsement-definition additions, 1 operator change in one method

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I — State Isolation | PASS | All changes are within `fl_rates.rb` (seed data) and `fl.rb` (calculator). No other state file touched. |
| II — Contract-First | PASS | FL already implements `BaseStateCalculator`. No interface change required. |
| III — Prove Before Extracting | PASS | No extraction. ALTA 9.1/9.2 use the same `percentage_combined` pricing_type already in the endorsement model — this is configuration, not a new abstraction. |
| IV — Configuration Over Conditionals | PASS | Endorsement fixes are seed-data edits. Reissue boundary is a single operator in the FL calculator's private method — no new conditional added. |
| V — CSV Scenario Coverage | PASS | Existing scenarios must continue to pass. New edge-case rows are out of scope and human-authored per constitution. Agent does NOT modify `scenarios_input.csv`. |
| VI — Documentation Accessibility | PASS | Plan and research artifacts are plain-language. |

**Gate result: All principles satisfied. Proceed.**

## Project Structure

### Documentation (this feature)

```text
specs/002-fix-fl-rates/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A for this feature — see research.md)
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
src/                         # (unused — legacy placeholder)

lib/ratenode/
├── calculators/
│   └── states/
│       └── fl.rb            # ← CHANGE: operator fix in eligible_for_reissue_rates?
├── models/
│   └── endorsement.rb       # (read-only — pricing logic already supports all needed types)
└── state_rules.rb           # (read-only — FL config unchanged)

db/seeds/data/
└── fl_rates.rb              # ← CHANGE: ALTA 6/6.2 pricing, ALTA 9.3 pricing, add ALTA 9.1/9.2

spec/
├── fixtures/
│   └── scenarios_input.csv  # (read-only — human-controlled per Principle V)
└── integration/
    └── csv_scenarios_spec.rb # (read-only — drives all scenario validation)
```

**Structure Decision**: Single-project layout. Only two files require edits: `db/seeds/data/fl_rates.rb` and `lib/ratenode/calculators/states/fl.rb`. Both are FL-isolated.

## Complexity Tracking

No constitution violations. Section intentionally left empty.
