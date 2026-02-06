# Implementation Plan: Fix CA Over-$3M Formulas and Minimum Premium

**Branch**: `008-fix-ca-3m-formulas` | **Date**: 2026-02-05 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-fix-ca-3m-formulas/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implements accurate premium calculation formulas for California properties valued over $3 million, including underwriter-specific (TRG and ORT) over-$3M owner premiums, Extended Lender Concurrent (ELC) rates, minimum premium enforcement, and progressive refinance rates above $10M. All formula parameters will be centralized in state_rules.rb configuration to enable underwriter-specific rate lookups at runtime.

## Technical Context

**Language/Version**: Ruby 3.4.8
**Primary Dependencies**: thor ~> 1.3 (CLI), sqlite3 ~> 1.6 (database), sequel (ORM), rspec ~> 3.12 (testing)
**Storage**: SQLite database with rate_tiers table for tiered rate lookups; endorsements also seeded in database
**Testing**: RSpec for unit tests; CSV-driven scenario tests in spec/integration/csv_scenarios_spec.rb
**Target Platform**: Linux/macOS CLI application
**Project Type**: Single project (CLI calculator)
**Performance Goals**: N/A (calculation accuracy is priority, not performance)
**Constraints**: Must maintain backward compatibility with existing calculation pipeline; no database schema changes; configuration changes limited to state_rules.rb; CSV test tolerance of $2.00 for rounding differences
**Scale/Scope**: 5 state calculators (AZ, CA, FL, NC, TX); 32+ CSV scenario tests; California has 2 underwriters (TRG, ORT) with separate rate schedules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: State Isolation ✅
- Changes are isolated to CA calculator (`lib/ratenode/calculators/states/ca.rb`) and CA-specific configuration in state_rules.rb
- No cross-state dependencies introduced
- Other states (AZ, FL, NC) remain untouched

### Principle II: Contract-First Design ✅
- CA calculator already implements BaseStateCalculator contract
- No contract modifications needed
- Feature operates entirely within existing interface

### Principle III: Prove Before Extracting ✅
- No shared code extraction planned
- Formula calculation logic remains CA-specific
- Underwriter-specific parameters stored in state_rules.rb per established pattern

### Principle IV: Configuration Over Scattered Conditionals ✅
- All underwriter-specific formula parameters moved to state_rules.rb
- Removes hardcoded TRG-only constants from rate_tier.rb
- Centralizes CA configuration: minimum_premium_cents, over_3m formulas, ELC formulas, refinance formulas

### Principle V: CSV Scenario Coverage ✅
- Existing CSV scenarios must continue passing (SC-005)
- No CSV schema modifications planned
- Tests verify calculations within $2.00 tolerance

### Principle VI: Documentation Accessibility ✅
- Rate manual references documented in docs/rate_manuals/ca/
- Formula parameters named clearly (over_3m_base_cents, over_3m_per_10k_cents)
- Comments will reference rate manual sections for verification

**GATE STATUS**: ✅ PASS - No violations. All changes follow constitutional principles.

---

## Constitution Check (Post-Design Re-Evaluation)

*Re-evaluated after Phase 1 design artifacts (research.md, data-model.md, contracts/)*

### Principle I: State Isolation ✅
- **Design Review**: All formula parameters scoped to CA state in state_rules.rb
- **No cross-state leakage**: Other states' calculations unaffected (AZ, FL, NC, TX)
- **Isolation verified**: Changes contained to CA calculator, rate_tier.rb only processes CA when state=="CA"

### Principle II: Contract-First Design ✅
- **Contract documented**: API contract in contracts/calculation_api.md defines all method signatures
- **Interface preserved**: Public API unchanged (calculate_owners_premium, calculate_lenders_premium)
- **Internal changes isolated**: Modified methods maintain expected input/output contracts

### Principle III: Prove Before Extracting ✅
- **No premature abstraction**: Formula logic stays in rate_tier.rb methods (not extracted)
- **State-specific config**: Parameters in state_rules.rb per established pattern
- **Pattern proven**: Underwriter-specific config already used for hold-open, multipliers (from 007-fix-ca-lender)

### Principle IV: Configuration Over Scattered Conditionals ✅
- **Centralized config**: All 7 formula parameters per underwriter in state_rules.rb
- **No new case statements**: Runtime lookup via rules_for(state, underwriter:)
- **Consistent pattern**: Matches existing concurrent_base_fee_cents, policy_type_multipliers structure

### Principle V: CSV Scenario Coverage ✅
- **No CSV modifications planned**: Existing columns support all test scenarios
- **Test coverage expanded**: Added test cases for over-$3M, ELC, minimum premium, refinance
- **Tolerance preserved**: $2.00 tolerance maintained per existing pattern

### Principle VI: Documentation Accessibility ✅
- **Plain language docs**: quickstart.md provides step-by-step implementation guide
- **Rate manual references**: Formula parameters linked to source manual sections
- **SME-friendly**: Configuration parameters clearly named (over_3m_base_cents, not obscure abbreviations)

**POST-DESIGN GATE STATUS**: ✅ PASS - Design artifacts confirm no constitutional violations. Ready for implementation.

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
│   ├── states/
│   │   └── ca.rb                    # CA calculator - owner premium logic modifications
│   ├── lenders_policy.rb            # No changes (lender logic already correct from 007)
│   └── base_rate.rb                 # May need underwriter parameter passthrough
├── models/
│   └── rate_tier.rb                 # Formula methods for over-$3M and refinance >$10M
├── state_rules.rb                   # Add underwriter-specific formula parameters
└── utilities/
    └── rounding.rb                  # Existing - no changes expected

db/seeds/
└── data/
    ├── ca_rates.rb                  # TRG rate tiers - verify completeness
    └── ca_ort_rates.rb              # ORT rate tiers - verify completeness

spec/
├── calculators/
│   └── states/
│       └── ca_spec.rb               # Unit tests for CA calculator
├── integration/
│   └── csv_scenarios_spec.rb        # CSV-driven tests - must continue passing
└── fixtures/
    └── scenarios_input.csv          # Test data - no modifications planned

docs/rate_manuals/ca/
├── CA_TRG_rate_summary.md          # Reference for TRG formulas
└── CA_ORT_rate_summary.md          # Reference for ORT formulas
```

**Structure Decision**: Single project CLI application. Changes concentrated in:
- **Configuration**: state_rules.rb (add formula parameters)
- **Calculation Logic**: ca.rb calculator (owner premium with minimum floor) + rate_tier.rb (over-$3M and refinance formulas)
- **Testing**: ca_spec.rb unit tests verify formulas; csv_scenarios_spec.rb ensures no regressions

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - this section is not applicable.

---

## Implementation Summary

### Phase 0: Research (✅ COMPLETED)

**Output**: `research.md`

All unknowns resolved:
- TRG ELC formula confirmed: $2,472 base + $4.20 per $10K
- Minimum premium application order: before multipliers/surcharges
- Boundary conditions: Use tier at exactly $3M/$10M, formula for amounts strictly greater
- Refinance approach: Tier lookup ≤$10M, runtime formula >$10M
- Formula storage: state_rules.rb with underwriter-specific sections

### Phase 1: Design & Contracts (✅ COMPLETED)

**Outputs**:
- `data-model.md` - Configuration structure and calculation formulas
- `contracts/calculation_api.md` - Method signatures and API contracts
- `quickstart.md` - Implementation guide
- Agent context updated in `CLAUDE.md`

**Design Decisions**:
- 7 formula parameters per underwriter (TRG, ORT)
- No database schema changes
- Minimum enforcement in CA calculator's `calculate_standard`
- Underwriter parameter passed through BaseRate → RateTier pipeline
- Boundary conditions: `>` not `>=` for $3M and $10M thresholds

### Phase 2: Task Generation (NEXT STEP)

Use `/speckit.tasks` command to generate actionable, dependency-ordered tasks.md from this plan.

---

## Files Generated

```
specs/008-fix-ca-3m-formulas/
├── spec.md              # Feature specification (user-provided)
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0: Research findings
├── data-model.md        # Phase 1: Configuration structure and formulas
├── quickstart.md        # Phase 1: Implementation guide
└── contracts/
    └── calculation_api.md  # Phase 1: Method signatures and contracts
```

---

## Implementation Readiness

**Ready for Task Generation**: ✅

All prerequisites met:
- [x] Feature spec clarified and complete
- [x] Research findings consolidated
- [x] Data model defined (configuration parameters)
- [x] API contracts documented
- [x] Implementation guide written
- [x] Constitution check passed (pre- and post-design)
- [x] Agent context updated
- [x] No blocking unknowns remain

**Next Action**: Run `/speckit.tasks` to generate tasks.md with implementation steps.

