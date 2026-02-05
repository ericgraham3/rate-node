# Quickstart: NC Simultaneous Issue PR-4 Fix

How to build, test, and verify this feature end-to-end.

---

## Prerequisites

- Ruby 3.4.8
- Bundler (`bundle install` from repo root)
- SQLite database seeded (`bundle exec ruby db/seeds/rates.rb` if not already done)

---

## Run the Existing Test Suite

```bash
bundle exec rspec
```

All existing scenarios (including the three NC scenarios) must pass before and after the code change. If they fail before you touch any code, the database may need re-seeding.

---

## Verify the Bug (before the fix)

Use the CLI to submit an NC simultaneous issue transaction where the loan exceeds the owner's coverage:

```bash
bundle exec ruby bin/ratenode quote \
  --state NC \
  --underwriter TRG \
  --transaction-type purchase \
  --purchase-price 300000 \
  --loan-amount 350000 \
  --owners-policy-type standard \
  --include-lenders-policy
```

**Before the fix**: The owner's premium will be computed on $300,000 (the owner's coverage), producing a base premium lower than $820.50.

**After the fix**: The owner's premium will be $820.50 (computed on $350,000 per PR-4), and the lender's concurrent charge will be $28.50, for a combined total of $849.00.

---

## Verify the Fix Does Not Affect Other States

Run the full scenario suite after the change:

```bash
bundle exec rspec spec/integration/csv_scenarios_spec.rb
```

Every non-NC scenario must produce identical results. The three existing NC scenarios (cash, loan where owner > loan, loan with reissue) must also produce identical results — the PR-4 max rule only changes output when loan > owner.

---

## Add the New CSV Scenario (Human Action)

Per Constitution Principle V, the agent does not modify `scenarios_input.csv`. The following row must be added by hand, with values verified against PR-2 tiers (see `research.md` §2):

```
NC_purchase_loan_exceeds_owner,NC,TRG,purchase,300000,350000,,,standard,standard,,,FALSE,,820.5,28.5,,,,849
```

**Fields**: scenario_name, state, underwriter, transaction_type, purchase_price, loan_amount, prior_policy_amount, prior_policy_date, owners_policy_type, lender_policy_type, endorsements, is_hold_open, cpl, property_type, expected_owners_premium, expected_lenders_premium, expected_endorsement_charges, expected_cpl_charges, expected_reissue_discount, expected_total

Add this row to the NC block in `spec/fixtures/scenarios_input.csv` and re-run `bundle exec rspec` to confirm it passes.

---

## Key Files Touched

| File | What changed |
|------|-------------|
| `lib/ratenode/calculator.rb` | `calculate_owners_policy` passes `loan_amount_cents` in the params hash when `include_lenders_policy` is true |
| `lib/ratenode/calculators/states/nc.rb` | `calculate_owners_premium` reads `loan_amount_cents`; `calculate_standard` uses `max(liability, loan)` as the base-rate input |
