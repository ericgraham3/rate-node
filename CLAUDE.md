# rate-node Development Guidelines

**Project Constitution**: See `.specify/memory/constitution.md` for architectural principles, state isolation rules, and quality gates.

## Technology Stack

- **Language**: Ruby 3.4.8
- **Database**: SQLite with Sequel ORM
- **CLI**: Thor (`bin/ratenode`)
- **Testing**: RSpec with CSV-driven scenario tests
- **Rate Storage**: Seed files in `db/seeds/data/{state}_rates.rb`
- **State Rules**: Centralized configuration in `lib/ratenode/state_rules.rb`

## Project Structure

```
lib/ratenode/
  calculators/
    states/          # One calculator per state (CA.rb, TX.rb, etc.)
    lenders_policy.rb
  models/            # Sequel models (RateTier, Endorsement, etc.)
  state_rules.rb     # Centralized state configuration
db/seeds/data/       # Rate tier seed files per state/underwriter
spec/
  fixtures/
    scenarios_input.csv  # ⚠️ HUMAN-CONTROLLED (see below)
```

## Critical Rules

### ⚠️ CSV Scenario File Protection

**`spec/fixtures/scenarios_input.csv` is HUMAN-CONTROLLED and MUST NOT be modified by agents unless explicitly requested and approved by a human.**

This file contains test scenarios validated against official rate manuals. Constitution Principle V states:

> Agents MUST NOT modify scenarios_input.csv unless explicitly requested and approved. If implementation requires a new input column or expected result column that does not exist, the agent MUST:
> 1. Stop and notify the user that a schema change is needed
> 2. Explain what column is missing and why it's required
> 3. Wait for explicit approval before modifying the CSV structure

**Rationale**: An agent implementing a calculation may inadvertently create tests that validate its own bugs. Test values MUST come from humans referencing rate manuals.

This rule applies to ALL agents, not just speckit workflows.

### State Isolation (Constitution Principle I)

Each state calculator is fully isolated. Changes to one state MUST NOT affect another state's behavior. Agents MUST NOT:
- Create cross-state dependencies or shared base classes
- Import, inherit from, or call another state's implementation
- Extract shared code without explicit human direction

See constitution for full details and extraction criteria.

## Key Architectural Patterns

### Formula Parameters in state_rules.rb

Over-threshold formulas (e.g., over-$3M, over-$10M) are configured as underwriter-specific parameters in `state_rules.rb` rather than hardcoded constants. Access via:

```ruby
RateNode.rules_for(state, underwriter:)
```

Parameters follow naming convention: `{formula}_base_cents` and `{formula}_per_{unit}_cents`.

### Minimum Premium

Minimum premium is enforced in both `BaseRate.calculate` (via `apply_minimum_premium`) and in state calculators before policy-type multipliers. The `minimum_premium_cents` value is per-underwriter in `state_rules.rb`.

### CA Over-$3M Formula Pattern

Formula: `base + (ceil(excess / increment_size) * rate_per_increment)`

Used for:
- Owner premiums >$3M
- ELC (Extended Lender Concurrent) >$3M
- Refinance >$10M

All use `state_rules` lookup for underwriter-specific parameters.

### Multi-Underwriter States

States with multiple underwriters (AZ, CA) use separate seed modules:
- `ca_rates.rb` (TRG underwriter)
- `ca_ort_rates.rb` (ORT underwriter)

### Hold-Open/Binder Pattern

- **Initial**: Base rate + surcharge
- **Final**: Incremental (new liability - prior liability)
- **CA**: 10% surcharge on base rate (not multiplied rate)
- **AZ**: 25% surcharge on full premium

### Rate Tier Seeding

Each `db/seeds/data/{state}_rates.rb` file MUST declare:

```ruby
RATE_TIERS_UNIT = :dollars  # or :cents
```

This tells the seeder how to interpret the rate values in the file.

## Calculator Pipeline

- **Owner's Premium**: Calculated by state calculator (e.g., `States::CA`)
- **Lender's Premium**: Routed through `Calculators::LendersPolicy` (NOT state calculator's `calculate_lenders_premium`)
- **Pipeline**: `Calculator` → `LendersPolicy` → state calculator

Always pass `lender_policy_type` through the full pipeline.

## Common Pitfalls

1. **Lender Policy Type**: Always pass `lender_policy_type` through `Calculator` → `LendersPolicy` pipeline
2. **Hold-Open Flag**: `is_hold_open` must be passed to Calculator for all states (not just AZ)
3. **Endorsements**: Underwriter-specific (e.g., ORT ALTA 8.1 = $25, TRG = no_charge)
4. **ORT ELC Column**: ORT rate data needs ELC (Extended Lender Concurrent) column populated for concurrent scenarios
5. **Floating Point**: Always `.round` results of multiplication with Float percentages
6. **Over-Threshold Guards**: Use state-specific guards (e.g., `state == "CA"` not `state != "TX"`)
7. **Boundary Conditions**: Use `>` not `>=` for $3M and $10M thresholds (tier at boundary, formula above)
8. **Refinance Formulas**: `RefinanceRate` has its own over-$10M formula separate from `rate_tier.rb` over-$3M

## Testing

- **CSV Scenarios**: `bundle exec rspec` runs all CSV-driven scenarios
- **Tolerance**: $2.00 difference allowed for rounding discrepancies
- **Round-Up Effect**: `round_up_to_dollar` rounds grand total to next dollar (can cause ~$1 diff from expected)

## Quality Gates (from Constitution)

Before merging any PR:
- [ ] All CSV scenario tests pass
- [ ] New states have minimum 4 scenario test cases
- [ ] State-specific logic is isolated (no cross-state conditionals)
- [ ] Rate calculations match published rate manuals exactly

## Adding a New State

1. Add entry to `STATE_RULES` in `lib/ratenode/state_rules.rb`
2. Create `db/seeds/data/{state}_rates.rb` with rate tiers and endorsements
3. Create `lib/ratenode/calculators/states/{state}.rb` implementing `BaseStateCalculator`
4. **(Human task)** Add test scenarios to `spec/fixtures/scenarios_input.csv`

Step 4 is human-only per Constitution Principle V.

## Getting Help

- `/help` - Get help with using Claude Code
- Feedback/Issues: https://github.com/anthropics/claude-code/issues
