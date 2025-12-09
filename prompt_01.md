CONTEXT:
You are working on a Ruby gem (TitleRound) that calculates California title insurance premiums. 
Currently, it only supports rates for the state of California and underwriter TRG hardcoded in db/seeds/rates.rb. We need to 
expand it to support multiple states and underwriters with date-based rate versioning.

CURRENT ARCHITECTURE:
- Database: SQLite3 at db/title_round.db
- Tables: rate_tiers, refinance_rates, endorsements, policy_types
- Models: RateTier, RefinanceRate, Endorsement, PolicyType (in lib/title_round/models/)
- Calculator: lib/title_round/calculator.rb orchestrates calculations
- Seeds: db/seeds/rates.rb contains California TRG rate constants
- Schema: db/schema.sql defines table structures

GOAL:
Add support for multiple state/underwriter combinations with optional date-based queries.

REQUIREMENTS:

1. DATABASE SCHEMA CHANGES (db/schema.sql):
   - Add to rate_tiers table:
     * state_code VARCHAR(2) NOT NULL DEFAULT 'CA'
     * underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG'
     * effective_date DATE NOT NULL DEFAULT '2024-01-01'
     * expires_date DATE
   - Add same columns to: refinance_rates, endorsements, policy_types
   - Add indexes: (state_code, underwriter_code, effective_date) on all tables
   
2. MODEL UPDATES (lib/title_round/models/*.rb):
   - Add scope to all models: for_jurisdiction(state, underwriter, as_of_date = Date.today)
   - Update all finder methods to filter by state/underwriter/date
   - Example for RateTier.find_by_liability:
     * Add parameters: state:, underwriter:, as_of_date: Date.today
     * Filter WHERE state_code = ? AND underwriter_code = ?
     * Filter WHERE effective_date <= ? AND (expires_date IS NULL OR expires_date > ?)

3. CALCULATOR UPDATES (lib/title_round/calculator.rb):
   - Add required parameters to calculate_purchase and calculate_refinance:
     * state: (required, no default)
     * underwriter: (required, no default)  
     * as_of_date: Date.today (optional, defaults to today)
   - Pass these through to all model calls

4. CLI UPDATES (lib/title_round/cli.rb):
   - Add --state flag (required)
   - Add --underwriter flag (required)
   - Add --as-of-date flag (optional, defaults to today)
   - Update help text

5. SEED FILE UPDATES (db/seeds/rates.rb):
   - Update existing CA TRG constants to include:
     * state_code: "CA"
     * underwriter_code: "TRG"  
     * effective_date: Date.new(2024, 1, 1)
     * expires_date: nil

6. TEST DATA GENERATION:
   - Generate a DUMMY North Carolina Investors Title rate schedule
   - Create module Seeds::NC_INVESTORS with:
     * RATE_TIERS (make rates ~10% different from CA for easy testing)
     * REFINANCE_RATES (adjust accordingly)
     * ENDORSEMENTS (use similar codes but different prices)
     * POLICY_TYPES (same 3 types: standard, homeowner, extended)
   - All records tagged with:
     * state_code: "NC"
     * underwriter_code: "INVESTORS"
     * effective_date: Date.new(2024, 1, 1)
     * expires_date: nil

7. SEED LOADER UPDATES:
   - Update Seeds::Rates.seed_all to load both CA/TRG and NC/INVESTORS

TESTING REQUIREMENTS:
After implementation, these should work:
```ruby
# Current CA rates (existing functionality)
TitleRound.calculate(
  state: "CA",
  underwriter: "TRG", 
  purchase_price: 500_000,
  loan_amount: 400_000
)

# Current NC rates (new functionality)  
TitleRound.calculate(
  state: "NC",
  underwriter: "INVESTORS",
  purchase_price: 500_000, 
  loan_amount: 400_000
)

# Verify rates are different between CA and NC
# (NC rates should be ~10% different for easy verification)
```

CLI should work:
```bash
title-round calculate --state CA --underwriter TRG --purchase-price 500000 --loan-amount 400000
title-round calculate --state NC --underwriter INVESTORS --purchase-price 500000 --loan-amount 400000
```

CONSTRAINTS:
- Do NOT change the core calculation logic (10K rounding, concurrent discounts, etc.)
- Do NOT change the output format (ClosingDisclosure should work as-is)
- Maintain backwards compatibility where possible
- Add columns directly to existing tables (state_code, underwriter_code, etc.) - do NOT create separate rate_schedules or reference tables
- Keep the denormalized structure for now - state/underwriter stored as strings on every row
- Date-based filtering is implemented but not heavily tested yet (Phase 2 will add multiple versions)

DELIVERABLES:
1. Updated schema with new columns and indexes
2. Updated models with jurisdiction filtering
3. Updated calculator with required state/underwriter parameters
4. Updated CLI with new flags
5. Updated seeds with CA/TRG data plus dummy NC/INVESTORS data
6. Update the README file to reflect new parameters

Please implement these changes systematically, testing each component before moving to the next.
Start with schema, then models, then calculator, then CLI, then seeds.