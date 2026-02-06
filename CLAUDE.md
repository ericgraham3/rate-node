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
- 007-fix-ca-lender: Added Ruby 3.4.8 + Sequel ORM, thor ~> 1.3, sqlite3 ~> 1.6, rspec ~> 3.12
- 006-explicit-seed-units: Added Ruby 3.4.8 + Sequel ORM, thor ~> 1.3, sqlite3 ~> 1.6
- 005-fix-nc-simul-premium: Added Ruby 3.4.8 + thor ~> 1.3, sqlite3 ~> 1.6, csv (stdlib)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
