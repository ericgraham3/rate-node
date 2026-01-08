# TitleRound

## Recent Updates (1/8/2026)

Today's changes:
- **Updated NC underwriter from INVESTORS to TRG** (Chicago Title rates effective Oct 1, 2025)
- **Implemented Chicago Title tiered rate structure** for NC: $2.78/$2.17/$1.41/$1.08/$0.75 per thousand across 5 tiers
- **Added NC-specific endorsement pricing**: ALTA 5, ALTA 8.1, and ALTA 9 now charge $23.00 flat fee (vs no-charge in CA)
- **Fixed CPL calculation duplicates** by adding unique constraints to database
- **Implemented state-specific business rules**:
  - NC Homeowner's policy: 120% multiplier (vs 110% in CA)
  - NC Simultaneous issue: $28.50 flat (vs $150 in CA)
  - NC Reissue discount: 50% on prior policy amount within 15 years
  - NC CPL tiered rates: $0.69/$0.13/$0.00 per thousand
- **All 6 CSV integration test scenarios now passing**

---

Multi-state title insurance premium calculator supporting multiple states and underwriters with date-based rate versioning. Currently includes California (TRG) and North Carolina (Chicago Title/TRG) rate tables.

## Setup

```bash
bundle install
```

## CLI Usage

```bash
# Purchase transaction (standard owner's policy + concurrent lender's)
# State and underwriter are now required
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000

# Extended owner's policy (125% of Schedule of Rates)
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --policy_type=extended

# Homeowner's policy (110% of Schedule of Rates)
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --policy_type=homeowner

# Refinance transaction
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --type=refinance \
  --loan_amount=400000

# With endorsements
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --endorsements="CLTA 115,ALTA 4.1,CLTA 100"

# Owner's policy only (no lender's)
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --no_lenders_policy

# North Carolina Chicago Title (TRG) - uses tiered rate structure
bundle exec bin/title_round calculate \
  --state NC \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000

# NC with CPL (Closing Protection Letter) and reissue discount
bundle exec bin/title_round calculate \
  --state NC \
  --underwriter TRG \
  --purchase_price=60000 \
  --loan_amount=58200 \
  --cpl \
  --prior_policy_amount=35000 \
  --prior_policy_date=2020-01-01 \
  --endorsements="ALTA 8.1,ALTA 9"

# With specific effective date (for historical calculations)
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --as-of-date=2024-01-01 \
  --purchase_price=500000 \
  --loan_amount=400000

# JSON output
bundle exec bin/title_round calculate \
  --state CA \
  --underwriter TRG \
  --purchase_price=500000 \
  --loan_amount=400000 \
  --json
```

## Library Usage

```ruby
require_relative 'lib/title_round'
require 'date'

TitleRound.setup_database

# State and underwriter are now required parameters
result = TitleRound.calculate(
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
result_nc = TitleRound.calculate(
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

### Closing Protection Letter (CPL)

**California (TRG):** Not applicable

**North Carolina (Chicago Title/TRG):** Tiered rates
- Up to $100,000: $0.69 per thousand
- $100,001 to $500,000: add $0.13 per thousand
- $500,001 and above: add $0.00 per thousand

### Reissue Discount

**California (TRG):** Not applicable

**North Carolina (Chicago Title/TRG):**
- 50% discount on portion up to prior policy amount
- Only available if prior policy issued within 15 years

### Endorsement Pricing

Some endorsements have state-specific pricing:
- **ALTA 5** (Planned Unit Development): No charge (CA) | $23.00 flat (NC)
- **ALTA 8.1** (Environmental Lien Protection): No charge (CA) | $23.00 flat (NC)
- **ALTA 9** (Restrictions, Encroachments, Minerals): No charge (CA) | $23.00 flat (NC)

### Key Rounding Rules

**Both California and North Carolina:**
- Liability rounded UP to next $10,000 before rate lookup/calculation
- Final premium rounded to nearest dollar

**Difference in Calculation Method:**
- **CA**: Uses rounded liability to look up flat rate from Schedule of Rates table
- **NC**: Uses rounded liability to calculate across progressive tiered brackets (similar to tax brackets)

## Tests

```bash
bundle exec rspec
```
