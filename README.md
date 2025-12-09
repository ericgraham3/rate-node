# TitleRound

Multi-state title insurance premium calculator supporting multiple states and underwriters with date-based rate versioning. Currently includes California (TRG) and North Carolina (Investors Title) rate tables.

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

# North Carolina Investors Title (example of different state/underwriter)
bundle exec bin/title_round calculate \
  --state NC \
  --underwriter INVESTORS \
  --purchase_price=500000 \
  --loan_amount=400000

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

# North Carolina Investors Title example
result_nc = TitleRound.calculate(
  state: "NC",
  underwriter: "INVESTORS",
  transaction_type: :purchase,
  purchase_price_cents: 50_000_000,
  loan_amount_cents: 40_000_000
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
| Type | Rate |
|------|------|
| Standard (CLTA/ALTA with WRE) | 100% of Schedule of Rates |
| Homeowner's | 110% of Schedule of Rates |
| Extended (ALTA without WRE) | 125% of Schedule of Rates |

### Lender's Policies
| Scenario | Rate |
|----------|------|
| Concurrent (loan ≤ owner liability) | $150 flat |
| Concurrent (loan > owner liability) | $150 + Extended Lenders Concurrent Rate for excess |
| Refinance (1-4 family residential) | Special flat rate table |

### Key Rounding Rules
- Liability rounded UP to next $10,000 before rate lookup
- Final premium rounded UP to nearest dollar

## Tests

```bash
bundle exec rspec
```
