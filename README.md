# RateNode

## Recent Updates (1/28/2026)

**Florida (FL) Implementation:**

- **Added FL as 4th supported state** with unique patterns:
  - **Liability rounding**: Nearest $100 (vs $10,000 in CA/NC, none in TX)
  - **Separate reissue rate table**: FL uses distinct rate tables for original vs reissue policies (vs percentage discount in NC)
  - **Minimum premium**: $100 (10,000 cents)
  - **Concurrent lender's fee**: $25 flat when loan ≤ owner liability
  - **Reissue eligibility**: 3 years from prior policy

- **New endorsement pricing types**:
  - `percentage_combined`: Rate based on combined owner's + lender's premium (FL survey endorsements)
  - `property_tiered`: Different rates for residential vs commercial (FL zoning endorsements)
  - Added `property_type` parameter to Calculator and CLI

- **FL rate structure** (tiered per-thousand, similar to NC):
  - $0 - $100,000: $5.75 per thousand (original) / $3.50 per thousand (reissue)
  - $100,001 - $1,000,000: $5.00 per thousand (original) / $3.00 per thousand (reissue)
  - Higher tiers have progressively lower rates

- **6 new FL test scenarios** added (24 total scenarios now)

**State-Based Refactoring:**

- **Centralized state rules** in `lib/ratenode/state_rules.rb`:
  - All state-specific constants (concurrent fees, CPL settings, reissue discounts, liability rounding) now in one place
  - Replaced hardcoded constants in `lenders_policy.rb`, `cpl_calculator.rb`, `owners_policy.rb`, `base_rate.rb`
  - Easy to add new states by copying a STATE_RULES entry

- **Reorganized seed data** by state:
  ```
  db/seeds/
  ├── rates.rb              # Simplified loader (~140 lines)
  └── data/
      ├── ca_rates.rb       # CA rate tiers, endorsements, refinance rates
      ├── nc_rates.rb       # NC rate tiers, endorsements, CPL, refinance rates
      ├── tx_rates.rb       # TX rate tiers, endorsements (converted from CSV)
      └── fl_rates.rb       # FL rate tiers (original + reissue), endorsements
  ```

- **TX endorsements converted** from CSV to Ruby hashes (no runtime CSV parsing)
- **Archived old TX files** to `docs/archived/`

**To add a new state:**
1. Add entry to `STATE_RULES` in `lib/ratenode/state_rules.rb`
2. Create `db/seeds/data/{state}_rates.rb` with rate tiers, endorsements, etc.
3. Add `seed_{state}()` method in `db/seeds/rates.rb`

---

## Recent Updates (1/23/2026)

- **Consolidated test suite**: Single CSV-driven integration test file
- **Simplified spec directory structure**:
  ```
  spec/
  ├── spec_helper.rb              # Simplified RSpec config
  ├── integration/
  │   └── csv_scenarios_spec.rb   # Single test file for all scenarios
  └── fixtures/
      └── scenarios_input.csv     # Test data (18 scenarios: CA, NC, TX)
  ```
- **Enhanced test output**: Checkmarks (✓/✗), tolerance warnings (±$2.00), summary section
- **24 test scenarios passing**: 2 CA, 4 NC, 12 TX, 6 FL

---

## Known Issues 1/22/26
- Endorsement rates need to be calculated off of correct policy type (e.g., a T-19 endorsement charge for the loan title policy is 5% of the basic premium rate for the loan policy) but they're currently calculating based off the owners rate

## Recent Updates (1/22/2026)

Today's changes:
- **Reverted Texas (TX) rates to 2019 promulgated rates** (effective September 1, 2019)
  - The 2025 TX rates have not yet been implemented by the TX Dept. of Insurance due to ongoing litigation
  - 2019 rates remain in effect as of January 2026
- **TX Owner's Policy**: Formula-based calculation for policies over $100,000
  - $100,001 - $1,000,000: $5.27 per $1,000 + $832 base
  - Higher tiers have progressively lower per-thousand rates (see Pricing Rules below)
- **TX Simultaneous Issue Lender's Policy**: $100 flat fee (when loan ≤ owner liability)
- **TX Endorsements**: 58 endorsements loaded from promulgated rate manual
  - Refactored endorsement system to use unique codes (e.g., "0885") instead of form numbers
  - Multiple variants per form now supported (e.g., T-19.1 has 4 variants with different rates)
  - Added `form_code` field for display, `code` field for unique lookup
- **TX CPL**: Not applicable (no charge)
- **No liability rounding for TX**: Texas uses exact liability amounts (unlike CA/NC which round up to next $10,000)

---

## Previous Updates (1/8/2026)

- **Updated NC underwriter from INVESTORS to TRG** (Chicago Title rates effective Oct 1, 2025)
- **Implemented Chicago Title tiered rate structure** for NC: $2.78/$2.17/$1.41/$1.08/$0.75 per thousand across 5 tiers
- **Added NC-specific endorsement pricing**: ALTA 5, ALTA 8.1, and ALTA 9 now charge $23.00 flat fee (vs no-charge in CA)
- **Fixed CPL calculation duplicates** by adding unique constraints to database
- **Implemented state-specific business rules**:
  - NC Homeowner's policy: 120% multiplier (vs 110% in CA)
  - NC Simultaneous issue: $28.50 flat (vs $150 in CA)
  - NC Reissue discount: 50% on prior policy amount within 15 years
  - NC CPL tiered rates: $0.69/$0.13/$0.00 per thousand
- **All CSV integration test scenarios passing**

---

Multi-state title insurance premium calculator supporting multiple states and underwriters with date-based rate versioning. Currently includes California (TRG), North Carolina (Chicago Title/TRG), Texas (promulgated rates), and Florida (TRG) rate tables.

## Setup

```bash
bundle install
```

## Project Structure

```
lib/ratenode/
├── state_rules.rb              # Centralized state-specific constants
├── calculator.rb               # Main calculation orchestrator
├── calculators/
│   ├── base_rate.rb            # Base rate lookup/calculation
│   ├── owners_policy.rb        # Owner's policy with reissue discount
│   ├── lenders_policy.rb       # Lender's policy (concurrent/standalone)
│   ├── cpl_calculator.rb       # Closing Protection Letter
│   ├── endorsement_calculator.rb
│   └── refinance.rb
└── models/
    ├── rate_tier.rb            # Rate tier lookup and tiered calculation
    ├── endorsement.rb          # Endorsement pricing
    ├── policy_type.rb          # Policy type multipliers
    ├── cpl_rate.rb             # CPL rate tiers
    └── refinance_rate.rb

db/seeds/
├── rates.rb                    # Seed loader (calls state-specific seeders)
└── data/
    ├── ca_rates.rb             # California: TRG rates (effective 2024-01-01)
    ├── nc_rates.rb             # North Carolina: TRG/Chicago Title (effective 2025-10-01)
    ├── tx_rates.rb             # Texas: Promulgated rates (effective 2019-09-01)
    └── fl_rates.rb             # Florida: TRG rates (effective 2025-01-01)
```

## CLI Usage

```bash
# Purchase transaction (standard owner's policy + concurrent lender's)
# State and underwriter are now required
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000

# Extended owner's policy (125% of Schedule of Rates)
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --policy_type=extended

# Homeowner's policy (110% of Schedule of Rates)
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --policy_type=homeowner

# Refinance transaction
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --type=refinance \
  --loan_amount=400000

# With endorsements
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --endorsements="CLTA 115,ALTA 4.1,CLTA 100"

# Owner's policy only (no lender's)
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --no_lenders_policy

# North Carolina Chicago Title (TRG) - uses tiered rate structure
bundle exec bin/ratenode calculate \
  --state NC \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000

# NC with CPL (Closing Protection Letter) and reissue discount
bundle exec bin/ratenode calculate \
  --state NC \
  --underwriter TRG \
  --purchase_price=60000 \
  --loan_amount=58200 \
  --cpl \
  --prior_policy_amount=35000 \
  --prior_policy_date=2020-01-01 \
  --endorsements="ALTA 8.1,ALTA 9"

# Texas (promulgated rates) - uses formula-based calculation
bundle exec bin/ratenode calculate \
  --state TX \
  --underwriter DEFAULT \
  --purchase_price=500000 \
  --loan_amount=400000

# TX with endorsements (use code for specific variant)
bundle exec bin/ratenode calculate \
  --state TX \
  --underwriter DEFAULT \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --endorsements="0885,0890"

# Florida - uses tiered rates with separate reissue table
bundle exec bin/ratenode calculate \
  --state FL \
  --underwriter TRG \
  --purchase_price=200000 \
  --loan_amount=160000

# FL with reissue (prior policy within 3 years)
bundle exec bin/ratenode calculate \
  --state FL \
  --underwriter TRG \
  --purchase_price=200000 \
  --prior_policy_amount=150000 \
  --prior_policy_date=2024-01-01

# FL with property type for endorsements (affects pricing)
bundle exec bin/ratenode calculate \
  --state FL \
  --underwriter TRG \
  --purchase_price=150000 \
  --property_type=residential \
  --endorsements="ALTA 3"

# With specific effective date (for historical calculations)
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --as-of-date=2024-01-01 \
  --purchase_price=500000 \
  --loan_amount=400000

# JSON output
bundle exec bin/ratenode calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --json
```

## Library Usage

```ruby
require_relative 'lib/ratenode'
require 'date'

RateNode.setup_database

# State and underwriter are now required parameters
result = RateNode.calculate(
  state: "CA",
  underwriter: "TRG",
  transaction_type: :purchase,
  purchase_price_cents: 50_000_000,   # $500,000
  loan_amount_cents: 40_000_000,      # $400,000
  owner_policy_type: :standard,       # :standard, :homeowner, :extended
  include_lenders_policy: true,
  endorsement_codes: ['CLTA 115', 'ALTA 4.1'],
  as_of_date: Date.today              # Optional, defaults to today
)

# North Carolina Chicago Title (TRG) with CPL and reissue discount
result_nc = RateNode.calculate(
  state: "NC",
  underwriter: "TRG",
  transaction_type: :purchase,
  purchase_price_cents: 6_000_000,      # $60,000
  loan_amount_cents: 5_820_000,         # $58,200
  owner_policy_type: :standard,
  include_lenders_policy: true,
  endorsement_codes: ['ALTA 8.1', 'ALTA 9'],
  include_cpl: true,                    # Closing Protection Letter
  prior_policy_amount_cents: 3_500_000, # $35,000
  prior_policy_date: Date.new(2020, 1, 1)
)

# Texas (promulgated rates)
result_tx = RateNode.calculate(
  state: "TX",
  underwriter: "DEFAULT",               # TX uses state-regulated rates
  transaction_type: :purchase,
  purchase_price_cents: 50_000_000,     # $500,000
  loan_amount_cents: 40_000_000,        # $400,000
  owner_policy_type: :standard,
  include_lenders_policy: true,
  endorsement_codes: ['0885', '0890']   # TX uses numeric codes for endorsements
)

# TX endorsement lookup by form (returns all variants)
variants = RateNode::Models::Endorsement.find_by_form_code(
  "T-19.1",
  state: "TX",
  underwriter: "DEFAULT"
)
# Returns 4 variants: 0889 (15%), 0895 (10%), 0897 (10%), 0898 (5%)

# Florida (TRG) - uses tiered rates with separate reissue table
result_fl = RateNode.calculate(
  state: "FL",
  underwriter: "TRG",
  transaction_type: :purchase,
  purchase_price_cents: 20_000_000,     # $200,000
  loan_amount_cents: 16_000_000,        # $160,000
  owner_policy_type: :standard,
  include_lenders_policy: true
)

# FL with reissue rates (prior policy within 3 years)
result_fl_reissue = RateNode.calculate(
  state: "FL",
  underwriter: "TRG",
  transaction_type: :purchase,
  purchase_price_cents: 20_000_000,     # $200,000
  prior_policy_amount_cents: 15_000_000, # $150,000
  prior_policy_date: Date.new(2024, 1, 1)
)

# FL with property type for endorsements
result_fl_endorsements = RateNode.calculate(
  state: "FL",
  underwriter: "TRG",
  transaction_type: :purchase,
  purchase_price_cents: 15_000_000,     # $150,000
  property_type: :residential,          # :residential or :commercial
  endorsement_codes: ['ALTA 3']         # $25 residential, $100 commercial
)

# Structured hash for closing disclosure integration
result.to_h

# JSON output
result.to_json

# Human-readable text
puts result.to_s
```

## Pricing Rules

### Owner's Policies

**California (TRG):**
| Type | Rate |
|------|------|
| Standard (CLTA/ALTA with WRE) | 100% of Schedule of Rates |
| Homeowner's | 110% of Schedule of Rates |
| Extended (ALTA without WRE) | 125% of Schedule of Rates |

**North Carolina (Chicago Title/TRG):**
| Type | Rate |
|------|------|
| Standard | 100% of tiered rate structure |
| Homeowner's | 120% of tiered rate structure |
| Extended | 120% of tiered rate structure |

NC uses a tiered calculation (like progressive tax brackets):
- Up to $100,000: $2.78 per thousand
- $100,001 to $500,000: add $2.17 per thousand
- $500,001 to $2,000,000: add $1.41 per thousand
- $2,000,001 to $7,000,000: add $1.08 per thousand
- $7,000,001 and above: add $0.75 per thousand

**Texas (Promulgated Rates):**
| Type | Rate |
|------|------|
| Standard | 100% of basic premium rate |
| Homeowner's | 100% of basic premium rate |

**Florida (TRG):**
| Type | Rate |
|------|------|
| Standard | 100% of tiered rate structure |
| Homeowner's | 100% of tiered rate structure |

FL uses a tiered calculation (similar to NC) with separate original and reissue rate tables:

**Original Rates:**
- Up to $100,000: $5.75 per thousand
- $100,001 to $1,000,000: add $5.00 per thousand
- $1,000,001 to $5,000,000: add $2.50 per thousand
- $5,000,001 to $10,000,000: add $2.25 per thousand
- Over $10,000,000: add $2.00 per thousand

**Reissue Rates** (prior policy within 3 years):
- Up to $100,000: $3.50 per thousand
- $100,001 to $1,000,000: add $3.00 per thousand
- $1,000,001 to $5,000,000: add $1.75 per thousand
- $5,000,001 to $10,000,000: add $1.50 per thousand
- Over $10,000,000: add $1.25 per thousand

**FL Minimum Premium:** $100

TX uses formula-based calculation for policies over $100,000 (2019 rates, effective September 1, 2019):
- $25,000 to $100,000: Lookup table (flat rates per $500 increment)
- $100,001 to $1,000,000: $5.27 per $1,000 over $100,000 + $832
- $1,000,001 to $5,000,000: $4.33 per $1,000 over $1,000,000 + $5,575
- $5,000,001 to $15,000,000: $3.57 per $1,000 over $5,000,000 + $22,895
- $15,000,001 to $25,000,000: $2.54 per $1,000 over $15,000,000 + $58,595
- $25,000,001 to $50,000,000: $1.52 per $1,000 over $25,000,000 + $83,995
- $50,000,001 to $100,000,000: $1.38 per $1,000 over $50,000,000 + $121,995
- Over $100,000,000: $1.24 per $1,000 over $100,000,000 + $190,995

**Note:** TX does not round liability amounts (uses exact values).

### Lender's Policies

**California (TRG):**
| Scenario | Rate |
|----------|------|
| Concurrent (loan ≤ owner liability) | $150 flat |
| Concurrent (loan > owner liability) | $150 + Extended Lenders Concurrent Rate for excess |
| Refinance (1-4 family residential) | Special flat rate table |

**North Carolina (Chicago Title/TRG):**
| Scenario | Rate |
|----------|------|
| Concurrent (simultaneous issue) | $28.50 flat |
| Refinance (1-4 family residential) | Special flat rate table |

**Texas (Promulgated Rates):**
| Scenario | Rate |
|----------|------|
| Simultaneous issue (loan ≤ owner liability) | $100 flat |
| Simultaneous issue (loan > owner liability) | $100 + basic rate for excess |

**Florida (TRG):**
| Scenario | Rate |
|----------|------|
| Concurrent (loan ≤ owner liability) | $25 flat |
| Concurrent (loan > owner liability) | $25 + ELC rate for excess |
| Refinance (1-4 family residential) | Special flat rate table |

### Closing Protection Letter (CPL)

**California (TRG):** Not applicable

**North Carolina (Chicago Title/TRG):** Tiered rates
- Up to $100,000: $0.69 per thousand
- $100,001 to $500,000: add $0.13 per thousand
- $500,001 and above: add $0.00 per thousand

**Texas (Promulgated Rates):** Not applicable (no charge)

**Florida (TRG):** Not applicable

### Reissue Discount

**California (TRG):** Not applicable

**North Carolina (Chicago Title/TRG):**
- 50% discount on portion up to prior policy amount
- Only available if prior policy issued within 15 years

**Florida (TRG):**
- Uses separate reissue rate table (lower per-thousand rates) instead of percentage discount
- Prior policy amount at reissue rates, excess at original rates
- Only available if prior policy issued within 3 years

### Endorsement Pricing

Some endorsements have state-specific pricing:
- **ALTA 5** (Planned Unit Development): No charge (CA) | $23.00 flat (NC)
- **ALTA 8.1** (Environmental Lien Protection): No charge (CA) | $23.00 flat (NC)
- **ALTA 9** (Restrictions, Encroachments, Minerals): No charge (CA) | $23.00 flat (NC)

**Texas Endorsements:**
TX endorsements use a unique code system (not form numbers) because many forms have multiple rate variants:

| Code | Form | Description | Rate |
|------|------|-------------|------|
| 0885 | T-19 | Restrictions, Encroachments & Minerals - Res | 5% of basic rate, min $50 |
| 0886 | T-19 | Restrictions, Encroachments & Minerals - Non-Res | 10% of basic rate, min $50 |
| 0889 | T-19.1 | Restrictions, Encroachments & Minerals - Non-Res | 15% of basic rate |
| 0895 | T-19.1 | Restrictions, Encroachments & Minerals - Non-Res (w/survey) | 10% of basic rate, min $50 |
| 0897 | T-19.1 | Restrictions, Encroachments & Minerals - Res | 10% of basic rate, min $50 |
| 0898 | T-19.1 | Restrictions, Encroachments & Minerals - Non-Res (w/survey) | 5% of basic rate, min $50 |
| 0890 | T-23 | Access Endorsement | $100 flat |
| 0891 | T-24 | Non-Imputation Endorsement | 5% of basic rate, min $25 |

Use `Endorsement.find_by_form_code("T-19.1", ...)` to find all variants of a form.

**Florida Endorsements:**
FL endorsements use two special pricing types:

| Code | Description | Pricing |
|------|-------------|---------|
| ALTA 9 | Restrictions, Encroachments, Minerals | 5% of combined premium, min $25 |
| ALTA 22 | Location | 10% of combined premium, min $50 |
| ALTA 3 | Zoning - Unimproved | $25 (residential) / $100 (commercial) |
| ALTA 3.1 | Zoning - Improved | $50 (residential) / $150 (commercial) |
| ALTA 19 | Contiguity | $50 (residential) / $150 (commercial) |

- `percentage_combined`: Rate based on combined owner's + lender's premium
- `property_tiered`: Different flat rates for residential vs commercial properties

### Key Rounding Rules

**California and North Carolina:**
- Liability rounded UP to next $10,000 before rate lookup/calculation
- Final premium rounded to nearest dollar

**Florida:**
- Liability rounded UP to next $100 before rate lookup/calculation
- Final premium rounded to nearest dollar
- Minimum premium of $100 enforced

**Texas:**
- **No liability rounding** - uses exact liability amounts
- Formula calculations round at each step, then multiply to cents

**Difference in Calculation Method:**
- **CA**: Uses rounded liability to look up flat rate from Schedule of Rates table
- **NC**: Uses rounded liability to calculate across progressive tiered brackets (similar to tax brackets)
- **FL**: Uses rounded liability ($100 increments) with tiered calculation, separate original/reissue tables
- **TX**: Uses exact liability with formula-based calculation (lookup table for amounts up to $100k)

## Tests

```bash
bundle exec rspec
```

### Test Structure

All tests are driven by a single CSV file (`spec/fixtures/scenarios_input.csv`) containing expected values for each scenario. The test runner:

1. Parses each row from the CSV
2. Calls `RateNode.calculate()` with the scenario parameters
3. Compares actual vs expected values with ±$2.00 tolerance
4. Outputs formatted results with pass/fail status

### Adding New Test Scenarios

Add a row to `spec/fixtures/scenarios_input.csv` with columns:
- `scenario_name` - Unique identifier
- `state` - CA, NC, TX, or FL
- `underwriter` - TRG, DEFAULT, etc. (optional, uses state default)
- `transaction_type` - purchase or refinance
- `purchase_price`, `loan_amount` - In dollars
- `prior_policy_amount`, `prior_policy_date` - For reissue discount
- `owners_policy_type`, `lender_policy_type` - standard, homeowner, extended
- `endorsements` - Comma-separated codes
- `cpl` - TRUE/FALSE
- `property_type` - residential or commercial (for FL endorsements)
- `expected_*` - Expected values for validation
