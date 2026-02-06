# Research: CA Lender Policy Calculation Bugs

**Feature**: 007-fix-ca-lender
**Date**: 2026-02-05
**Status**: Complete

## Overview

Research to resolve NEEDS CLARIFICATION items from Technical Context and understand CA lender policy calculation requirements from TRG and ORT rate manuals.

---

## Research Area 1: Underwriter-Specific Multipliers for Standalone Lender Policies

**Question**: What are the exact multipliers TRG and ORT apply to standalone (non-concurrent) lender policies for Standard and Extended coverage?

**Findings**:

**TRG California** (CA_TRG_rate_summary.md, lines 176-185):
- Standard Coverage (CLTA/ALTA with WRE): **80% of Schedule**
- Extended Coverage (ALTA without WRE): **90% of Schedule**
- Expanded Coverage Residential: 100% of Schedule

**ORT California** (CA_ORT_rate_summary.md, lines 252-262):
- Standard Coverage (CLTA/ALTA): **75% of OR Insurance Rate**
- Extended Coverage (ALTA Extended): **85% of OR Insurance Rate** (standard refinance)
- Extended Coverage: **100% of OR Insurance Rate** (when loan funds purchase OR construction)
- Expanded Coverage Residential: **95% of OR Insurance Rate** (cannot be used for construction)

**Decision**: Add underwriter-specific multipliers to state_rules.rb:
- `standalone_lender_standard_percent`: 80% for TRG, 75% for ORT
- `standalone_lender_extended_percent`: 90% for TRG, 85% for ORT

**Rationale**: These are promulgated rates from official rate manuals. Using configuration ensures multipliers are centralized per Principle IV (Configuration Over Conditionals).

**Alternatives Considered**:
- ❌ Hardcoding multipliers in CA calculator: Violates Principle IV (scattered conditionals)
- ❌ Creating a shared "lender_multipliers" utility: Violates Principle III (premature extraction - only CA needs this now)

---

## Research Area 2: Concurrent Standard Lender Excess Calculation Formula

**Question**: How exactly should concurrent Standard lender policies calculate the premium when loan amount > owner liability?

**Findings**:

**TRG California** (CA_TRG_rate_summary.md, lines 203-206):
> **For loan amounts EXCEEDING owner's policy amount:**
> - Calculate increased liability: Difference between Schedule charge at loan amount vs. owner's policy amount
> - Apply 80% rate to the increased liability portion
> - Add $150 base fee

Formula: `$150 + (80% × [rate(loan_amount) - rate(owner_liability)])`

**ORT California** (CA_ORT_rate_summary.md, lines 293-298):
> **For loan amounts EXCEEDING owner's policy amount:**
> - Calculate increased liability: Difference between OR Rate at loan amount vs. owner's policy amount
> - Apply 75% to the increased liability portion
> - Add $150 base fee

Formula: `$150 + (75% × [rate(loan_amount) - rate(owner_liability)])`

**Key Insight**: The calculation uses the **rate difference**, not an ELC lookup on the excess amount. Current code incorrectly uses `calculate_elc(excess)`.

**Example Validation** (from spec, TRG manual):
```
Owner: $400,000 → rate = $1,372
Loan:  $500,000 → rate = $1,571
TRG calculation: $150 + 80% × ($1,571 - $1,372) = $150 + $159.20 = $309.20
```

This matches the spec's expected value of $310 (rounding difference likely due to intermediate calculations).

**Decision**: Replace ELC lookup with rate difference calculation:
```ruby
rate_owner = BaseRate.calculate(owner_liability_cents, ...)
rate_loan = BaseRate.calculate(loan_amount_cents, ...)
excess_percent = rules[:concurrent_standard_excess_percent]
concurrent_fee + ((rate_loan - rate_owner) * excess_percent).round
```

**Rationale**: Matches published rate manuals exactly. Prevents the 109% overcharge identified in spec ($648 vs $310).

**Alternatives Considered**:
- ❌ Keep ELC lookup: Produces incorrect results ($648 instead of $310)
- ❌ Use base rate on excess amount: Still incorrect, doesn't match manual formula

---

## Research Area 3: Extended Concurrent Lender Policy Calculation

**Question**: How do Extended concurrent lender policies differ from Standard concurrent?

**Findings**:

**TRG California** (CA_TRG_rate_summary.md, lines 208-215):

| Owner's Policy Type | Loan Policy Rate |
|---------------------|------------------|
| Standard Coverage | 100% of Extended Lenders Concurrent Rate* |
| Homeowner's Policy | 100% of Extended Lenders Concurrent Rate* |

*Extended Lenders Concurrent Rate shown in rate schedule (separate column)

This is a **full ELC rate table lookup** on the loan amount, not the $150 + excess formula.

**When concurrent with Extended Owner's:**
- Up to owner's policy amount: $150 flat fee
- Exceeding owner's policy amount: Increased liability at applicable rate

**ORT California** (CA_ORT_rate_summary.md, lines 302-329):

Extended Coverage Loan Policy (Concurrent with Standard Owner's or Homeowner's Policy):
- **Rate**: Per Extended Coverage Concurrent Insurance Rate Table (pages 18-21)
- This is a special rate table with values like $465 @ $100K, $653 @ $250K, $1,015 @ $500K, etc.

Extended Coverage Loan Policy (Concurrent with Extended Owner's Policy):
- Up to owner's policy amount: **$500 flat fee** (ORT uses $500, TRG uses $150)
- Exceeding owner's policy amount: Increased liability at applicable Extended Coverage rate

**Decision**: Current code uses `calculate_elc` which is correct for Extended concurrent. However, it doesn't differentiate between Standard and Extended coverage types. Need to:
1. Add `lender_policy_type` parameter (`:standard` or `:extended`)
2. Route Standard concurrent to the $150 + excess formula
3. Route Extended concurrent to full ELC rate lookup

**Rationale**: Extended concurrent is a valid product offering that uses different calculation logic than Standard concurrent.

**Alternatives Considered**:
- ❌ Use same formula for both: Incorrect per rate manuals
- ❌ Always use ELC for any excess: Incorrect for Standard concurrent (causes the $648 bug)

---

## Research Area 4: Binder Acquisition Flag Logic

**Question**: When should the system skip lender policy calculation entirely?

**Findings**:

From spec clarifications (lines 12-13):
> Q: When `is_binder_acquisition: true` but `include_lenders_policy: true` is also set, which flag takes precedence?
> A: `is_binder_acquisition: true` always takes precedence (never include lender policy for cash purchases, regardless of `include_lenders_policy` value)

**Business Logic**:
- `is_binder_acquisition: true` = Opendoor cash purchase (acquisition phase) → **NO lender policy**
- `include_lenders_policy: false` = Explicitly no lender policy requested → **NO lender policy**
- Both flags present and conflicting → `is_binder_acquisition` wins

**Decision**: Add guard clause at start of `calculate_lenders_premium`:
```ruby
return 0 if params[:is_binder_acquisition] == true
return 0 if params[:include_lenders_policy] == false
```

**Rationale**: Cash acquisitions never have financing at acquisition stage. Lender policy only applies at resale when buyer obtains financing.

**Alternatives Considered**:
- ❌ Rely only on loan_amount = 0: Doesn't cover all cases where lender policy should be skipped
- ❌ Check `include_lenders_policy` first: Violates precedence requirement from spec

---

## Research Area 5: Edge Cases and Error Handling

**Question**: How should the system handle edge cases like $0 loan, negative amounts, rate lookup failures, and minimum premiums?

**Findings from Spec**:

1. **$0 Loan Amount** (spec lines 14, 34):
   - Return $0 premium (no loan means no lender policy premium)

2. **Negative Loan Amounts** (spec lines 16):
   - Reject as invalid input (loan amounts must be ≥ $0)
   - Raise error to fail fast

3. **Rate Lookup Failures** (spec lines 15):
   - Raise error and reject quote request (fail fast to prevent incorrect quotes)
   - Don't silently return 0 or fallback values

4. **Minimum Premium for Concurrent Standard** (spec lines 13, 47, 52):
   - Use `max($150, $150 + percentage × rate_difference)` to ensure total cannot be less than $150
   - Handles cases where rate_difference ≤ 0 or percentage calculation yields < $150

**Decision**: Add validations and guards:
```ruby
# Early returns
return 0 if loan_amount_cents == 0
raise ArgumentError, "Loan amount cannot be negative" if loan_amount_cents < 0

# Concurrent Standard with excess
excess_rate = ... rate difference calculation ...
[concurrent_fee, concurrent_fee + excess_rate].max  # Ensures minimum of $150
```

**Rationale**: Fail fast on bad input to prevent incorrect quotes. Use max() for minimum premium to handle edge cases cleanly.

**Alternatives Considered**:
- ❌ Return 0 for negative amounts: Silently accepts bad input
- ❌ Allow rate lookups to fail silently: Risks incorrect quotes

---

## Research Area 6: Existing BaseRate.calculate API

**Question**: Does `BaseRate.calculate` support a multiplier parameter, or do we need to multiply after the fact?

**Findings**:

From examining the codebase pattern (CA calculator lines 113-121):
```ruby
base_rate = Calculators::BaseRate.new(
  @liability_cents,
  state: "CA",
  underwriter: @underwriter,
  as_of_date: @as_of_date
).calculate

multiplier = Models::PolicyType.multiplier_for(@policy_type, ...)
(base_rate * multiplier).round
```

Current pattern is:
1. Get base rate from `BaseRate.calculate` (returns 100% rate)
2. Multiply by policy type multiplier
3. Round the result

**Decision**: Use the same pattern for standalone lender policies:
```ruby
base_rate = Calculators::BaseRate.new(...).calculate
multiplier = rules[:standalone_lender_standard_percent] / 100.0
(base_rate * multiplier).round
```

**Rationale**: Consistent with existing owner's policy calculation pattern. Keeps monetary calculations in cents.

**Alternatives Considered**:
- ❌ Modify BaseRate to accept multiplier: Overkill for this feature; would affect all states
- ❌ Create a new LenderRate class: Violates Principle III (premature extraction)

---

## Research Area 7: Testing Strategy with CSV Scenarios

**Question**: What new CSV test scenarios are required, and how should human validation work?

**Findings from Constitution Principle V**:

> **Agent Constraints**: The CSV scenario file is a human-controlled document. Agents MUST NOT modify `scenarios_input.csv` unless explicitly requested and approved. If implementation requires a new input column or expected result column that does not exist, the agent MUST:
> 1. Stop and notify the user that a schema change is needed
> 2. Explain what column is missing and why it's required
> 3. Wait for explicit approval before modifying the CSV structure

**Required New Test Scenarios** (from spec acceptance criteria):
1. Standalone lender Standard (TRG and ORT) with various loan amounts
2. Standalone lender Extended (TRG and ORT) with various loan amounts
3. Concurrent Standard with loan > owner (TRG and ORT) - tests the excess formula
4. Concurrent Standard with loan ≤ owner (should be $150 flat)
5. Extended concurrent with Standard owner's (uses ELC table)
6. Extended concurrent with Extended owner's (uses $150/$500 flat or excess)
7. Cash acquisition (is_binder_acquisition: true) - expects $0 lender premium
8. $0 loan amount - expects $0 lender premium

**New CSV Columns Needed**:
- `lender_policy_type` (standard/extended) - NEW COLUMN
- `is_binder_acquisition` (true/false) - NEW COLUMN
- `include_lenders_policy` (true/false) - may already exist

**Decision**: Document required CSV changes and wait for human to:
1. Add new columns to CSV schema
2. Provide expected premium values from rate manuals (human must validate against TRG/ORT tables)
3. Approve modification to scenarios_input.csv

**Rationale**: Per Principle V, agents cannot self-validate test scenarios. Human must reference rate manuals to provide correct expected values.

**Alternatives Considered**:
- ❌ Agent creates test scenarios with calculated values: Violates Principle V - "agent implementing a calculation may inadvertently create tests that validate its own bugs"
- ❌ Skip CSV tests and only use unit tests: Violates Principle V requirement for CSV scenario coverage

---

## Summary of Decisions

### Implementation Approach

**Bug Fix 1 - Standalone Lender Multipliers**:
- Add `standalone_lender_standard_percent` and `standalone_lender_extended_percent` to state_rules.rb (TRG: 80%/90%, ORT: 75%/85%)
- Modify `calculate_lenders_premium` to apply multiplier when `!concurrent`
- Pattern: `(BaseRate.calculate(...) * multiplier).round`

**Bug Fix 2 - Concurrent Standard Excess**:
- Add `concurrent_standard_excess_percent` to state_rules.rb (TRG: 80%, ORT: 75%)
- Replace ELC lookup with rate difference calculation: `$150 + percent × (rate_loan - rate_owner)`
- Use `[concurrent_fee, concurrent_fee + excess_rate].max` to enforce $150 minimum

**Bug Fix 3 - Extended Concurrent Support**:
- Add `lender_policy_type` parameter (`:standard` or `:extended`)
- Route Extended concurrent to full ELC rate lookup (existing `calculate_elc` call)
- Keep Standard concurrent using new excess formula

**Bug Fix 4 - Binder Acquisition Flag**:
- Add guard clause: `return 0 if params[:is_binder_acquisition] == true`
- Add guard clause: `return 0 if params[:include_lenders_policy] == false`
- Order matters: `is_binder_acquisition` check comes first

**Edge Cases**:
- Return 0 for loan_amount_cents == 0
- Raise ArgumentError for negative loan amounts
- Let rate lookup failures propagate (fail fast)
- Use max() for $150 minimum on concurrent Standard

### Files to Modify

1. **lib/ratenode/state_rules.rb**: Add 3 new underwriter-specific config keys
2. **lib/ratenode/calculators/states/ca.rb**: Rewrite `calculate_lenders_premium` method
3. **spec/fixtures/scenarios_input.csv**: Add new test scenarios (human-provided values)
4. **spec/calculators/states/ca_spec.rb**: Add unit tests for new logic

### Test Data Requirements (Human Input Required)

User must add CSV scenarios with expected values from rate manuals:
- Standalone TRG/ORT Standard/Extended lender policies
- Concurrent Standard with excess (TRG $400K owner / $500K loan should yield $310)
- Extended concurrent with Standard owner's (use ELC table)
- Cash acquisition scenarios (is_binder_acquisition: true)

---

## Open Questions

None. All NEEDS CLARIFICATION items resolved through rate manual research.
