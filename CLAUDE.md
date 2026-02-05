# rate-node Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-03

## Active Technologies
- Ruby 3.4.8 + thor ~> 1.3, sqlite3 ~> 1.6, csv (stdlib) (002-fix-fl-rates)
- SQLite — endorsement rows are seeded from `db/seeds/data/fl_rates.rb` via `Models::Endorsement.seed`; reissue logic lives in the FL calculator (002-fix-fl-rates)

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
- 002-fix-fl-rates: Added Ruby 3.4.8 + thor ~> 1.3, sqlite3 ~> 1.6, csv (stdlib)

- 001-extract-state-calculators: Added Ruby 3.4.8 + sqlite3 ~> 1.6, thor ~> 1.3, csv (stdlib), rspec ~> 3.12

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
