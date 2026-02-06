# rate-node Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-03

## Active Technologies
- Ruby 3.4.8 + thor ~> 1.3, sqlite3 ~> 1.6, csv (stdlib) (002-fix-fl-rates)
- SQLite — endorsement rows are seeded from `db/seeds/data/fl_rates.rb` via `Models::Endorsement.seed`; reissue logic lives in the FL calculator (002-fix-fl-rates)
- SQLite with `rate_tiers` table for tiered rate lookups (003-fix-nc-reissue)
- SQLite with Sequel ORM for rate tier and endorsement lookups (004-fix-nc-config)
- SQLite with Sequel ORM — rate tiers queried via `Models::RateTier.calculate_rate` (005-fix-nc-simul-premium)
- Ruby 3.4.8 + Sequel ORM, thor ~> 1.3, sqlite3 ~> 1.6 (006-explicit-seed-units)
- SQLite database with `rate_tiers` table (006-explicit-seed-units)
- Ruby 3.4.8 + Sequel ORM, thor ~> 1.3, sqlite3 ~> 1.6, rspec ~> 3.12 (007-fix-ca-lender)
- SQLite database with rate_tiers table for tiered rate lookups (007-fix-ca-lender)
- Ruby 3.4.8 + thor ~> 1.3 (CLI), sqlite3 ~> 1.6 (database), sequel (ORM), rspec ~> 3.12 (testing) (008-fix-ca-3m-formulas)
- SQLite database with rate_tiers table for tiered rate lookups; endorsements also seeded in database (008-fix-ca-3m-formulas)

- Ruby 3.4.8 + sqlite3 ~> 1.6, thor ~> 1.3, csv (stdlib), rspec ~> 3.12 (001-extract-state-calculators)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Ruby 3.4.8

## Code Style

Ruby 3.4.8: Follow standard conventions

## Recent Changes
- 008-fix-ca-3m-formulas: Added Ruby 3.4.8 + thor ~> 1.3 (CLI), sqlite3 ~> 1.6 (database), sequel (ORM), rspec ~> 3.12 (testing)
- 007-fix-ca-lender: Added Ruby 3.4.8 + Sequel ORM, thor ~> 1.3, sqlite3 ~> 1.6, rspec ~> 3.12
- 006-explicit-seed-units: Added Ruby 3.4.8 + Sequel ORM, thor ~> 1.3, sqlite3 ~> 1.6


<!-- MANUAL ADDITIONS START -->
## Key Patterns

### Formula Parameters in state_rules.rb
Over-threshold formulas (e.g., over-$3M, over-$10M) are configured as underwriter-specific parameters in `state_rules.rb` rather than hardcoded constants. Access via `RateNode.rules_for(state, underwriter:)`. Parameters follow naming convention: `{formula}_base_cents` and `{formula}_per_{unit}_cents`.

### Minimum Premium
Minimum premium is enforced in both `BaseRate.calculate` (via `apply_minimum_premium`) and in state calculators before policy-type multipliers. The `minimum_premium_cents` value is per-underwriter in `state_rules.rb`.

### CA Over-$3M Formula Pattern
Formula: `base + (ceil(excess / increment_size) * rate_per_increment)`. Used for owner premiums >$3M, ELC >$3M, and refinance >$10M. All use `state_rules` lookup for underwriter-specific parameters.
<!-- MANUAL ADDITIONS END -->
