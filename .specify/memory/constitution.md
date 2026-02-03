<!--
Sync Impact Report
==================
Version change: 1.5.0 → 1.6.0
Modified principles:
  - Principle I (State Isolation): Added agent constraints prohibiting cross-state
    dependencies, shared base classes, or unified implementations without human direction.
Added sections: None
Removed sections: None
Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ compatible (Constitution Check section exists)
  - .specify/templates/spec-template.md: ✅ compatible (no constitution-specific sections)
  - .specify/templates/tasks-template.md: ✅ compatible (test-first pattern aligns with Principle V)
Follow-up TODOs: None
-->

# RateNode Constitution

## Core Principles

### I. State Isolation

Each state calculator is fully isolated. Changes to one state's implementation MUST NOT affect another state's behavior. Even if two states appear similar, they maintain separate implementations until shared patterns are proven across 2+ states AND a human explicitly directs unification.

**Agent Constraints**: Agents MUST NOT create cross-state dependencies, shared base classes, or unified implementations without explicit human direction. When implementing a feature that exists in another state, agents MUST:
1. Implement it independently in the target state's calculator
2. Not import, inherit from, or call another state's implementation
3. Report observed similarities for human review (do not act on them)

**Rationale**: Title insurance rates are state-regulated with genuinely different calculation logic—not just different parameters. Over-abstracting fights the domain. A bug fix to FL logic MUST NOT be able to accidentally change TX behavior.

### II. Contract-First Design

All state calculators MUST implement a shared contract (`BaseStateCalculator`). The contract defines the interface; implementations own their logic. This standardizes the boundary while liberating the implementation details.

**Rationale**: A consistent interface enables the factory pattern (`StateCalculator.for("AZ", ...)`) and ensures all states provide the same capabilities (owners premium, lenders premium, endorsements, CPL) without dictating how they compute those values.

### III. Prove Before Extracting

Shared utilities and abstractions are only extracted after patterns prove themselves across multiple states (minimum 2) AND a human explicitly directs the extraction. Premature abstraction is explicitly forbidden. Three similar lines of code is acceptable; a premature abstraction is not.

**Permitted Utilities** (pre-approved for extraction to `lib/ratenode/utilities/`):
- Mathematical operations: rounding functions, cent/dollar conversions
- Generic algorithms: tier lookup traversal, bracket calculations

**Forbidden Without Explicit Direction** (even if 2+ states share them):
- Domain-specific patterns: hold-open logic, reissue calculations, endorsement pricing
- State calculation workflows: even if CA and AZ both have similar hold-open, they remain separate until a human decides to unify them

**Agent Constraints**: Agents MUST NOT extract shared code or create abstractions on their own initiative. If an agent observes a pattern across states, it MUST:
1. Complete the current task using state-specific code
2. Note the potential pattern in a comment or report
3. Wait for explicit human direction before any extraction

**Rationale**: Each state's rate manual has subtle differences. What looks like duplication often hides state-specific edge cases. Extracting too early creates rigid abstractions that fight future state additions. The 2+ state criterion is necessary but not sufficient—human judgment determines when extraction is worth the coupling cost.

### IV. Configuration Over Scattered Conditionals

State-specific rules belong in `state_rules.rb`, not scattered across calculators as case statements. When adding state-specific behavior, prefer configuration-driven approaches.

**Rationale**: Centralizing state configuration in one place makes it easy to see all rules for a state at a glance, simplifies adding new states, and prevents "find all the places TX is mentioned" archaeology.

### V. CSV Scenario Coverage

Every state MUST have CSV scenario test coverage in `spec/fixtures/scenarios_input.csv`. These tests are the safety net for refactors. No structural changes ship without passing scenario tests.

**Agent Constraints**: The CSV scenario file is a human-controlled document. Agents MUST NOT modify `scenarios_input.csv` unless explicitly requested and approved. If implementation requires a new input column or expected result column that does not exist, the agent MUST:
1. Stop and notify the user that a schema change is needed
2. Explain what column is missing and why it's required
3. Wait for explicit approval before modifying the CSV structure

**Rationale**: Real-world rate calculations have many edge cases. CSV-driven tests allow domain experts to contribute test cases without writing Ruby. The test suite currently covers 32+ scenarios across 5 states. Protecting the CSV from unilateral agent changes ensures SMEs retain control over test data.

### VI. Documentation Accessibility

Documentation MUST be written to enable non-technical subject matter experts (SMEs) to understand, verify, and contribute to the project. Rate manuals, calculation logic, and test scenarios MUST be documented in plain language.

**Rationale**: The people who best understand title insurance rates are often not software engineers. They read rate manuals, interpret regulatory guidance, and can validate calculation correctness—but only if the documentation meets them where they are.

## Technical Standards

**Language/Framework**: Ruby with RSpec for testing
**Database**: SQLite with Sequel ORM for rate tier lookups
**Rate Storage**: Centralized seed data in `db/seeds/data/{state}_rates.rb`
**State Rules**: Centralized in `lib/ratenode/state_rules.rb`
**CLI**: Thor-based command interface (`bin/ratenode`)

**Monetary Values**: All amounts stored and calculated in cents (integers) to avoid floating-point errors. Conversion to dollars happens only at display boundaries.

**One Calculator Per State (Required)**:
Each state MUST have its own dedicated calculator file at `lib/ratenode/calculators/states/{state}.rb`. Multi-state calculators with internal case statements are explicitly forbidden. This ensures:
- A change to FL logic cannot syntactically affect TX code
- Each state can be "locked in" once validated against its rate manual
- New states don't risk destabilizing existing implementations

Even if two states have identical logic today, they get separate files. Shared code is extracted to utilities only after Principle III criteria are met.

**File Conventions for New States**:
1. Add entry to `STATE_RULES` in `lib/ratenode/state_rules.rb`
2. Create `db/seeds/data/{state}_rates.rb` with rate tiers and endorsements
3. Create `lib/ratenode/calculators/states/{state}.rb` implementing `BaseStateCalculator`
4. *(Human task)* Add test scenarios to `spec/fixtures/scenarios_input.csv`

**Why Step 4 is Human-Only**: Agents MUST NOT create test scenarios with input values and expected results. An agent implementing a calculation may inadvertently create tests that validate its own bugs—the test "passes" but both the code and test are wrong. Agents MAY propose scenario types to test (e.g., "we should test hold-open with liability increase"), but actual values MUST come from humans referencing rate manuals. See Principle V for CSV agent constraints.

## Quality Gates

**Before Merging Any PR**:
- [ ] All CSV scenario tests pass (`bundle exec rspec`)
- [ ] New states have minimum 4 scenario test cases
- [ ] State-specific logic is isolated (no cross-state conditionals added)
- [ ] Rate calculations match published/promulgated rate manuals exactly

**Before Extracting Shared Code** (per Principle III):
- [ ] Human has explicitly directed the extraction (agents MUST NOT self-initiate)
- [ ] Extraction is either a permitted utility (rounding, tier lookup) OR has explicit approval for domain logic
- [ ] Pattern exists in 2+ state implementations (necessary but not sufficient)
- [ ] Extraction does not introduce cross-state dependencies
- [ ] Original state tests still pass after extraction

**For Non-Technical Contributions**:
- [ ] README documents how to add test scenarios via CSV
- [ ] Rate calculation logic is documented in comments referencing rate manual sections
- [ ] Discrepancies from expected rates include clear error messages

## Governance

This constitution supersedes ad-hoc practices. All PRs and code reviews MUST verify compliance with these principles.

**Amendment Process**:
1. Propose changes via PR to this file
2. Document rationale for the change
3. Update version number following semantic versioning:
   - MAJOR: Principle removal or fundamental redefinition
   - MINOR: New principle added or existing principle materially expanded
   - PATCH: Clarifications, typo fixes, non-semantic refinements
4. Update `LAST_AMENDED_DATE` to the merge date

**Compliance Review**: When reviewing PRs, explicitly check:
- Does this change isolate state logic appropriately? (Principle I)
- Does this follow the contract interface? (Principle II)
- Is any abstraction being extracted prematurely? (Principle III)
- Are state-specific rules in `state_rules.rb`? (Principle IV)
- Are CSV scenarios updated for affected states? (Principle V)
- Can a non-technical SME understand the change? (Principle VI)

**Version**: 1.6.0 | **Ratified**: 2026-02-03 | **Last Amended**: 2026-02-03
