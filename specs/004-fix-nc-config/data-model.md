# Data Model: Fix NC Rate Configuration

**Feature**: 004-fix-nc-config
**Date**: 2026-02-05

## Overview

This feature involves configuration changes only — no new entities or schema changes are required. The affected data structures are documented below for reference.

## Affected Entities

### Endorsement (seed data change)

**Location**: `db/seeds/data/nc_rates.rb`
**Model**: `lib/ratenode/models/endorsement.rb`

**Current NC ENDORSEMENTS** (46 entries):
```ruby
ENDORSEMENTS = [
  { code: "CLTA 100", ... },
  { code: "CLTA 100.1", ... },
  # ... 44 more entries from various state rate manuals
]
```

**Target NC ENDORSEMENTS** (3 entries per PR-10):
```ruby
ENDORSEMENTS = [
  { code: "ALTA 5", name: "Planned Unit Development", pricing_type: "flat", base_amount: 2300 },
  { code: "ALTA 8.1", name: "Environmental Protection Lien (Owner)", pricing_type: "flat", base_amount: 2300 },
  { code: "ALTA 9", name: "Restrictions, Encroachments, Minerals", pricing_type: "flat", base_amount: 2300 }
].freeze
```

**Validation rules**:
- `code` MUST be one of: "ALTA 5", "ALTA 8.1", "ALTA 9"
- `pricing_type` MUST be "flat"
- `base_amount` MUST be 2300 (cents, = $23.00)

---

### PolicyType (constant rename)

**Location**: `lib/ratenode/models/policy_type.rb`

**Current TYPES**:
```ruby
TYPES = {
  standard: { name: "standard", multiplier: 1.00 },
  homeowner: { name: "homeowner", multiplier: 1.10 },  # ← rename
  extended: { name: "extended", multiplier: 1.25 }
}
```

**Target TYPES**:
```ruby
TYPES = {
  standard: { name: "standard", multiplier: 1.00 },
  homeowners: { name: "homeowners", multiplier: 1.10 },  # ← renamed
  extended: { name: "extended", multiplier: 1.25 }
}
```

**Current NC_TYPES**:
```ruby
NC_TYPES = {
  standard: { name: "standard", multiplier: 1.00 },
  homeowner: { name: "homeowner", multiplier: 1.20 },  # ← rename
  extended: { name: "extended", multiplier: 1.20 }
}
```

**Target NC_TYPES**:
```ruby
NC_TYPES = {
  standard: { name: "standard", multiplier: 1.00 },
  homeowners: { name: "homeowners", multiplier: 1.20 },  # ← renamed
  extended: { name: "extended", multiplier: 1.20 }
}
```

---

### StateRules (configuration updates)

**Location**: `lib/ratenode/state_rules.rb`

#### NC Configuration Changes

| Field | Current | Target |
|-------|---------|--------|
| `minimum_premium_cents` | 0 | 5600 |
| `rounding_increment_cents` | 1_000_000 | 100_000 |
| `policy_type_multipliers` key | `:homeowner` | `:homeowners` |

#### Other States (policy_type_multipliers key only)

| State | Line | Current | Target |
|-------|------|---------|--------|
| CA | 44 | `:homeowner` | `:homeowners` |
| TX | 94 | `:homeowner` | `:homeowners` |
| FL | 119 | `:homeowner` | `:homeowners` |
| AZ TRG | 147 | `:homeowners` | (no change) |
| AZ ORT | 171 | `:homeowners` | (no change) |
| DEFAULT | 203 | `:homeowner` | (out of scope) |

---

## State Transitions

N/A — this feature does not introduce any state machines or workflow transitions.

## Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                         Rate Calculation                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Input: policy_type = :homeowners                                │
│                    ↓                                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ PolicyType.multiplier_for(:homeowners, state: "NC")         ││
│  │   1. Check STATE_RULES[:policy_type_multipliers][:homeowners]│
│  │   2. Return 1.20 (NC multiplier)                            ││
│  └─────────────────────────────────────────────────────────────┘│
│                    ↓                                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ BaseRate.calculate × PolicyType.multiplier                  ││
│  │   → Final premium (subject to minimum_premium_cents)        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Database Impact

The endorsements table will be reseeded when `db:seed` is run. After seeding:

```sql
-- NC endorsements count
SELECT COUNT(*) FROM endorsements WHERE state_code = 'NC';
-- Expected: 3 (was: 46)

-- NC endorsement pricing
SELECT code, pricing_type, base_amount_cents FROM endorsements WHERE state_code = 'NC';
-- Expected:
-- ALTA 5    | flat | 2300
-- ALTA 8.1  | flat | 2300
-- ALTA 9    | flat | 2300
```
