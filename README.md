# RateNode

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
- **All 6 CSV integration test scenarios now passing**

---

Multi-state title insurance premium calculator supporting multiple states and underwriters with date-based rate versioning. Currently includes California (TRG), North Carolina (Chicago Title/TRG), and Texas (promulgated rates) rate tables.

## Setup

```bash
bundle install
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

### Closing Protection Letter (CPL)

**California (TRG):** Not applicable

**North Carolina (Chicago Title/TRG):** Tiered rates
- Up to $100,000: $0.69 per thousand
- $100,001 to $500,000: add $0.13 per thousand
- $500,001 and above: add $0.00 per thousand

**Texas (Promulgated Rates):** Not applicable (no charge)

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

### Key Rounding Rules

**California and North Carolina:**
- Liability rounded UP to next $10,000 before rate lookup/calculation
- Final premium rounded to nearest dollar

**Texas:**
- **No liability rounding** - uses exact liability amounts
- Formula calculations round at each step, then multiply to cents

**Difference in Calculation Method:**
- **CA**: Uses rounded liability to look up flat rate from Schedule of Rates table
- **NC**: Uses rounded liability to calculate across progressive tiered brackets (similar to tax brackets)
- **TX**: Uses exact liability with formula-based calculation (lookup table for amounts up to $100k)

## Tests

```bash
bundle exec rspec
```
