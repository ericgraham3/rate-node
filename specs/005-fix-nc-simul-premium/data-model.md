# Data Model: NC Simultaneous Issue Base Premium (PR-4)

This document maps the data entities involved in the PR-4 fix and shows exactly how they flow through the two modified files.

---

## Entities

### Owner's Policy Coverage
- **Source**: `Calculator#purchase_price_cents` (set from user input)
- **Role**: The liability amount insured under the Owner's title insurance policy. Used as the reported `liability_cents` in output. One of the two values compared under PR-4.
- **Stored as**: Integer, cents

### Loan Policy Coverage
- **Source**: `Calculator#loan_amount_cents` (set from user input)
- **Role**: The liability amount insured under the Loan Policy. Compared against the Owner's coverage to determine which value drives the base premium under PR-4. Only relevant when `include_lenders_policy` is true.
- **Stored as**: Integer, cents
- **Guard**: If `loan_amount_cents` is 0 and no lender's policy is flagged, PR-4 does not apply.

### Base Premium Input (derived)
- **Computed in**: `States::NC#calculate_standard` (private)
- **Formula**: `max(liability_cents, loan_amount_cents)` when `loan_amount_cents` is present and non-zero; otherwise `liability_cents`
- **Role**: The amount fed into the PR-2 tiered rate lookup. Not stored or returned — it is an intermediate calculation value.

### Base Premium (output)
- **Computed in**: `Calculators::BaseRate#calculate` (via `Models::RateTier.calculate_rate`)
- **Input**: The Base Premium Input (after NC's $1,000 round-up)
- **Output**: Integer cents — the owner's premium before policy-type multiplier and reissue discount

### Simultaneous Issue Charge
- **Source**: `state_rules[:concurrent_base_fee_cents]` = 2,850 cents ($28.50)
- **Computed in**: `Calculators::LendersPolicy#calculate_concurrent`
- **Role**: Flat per-Loan-Policy charge. Unaffected by PR-4.

---

## Data Flow Diagram

```
User Input
    │
    ├── purchase_price_cents  ──────────────► Calculator#calculate_owners_policy
    │                                              │
    ├── loan_amount_cents  ────────────────────────┤  (NEW: added to params hash
    │                                              │   when include_lenders_policy)
    ├── include_lenders_policy ────────────────────┤
    │                                              ▼
    │                                      params = {
    │                                        liability_cents:      purchase_price_cents,
    │                                        loan_amount_cents:    loan_amount_cents,   ← NEW
    │                                        policy_type:          ...,
    │                                        ...
    │                                      }
    │                                              │
    │                                              ▼
    │                                      States::NC#calculate_owners_premium(params)
    │                                              │
    │                                              ├── @liability_cents = params[:liability_cents]
    │                                              ├── @loan_amount_cents = params[:loan_amount_cents]  ← NEW
    │                                              │
    │                                              ▼
    │                                      calculate_standard (private)
    │                                              │
    │                                              ├── premium_input = if @loan_amount_cents && @loan_amount_cents > 0
    │                                              │                     max(@liability_cents, @loan_amount_cents)  ← NEW
    │                                              │                   else
    │                                              │                     @liability_cents
    │                                              │                   end
    │                                              │
    │                                              ├── BaseRate.new(premium_input, ...).calculate
    │                                              │       └── rounds UP to $1,000, looks up PR-2 tiers
    │                                              │
    │                                              ├── × policy_type multiplier
    │                                              ├── − reissue discount (still on @liability_cents)
    │                                              └── → premium_cents (Integer)
    │
    │                                      Output hash:
    │                                        liability_cents:  purchase_price_cents   ← UNCHANGED
    │                                        premium_cents:    (computed above)
    │
    └── (loan path) ────────────────────────► LendersPolicy#calculate_concurrent
                                                    └── returns 2_850 (flat, unchanged)
```

---

## Field-Level Change Summary

| File | Location | Field / Variable | Change |
|------|----------|-----------------|--------|
| `calculator.rb` | `calculate_owners_policy`, params hash | `loan_amount_cents` | Added when `include_lenders_policy` is true |
| `calculators/states/nc.rb` | `calculate_owners_premium` | `@loan_amount_cents` | New instance variable, read from params |
| `calculators/states/nc.rb` | `calculate_standard` | `premium_input` | New local: `max(@liability_cents, @loan_amount_cents)` when loan present |
| `calculators/states/nc.rb` | `calculate_standard` | `BaseRate.new(...)` | First argument changes from `@liability_cents` to `premium_input` |

---

## What Does NOT Change

- `liability_cents` in the Owner's Policy output hash (`calculator.rb:100`) — always `purchase_price_cents`
- Reissue discount calculation — still uses `@liability_cents` for the discountable portion
- Lender's concurrent fee — still $28.50 flat
- Any other state calculator — CA, TX, FL, AZ all ignore the new `loan_amount_cents` key
- The `BaseStateCalculator` contract — no new method signatures
- The CSV schema — no new columns needed
