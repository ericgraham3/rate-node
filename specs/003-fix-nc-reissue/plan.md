# Implementation Plan: Fix NC Reissue Discount Calculation

**Branch**: `003-fix-nc-reissue` | **Date**: 2026-02-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-fix-nc-reissue/spec.md`

## Summary

Fix the NC reissue discount calculation which currently uses a linear proportional approximation instead of the actual tiered rate on the discountable portion. The correction requires calling `RateTier.calculate_rate()` for the discountable portion (MIN of liability, prior policy amount) rather than scaling the full premium proportionally.

## Technical Context

**Language/Version**: Ruby 3.4.8
**Primary Dependencies**: sqlite3 ~> 1.6, thor ~> 1.3, csv (stdlib)
**Storage**: SQLite with `rate_tiers` table for tiered rate lookups
**Testing**: RSpec ~> 3.12 with CSV-driven scenario tests (`spec/fixtures/scenarios_input.csv`)
**Target Platform**: Linux CLI
**Project Type**: Single Ruby application
**Performance Goals**: N/A (batch CLI tool, not latency-sensitive)
**Constraints**: Must match NC rate manual exactly; no cross-state dependencies per constitution
**Scale/Scope**: Single-state calculator fix; affects `lib/ratenode/calculators/states/nc.rb`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check (Phase 0)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. State Isolation | ✅ PASS | Change is isolated to `nc.rb`; no cross-state dependencies |
| II. Contract-First Design | ✅ PASS | Uses existing `BaseStateCalculator` contract; no interface changes |
| III. Prove Before Extracting | ✅ PASS | Uses existing `RateTier.calculate_rate()` utility; no new abstractions |
| IV. Configuration Over Conditionals | ✅ PASS | Discount % already in `state_rules.rb`; no new scattered conditionals |
| V. CSV Scenario Coverage | ⚠️ HUMAN REQUIRED | New test values for partial-reissue scenarios require human verification |
| VI. Documentation Accessibility | ✅ PASS | Logic will reference rate manual section |

**Pre-Design Gate Status**: PASS (Principle V constraint noted — human must provide expected values)

### Post-Design Check (Phase 1)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. State Isolation | ✅ PASS | Design uses only `nc.rb`; calls existing `RateTier.calculate_rate()` with NC params |
| II. Contract-First Design | ✅ PASS | No interface changes; existing contracts documented in `contracts/README.md` |
| III. Prove Before Extracting | ✅ PASS | No new abstractions; reuses `RateTier.calculate_rate()` and `PolicyType.multiplier_for()` |
| IV. Configuration Over Conditionals | ✅ PASS | Discount percentage and eligibility years remain in `state_rules.rb` |
| V. CSV Scenario Coverage | ⚠️ HUMAN REQUIRED | Spec example ($400k/$250k) documented; human must add CSV row with verified expected values |
| VI. Documentation Accessibility | ✅ PASS | `research.md` includes worked example; `data-model.md` has calculation flow diagram |

**Post-Design Gate Status**: PASS — Ready for task generation

## Project Structure

### Documentation (this feature)

```text
specs/003-fix-nc-reissue/
├── plan.md              # This file
├── research.md          # Phase 0: Bug analysis and correct formula
├── data-model.md        # Phase 1: Reissue discount calculation model
├── quickstart.md        # Phase 1: Implementation checklist
├── contracts/           # Phase 1: N/A (no new APIs)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
lib/ratenode/
├── calculators/
│   ├── states/
│   │   └── nc.rb                # TARGET: Fix calculate_reissue_discount()
│   └── base_rate.rb             # Existing: Calls RateTier.calculate_rate()
├── models/
│   └── rate_tier.rb             # Existing: calculate_rate(), calculate_tiered_rate()
└── state_rules.rb               # Existing: NC reissue_discount_percent (0.50)

spec/
└── fixtures/
    └── scenarios_input.csv      # HUMAN TASK: Add partial-reissue test scenarios
```

**Structure Decision**: Single project layout (already established). No structural changes required.

## Complexity Tracking

> No constitution violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
