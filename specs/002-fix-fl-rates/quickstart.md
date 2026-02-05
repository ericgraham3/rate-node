# Quickstart: Fix FL Rate Calculator Discrepancies

**Audience**: Developer picking up this feature, or SME verifying the changes
**Date**: 2026-02-04

---

## What this feature does (plain language)

Three things in the Florida rate calculator are wrong compared to the published rate manual. This feature fixes all three:

1. **ALTA 6 and ALTA 6.2 endorsements** — these are "Variable Rate Mortgage" endorsements that lenders commonly request. They currently produce a $0.00 charge. The rate manual says each should be a flat $25.00.

2. **ALTA 9-series endorsements** — these cover restrictions, encroachments, and minerals. ALTA 9.3 currently produces $0.00; ALTA 9.1 and 9.2 are not recognized at all. All three should be priced at 10% of the combined owner + lender premium, with a $25.00 minimum. (ALTA 9 itself is already correct and is not changed.)

3. **Reissue eligibility boundary** — when a homeowner refinances and has a prior policy, they may qualify for lower "reissue" rates if the prior policy is recent enough. Florida's rule is "less than three years." The code currently uses "three years or less" (inclusive), which incorrectly grants the discount when the prior policy is exactly three years old.

---

## Files to edit

| File | What changes |
|------|--------------|
| `db/seeds/data/fl_rates.rb` | Edit the `ENDORSEMENTS` array: fix ALTA 6, 6.2, 9.3 entries; add ALTA 9.1 and 9.2 entries |
| `lib/ratenode/calculators/states/fl.rb` | Change `<=` to `<` in `eligible_for_reissue_rates?` |

That's it. Two files. No other files need modification.

---

## Step-by-step

### 1. Fix ALTA 6 and ALTA 6.2 in `db/seeds/data/fl_rates.rb`

Find these two entries in the `ENDORSEMENTS` array:

```ruby
{ code: "ALTA 6",   ..., pricing_type: "no_charge", lender_only: true },
{ code: "ALTA 6.2", ..., pricing_type: "no_charge", lender_only: true },
```

Change both to:

```ruby
{ code: "ALTA 6",   ..., pricing_type: "flat", base_amount: 2500, lender_only: true },
{ code: "ALTA 6.2", ..., pricing_type: "flat", base_amount: 2500, lender_only: true },
```

(`2500` = $25.00 in cents.)

### 2. Fix ALTA 9.3 in `db/seeds/data/fl_rates.rb`

Find:

```ruby
{ code: "ALTA 9.3", ..., pricing_type: "no_charge", lender_only: true },
```

Change to:

```ruby
{ code: "ALTA 9.3", ..., pricing_type: "percentage_combined", percentage: 0.10, min: 2500, lender_only: true },
```

### 3. Add ALTA 9.1 and ALTA 9.2 in `db/seeds/data/fl_rates.rb`

Insert these two new entries near the other ALTA 9-series entries (after ALTA 9, before or after ALTA 9.3):

```ruby
{ code: "ALTA 9.1", form_code: "ALTA 9.1", name: "Restrictions, Encroachments, Minerals - Owner Policy", pricing_type: "percentage_combined", percentage: 0.10, min: 2500 },
{ code: "ALTA 9.2", form_code: "ALTA 9.2", name: "Restrictions, Encroachments, Minerals - Owner Policy (Planned)", pricing_type: "percentage_combined", percentage: 0.10, min: 2500 },
```

Note: no `lender_only: true` — these are owner endorsements (confirmed in spec clarification).

### 4. Fix the reissue boundary in `lib/ratenode/calculators/states/fl.rb`

In the private method `eligible_for_reissue_rates?`, find:

```ruby
years_since_prior <= eligibility_years
```

Change to:

```ruby
years_since_prior < eligibility_years
```

### 5. Run the scenario tests

```bash
bundle exec rspec spec/integration/csv_scenarios_spec.rb
```

All existing scenarios must pass. If any fail, the change has broken something — investigate before proceeding.

---

## How to verify correctness (for SMEs)

The scenario test output prints each check. Look for the Florida scenarios:

- **FL_Purchase_Simple** — no endorsements, no reissue. Should pass unchanged.
- **FL_Purchase_With_Loan** — owner + lender, no endorsements listed. Should pass unchanged.
- **FL_Purchase_Reissue** — reissue with a prior policy from 1/1/2024. That's about 1 year ago, well inside the 3-year window. Should still get reissue rates.
- **FL_Endorsement_Combined** — includes ALTA 9 (already correct). Should pass unchanged.

To test the new endorsements and the boundary fix, new rows would need to be added to `spec/fixtures/scenarios_input.csv` by a domain expert with expected values from the FL rate manual. That is out of scope for this implementation task (see Constitution Principle V).

---

## Key reminders

- All dollar amounts in the code are in **cents** (integers). $25.00 = `2500`.
- Do not modify `scenarios_input.csv` — that's a human-controlled document.
- Do not touch any other state's files — FL changes are isolated by design.
- ALTA 9 (the base form) is already correctly priced and is NOT changed.
