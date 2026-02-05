# Research: NC Simultaneous Issue Base Premium (PR-4)

## 1. Rate-Manual Rule: PR-4

**Decision**: The base premium for an NC simultaneous issue transaction is computed on `max(owner_coverage, loan_coverage)`. The owner's `liability_cents` output remains the actual owner coverage.

**Rationale**: PR-4 of the NC rate manual states that a single base premium is charged on the higher of the two coverages. This prevents under-billing when the Loan Policy coverage exceeds the Owner's Policy coverage. The NC rate manual uses "simultaneous issue" to describe what the codebase calls a "concurrent" purchase (an Owner's Policy and a Loan Policy issued together).

**Alternatives considered**: Computing two separate base premiums (one per policy) and summing them — rejected because PR-4 explicitly mandates a single base premium. Adjusting the Loan Policy charge instead of the Owner's base — rejected because the $28.50 concurrent flat fee is a separate line item governed by a different rule and must remain unchanged.

---

## 2. Manual Tier Verification

All expected values for the new test scenario are derived independently from PR-2 tiers, not from PR-4 illustrative examples (which contain known errors per the spec's assumptions).

### PR-2 Tier Table (NC, effective 2025-10-01)

| Bracket | Per-Thousand Rate |
|---------|-------------------|
| $0 – $100,000 | $2.78 |
| $100,001 – $500,000 | $2.17 |
| $500,001 – $2,000,000 | $1.41 |
| $2,000,001 – $7,000,000 | $1.08 |
| $7,000,001+ | $0.75 |

### Verification: Owner $300,000 / Loan $350,000

1. **Rounding**: NC rounds liability UP to the nearest $1,000. Both $300,000 and $350,000 are already on $1,000 boundaries — no rounding applies.
2. **PR-4 input**: `max(300_000, 350_000) = 350_000`. Base premium is computed on $350,000.
3. **Tier calculation on $350,000**:
   - Tier 1: $100,000 × $2.78 / $1,000 = **$278.00**
   - Tier 2: $250,000 × $2.17 / $1,000 = **$542.50**
   - Sum = **$820.50**
4. **Policy type multiplier**: Standard = 1.00. Premium = $820.50 × 1.00 = **$820.50**
5. **Minimum premium check**: NC minimum is $56.00. $820.50 > $56.00 — no adjustment.
6. **Lender concurrent fee**: $28.50 (flat, unchanged by PR-4).
7. **Combined total**: $820.50 + $28.50 = **$849.00**

All values match the spec's acceptance scenario.

### Regression check: Owner $500,000 / Loan $400,000 (existing test)

`max(500_000, 400_000) = 500_000` — owner wins. Base premium input is unchanged from current behaviour. Existing test expected value of $1,146.00 remains correct.

---

## 3. Reissue Discount Interaction

**Decision**: The reissue discount continues to operate on `@liability_cents` (the owner's actual coverage), not on the PR-4-adjusted premium input.

**Rationale**: The reissue discount represents a credit for prior insurance on the *owner's* property. The PR-4 max rule inflates the base premium input to account for the loan coverage, but it does not change what the owner actually insures. Applying the discount to the inflated input would over-credit. The existing `calculate_reissue_discount` method already uses `@liability_cents` for `discountable_portion_cents` — no change is needed.

**Risk**: None. The reissue discount path is exercised by the existing `NC_purchase_loan_reissue` scenario (Owner $500k, Loan $400k, Prior $200k). In that case loan < owner, so the PR-4 max does not change the base input, and the discount calculation is identical to current behaviour.

---

## 4. Data-Flow Design

**Decision**: Pass `loan_amount_cents` unconditionally in the params hash from `Calculator#calculate_owners_policy` when `include_lenders_policy` is true. The NC calculator reads it; all other state calculators ignore unknown keys.

**Rationale**: Adding a state-conditional in the orchestrator (`if state == "NC"`) would scatter state logic outside the state calculator, violating Constitution Principle IV. Ruby hashes accept extra keys silently — existing state calculators (CA, TX, FL, AZ) do not destructure params strictly, so the extra key is invisible to them. This satisfies FR-004 (no behavioural change to other states) without polluting the orchestrator with state checks.

**Alternatives considered**: Passing the key only for NC via a conditional — rejected (Principle IV). Adding a new method to `BaseStateCalculator` — rejected (unnecessary interface change for a single-state rule). Passing the key only when loan > owner — rejected (the calculator should make that comparison itself; the orchestrator should not know about PR-4).
