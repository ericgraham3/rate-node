# Research: Fix NC Rate Configuration

**Feature**: 004-fix-nc-config
**Date**: 2026-02-05

## Research Questions

### RQ-1: Which files contain `homeowner` vs `homeowners` symbols?

**Findings**:

| File | Current Symbol | Change Required |
|------|---------------|-----------------|
| `lib/ratenode/state_rules.rb` (CA, line 44) | `:homeowner` | → `:homeowners` |
| `lib/ratenode/state_rules.rb` (NC, line 69) | `:homeowner` | → `:homeowners` |
| `lib/ratenode/state_rules.rb` (TX, line 94) | `:homeowner` | → `:homeowners` |
| `lib/ratenode/state_rules.rb` (FL, line 119) | `:homeowner` | → `:homeowners` |
| `lib/ratenode/state_rules.rb` (AZ TRG, line 147) | `:homeowners` | No change |
| `lib/ratenode/state_rules.rb` (AZ ORT, line 171) | `:homeowners` | No change |
| `lib/ratenode/state_rules.rb` (DEFAULT, line 203) | `:homeowner` | Out of scope per spec |
| `lib/ratenode/models/policy_type.rb` (TYPES, line 11) | `:homeowner` | → `:homeowners` |
| `lib/ratenode/models/policy_type.rb` (NC_TYPES, line 18) | `:homeowner` | → `:homeowners` |
| `lib/ratenode/calculators/states/ca.rb` (line 127) | `when :homeowner` | → `when :homeowners` |
| `lib/ratenode/calculators/states/fl.rb` (line 219) | `when :homeowner` | → `when :homeowners` |
| `lib/ratenode/calculators/states/nc.rb` (line 164) | `when :homeowner` | → `when :homeowners` |
| `lib/ratenode/calculators/states/tx.rb` (line 128) | `when :homeowner` | → `when :homeowners` |
| `lib/ratenode/calculators/states/az.rb` (line 233) | `when :homeowners` | No change |
| `spec/fixtures/scenarios_input.csv` | `homeowners` | DO NOT MODIFY |

**Decision**: Rename `:homeowner` to `:homeowners` in all state rules (except DEFAULT, out of scope) and in all calculator `format_policy_type` methods.

**Rationale**: AZ CSV fixtures already use `homeowners` and are human-controlled (cannot be modified per Principle V). Standardizing to `homeowners` ensures lookups work correctly.

**Alternatives considered**: Rename AZ to `homeowner` — rejected because CSV fixtures are human-controlled.

---

### RQ-2: What are the correct NC endorsements per rate manual PR-10?

**Findings**:

Per NC rate manual section PR-10, residential policies support exactly three endorsements:

| Code | Name | Pricing | Amount |
|------|------|---------|--------|
| ALTA 5 | Planned Unit Development | Flat | $23.00 |
| ALTA 8.1 | Environmental Protection Lien (Owner) | Flat | $23.00 |
| ALTA 9 | Restrictions, Encroachments, Minerals | Flat | $23.00 |

**Current state**: `db/seeds/data/nc_rates.rb` ENDORSEMENTS array contains 46 entries copied from other states' rate manuals (CLTA 100, CLTA 100.1, ALTA 17, etc.).

**Decision**: Replace the entire ENDORSEMENTS array with exactly 3 entries at $23.00 (2300 cents) flat each.

**Rationale**: NC rate manual PR-10 is the authoritative source. All other endorsements are invalid for NC.

**Edge case**: Requesting a now-removed endorsement (e.g., ALTA 17) must raise an error, not return $0 or nil (per clarification in spec.md).

---

### RQ-3: What are the correct NC minimum premium and rounding values?

**Findings**:

Per NC rate manual section PR-1:

| Setting | Current Value | Correct Value |
|---------|---------------|---------------|
| `minimum_premium_cents` | 0 | 5600 ($56.00) |
| `rounding_increment_cents` | 1_000_000 ($10,000) | 100_000 ($1,000) |

**Decision**: Update NC underwriter config in `state_rules.rb`.

**Rationale**: NC rate manual PR-1 specifies $56.00 minimum and $1,000 rounding.

**Test impact**: All existing NC scenarios use $500,000 liability with `standard` policy type, which is well above both thresholds. Existing tests will not be affected.

**New test requirement**: Per FR-007 and Principle V, new scenarios exercising minimum premium and rounding must have human-provided expected values.

---

### RQ-4: How does the policy type multiplier lookup work?

**Findings**:

From `lib/ratenode/models/policy_type.rb`:

```ruby
def self.multiplier_for(policy_type, state:, underwriter: nil)
  policy_type_sym = policy_type.to_s.to_sym

  # 1. Check database first (allows overrides)
  db_multiplier = from_database(state, policy_type_sym, underwriter)
  return db_multiplier if db_multiplier

  # 2. Fall back to STATE_RULES config
  rules = RateNode.rules_for(state, underwriter: underwriter)
  multipliers = rules[:policy_type_multipliers]
  return multipliers[policy_type_sym] if multipliers&.key?(policy_type_sym)

  # 3. Legacy fallback to constants
  types = state == "NC" ? NC_TYPES : TYPES
  types.dig(policy_type_sym, :multiplier) || 1.0
end
```

**Key insight**: The lookup converts the input to a symbol and checks:
1. Database (not used in current implementation)
2. `STATE_RULES[:policy_type_multipliers]` hash
3. Legacy `TYPES` or `NC_TYPES` constants

If `homeowners` is requested but only `:homeowner` exists in the hash, the lookup fails and falls through to the 1.0 default — a silent error.

**Decision**: Ensure all lookup paths use `:homeowners` consistently.

---

### RQ-5: What happens when a removed endorsement is requested?

**Findings**:

From `lib/ratenode/models/endorsement.rb`:

```ruby
def self.find_by_code(state:, code:, underwriter: "TRG", effective_date: Date.today)
  # Returns nil if not found
  DB[:endorsements].where(
    state_code: state,
    code: code,
    underwriter_code: underwriter
  ).where { effective_date <= Sequel.cast(effective_date, Date) }
   .order(Sequel.desc(:effective_date))
   .first
end
```

The method returns `nil` when an endorsement is not found. Per spec clarification, callers must treat `nil` as an error condition — silent $0 returns are explicitly prohibited.

**Decision**: No code change needed for endorsement lookup behavior. The fix is to remove invalid endorsements from the seed data. Callers requesting removed endorsements will get `nil` and must raise an error.

**Note**: If the calculator currently handles `nil` by defaulting to $0, that is a separate bug to address.

---

## Summary of Decisions

| Area | Decision | Files Affected |
|------|----------|----------------|
| Policy type symbol | Rename `:homeowner` → `:homeowners` in 4 states + 2 constants | `state_rules.rb`, `policy_type.rb`, 4 calculator files |
| NC endorsements | Replace 46 entries with 3 valid entries at $23.00 flat | `nc_rates.rb` |
| NC minimum premium | Change from 0 to 5600 cents | `state_rules.rb` |
| NC rounding increment | Change from 1_000_000 to 100_000 cents | `state_rules.rb` |
| DEFAULT_STATE_RULES | Out of scope per spec | N/A |

All NEEDS CLARIFICATION items have been resolved.
