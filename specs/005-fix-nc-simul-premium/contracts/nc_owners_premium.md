# Contract: NC Owner's Premium Calculation (post PR-4)

This document defines the input/output contract for `States::NC#calculate_owners_premium` after the PR-4 fix. It is the authoritative interface specification for the NC calculator's owner's premium path.

---

## Input (params hash)

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `:liability_cents` | Integer | Yes | Owner's Policy coverage amount in cents. Always reflected in output `liability_cents`. |
| `:loan_amount_cents` | Integer | No | Loan Policy coverage amount in cents. When present and > 0, the PR-4 max rule applies. When absent or 0, behaves as owner-only transaction. |
| `:policy_type` | Symbol | Yes | `:standard`, `:homeowners`, or `:extended`. Defaults to `:standard` if nil. |
| `:underwriter` | String | Yes | Underwriter code (e.g., `"TRG"`). Used for rate-tier and rules lookup. |
| `:as_of_date` | Date | No | Effective date for rate lookup. Defaults to `Date.today`. |
| `:prior_policy_amount_cents` | Integer | No | Prior policy amount for reissue discount eligibility. |
| `:prior_policy_date` | Date | No | Prior policy date for reissue discount eligibility. |

---

## Output

Returns an **Integer** (cents) representing the Owner's Policy premium.

The premium is computed as:

```
premium_input  = max(liability_cents, loan_amount_cents)   # if loan_amount_cents present & > 0
                 liability_cents                            # otherwise

base_rate      = RateTier.calculate_rate(round_up_to_1k(premium_input))
full_premium   = round(base_rate × policy_type_multiplier)
premium        = full_premium − reissue_discount            # if eligible
                 full_premium                               # otherwise
```

**Important**: The `liability_cents` output field in the *orchestrator's* result hash is set by `Calculator#calculate_owners_policy` and is always `purchase_price_cents`. The NC calculator returns only the premium integer — it does not control the output `liability_cents` field.

---

## Behavioural Rules

1. **PR-4 max rule**: Applies only when `loan_amount_cents` is present and > 0. The base rate input becomes `max(liability_cents, loan_amount_cents)`.
2. **Rounding**: NC rounds the premium input UP to the nearest $1,000 (100,000 cents) before tier lookup. This is handled by `BaseRate#rounded_liability`.
3. **Minimum premium**: NC minimum is $56.00 (5,600 cents). Applied after tier calculation, before multiplier.
4. **Policy type multiplier**: Standard = 1.00, Homeowner's = 1.20, Extended = 1.20.
5. **Reissue discount**: Computed on `liability_cents` (owner's actual coverage), NOT on the PR-4-adjusted input. 50% of the tiered rate on `min(liability_cents, prior_policy_amount_cents)`.

---

## Behavioural Invariants (must hold for all inputs)

- When `loan_amount_cents` is absent, nil, or 0: output is identical to pre-PR-4 behaviour.
- When `loan_amount_cents <= liability_cents`: `max` evaluates to `liability_cents` — output is identical to pre-PR-4 behaviour.
- When `loan_amount_cents > liability_cents`: base rate is computed on the loan amount; all other logic (multiplier, reissue discount, minimum) is unchanged.
- The reissue discount is never computed on a value larger than `liability_cents`.

---

## Example Calculations

### Case A — Loan exceeds owner (NEW path)
- Input: `liability_cents: 30_000_000` ($300k), `loan_amount_cents: 35_000_000` ($350k), `policy_type: :standard`
- `premium_input = max(30_000_000, 35_000_000) = 35_000_000`
- Rounding: $350k is already on a $1k boundary — no change
- Tier calc: $100k × $2.78 + $250k × $2.17 = $278.00 + $542.50 = $820.50
- Multiplier: 1.00 → $820.50
- Output: **82,050 cents** ($820.50)

### Case B — Owner exceeds loan (existing path, unchanged)
- Input: `liability_cents: 50_000_000` ($500k), `loan_amount_cents: 40_000_000` ($400k), `policy_type: :standard`
- `premium_input = max(50_000_000, 40_000_000) = 50_000_000`
- Output: **114,600 cents** ($1,146.00) — matches existing test `NC_purchase_loan`

### Case C — No loan (existing path, unchanged)
- Input: `liability_cents: 50_000_000` ($500k), `loan_amount_cents` absent
- `premium_input = 50_000_000`
- Output: **114,600 cents** ($1,146.00) — matches existing test `NC_purchase_cash`
