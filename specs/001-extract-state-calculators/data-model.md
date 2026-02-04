# Data Model: Extract State Calculators into Plugin Architecture

**Date**: 2026-02-03
**Branch**: `001-extract-state-calculators`

## Overview

This refactor does not introduce new data entities. It restructures existing calculator classes into a plugin architecture. This document maps the existing entities and their relationships in the new structure.

## Entities

### 1. BaseStateCalculator (NEW - Abstract)

**Purpose**: Defines the contract all state calculators must implement.

**Attributes**: None (stateless abstract class)

**Methods**:
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `calculate_owners_premium` | `params` (Hash) | Integer (cents) | Calculate owner's policy premium |
| `calculate_lenders_premium` | `params` (Hash) | Integer (cents) | Calculate lender's policy premium |

**Relationships**:
- Parent of: `States::AZ`, `States::FL`, `States::CA`, `States::TX`, `States::NC`
- Uses: `Utilities::Rounding`, `Utilities::TierLookup`

---

### 2. State Calculator (States::XX) (NEW - Concrete)

**Purpose**: State-specific implementation of rate calculation logic.

**Instances**: `States::AZ`, `States::FL`, `States::CA`, `States::TX`, `States::NC`

**Attributes**: None (stateless singletons)

**State-Specific Methods** (beyond contract):

| State | Additional Methods | Description |
|-------|-------------------|-------------|
| AZ | `calculate_hold_open_premium` | Hold-open initial/final calculations |
| AZ | `region_for_county`, `area_for_county` | Geographic lookup |
| FL | `calculate_with_reissue_rate_table` | Split rate table calculation |
| NC | `calculate_reissue_discount` | Percentage-based discount |

**Relationships**:
- Inherits: `BaseStateCalculator`
- Reads: `STATE_RULES` configuration
- Queries: `RateTier`, `CPLRate`, `Endorsement` models

---

### 3. StateCalculatorFactory (NEW)

**Purpose**: Routes state codes to correct calculator instance with caching.

**Attributes**:
| Attribute | Type | Description |
|-----------|------|-------------|
| `@calculators` | Hash | Cached calculator instances by state code |

**Methods**:
| Method | Parameters | Returns | Description |
|--------|------------|---------|-------------|
| `for` | `state_code` (String) | StateCalculator | Get/create cached calculator |
| `reset!` | None | None | Clear cache (for testing) |

**Relationships**:
- Creates: All state calculator instances
- Raises: `UnsupportedStateError` for unknown states

---

### 4. Utilities::Rounding (NEW - Module)

**Purpose**: Pure functions for premium rounding operations.

**Functions**:
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `round_up` | `amount_cents`, `increment_cents` | Integer | Round up to next increment |
| `round_to_nearest` | `amount_cents`, `increment_cents` | Integer | Round to nearest increment |

**Usage By**:
- `States::AZ` (TRG: $5k, ORT: $20k increments)
- `States::CA`, `States::FL`, `States::NC` (default $10k increments)
- `States::TX` (no rounding - passes through)

---

### 5. Utilities::TierLookup (NEW - Module)

**Purpose**: Pure functions for tiered rate table traversal.

**Functions**:
| Function | Parameters | Returns | Description |
|----------|------------|---------|-------------|
| `calculate_tiered_rate` | `amount_cents`, `tiers` | Integer | Sum per-thousand across tiers |
| `find_bracket` | `amount_cents`, `tiers` | Hash | Single bracket lookup |

**Usage By**:
- `States::FL`, `States::NC` (tiered per-thousand rates)
- `States::CA` (bracket lookup, $3M+ formula)

---

### 6. Calculation Parameters (Hash Structure)

**Purpose**: Standard input structure for calculator methods.

**Fields**:
| Field | Type | Required | Used By |
|-------|------|----------|---------|
| `liability_cents` | Integer | Yes | All states |
| `loan_amount_cents` | Integer | For lenders | All states |
| `policy_type` | String | Yes | All states |
| `underwriter` | String | Yes | All states |
| `transaction_type` | String | Yes | All states |
| `as_of_date` | Date | Yes | All states |
| `prior_policy_amount_cents` | Integer | No | FL, NC (reissue) |
| `prior_policy_date` | Date | No | FL, NC (reissue) |
| `county` | String | No | AZ (region/area) |
| `concurrent` | Boolean | No | All states (lender calc) |
| `is_hold_open` | Boolean | No | AZ only |
| `hold_open_phase` | String | No | AZ only ("initial"/"final") |

---

## Existing Entities (Unchanged)

### RateTier
- Rate tier data model for database lookups
- **Change**: TX formula logic moves to `States::TX`

### CPLRate
- CPL rate tier model
- **Change**: None (called by state calculators)

### Endorsement
- Endorsement pricing model
- **Change**: None

### PolicyType
- Policy type multiplier lookup
- **Change**: None (called by state calculators)

### STATE_RULES (Configuration Hash)
- Frozen hash in `state_rules.rb`
- **Change**: None (read by state calculators)

---

## Entity Relationship Diagram

```
┌─────────────────────────┐
│ StateCalculatorFactory  │
│  .for(state_code)       │
└───────────┬─────────────┘
            │ creates/caches
            ▼
┌─────────────────────────┐
│  BaseStateCalculator    │◄──────────────────────────────┐
│  (abstract contract)    │                               │
└───────────┬─────────────┘                               │
            │ inherits                                    │ uses
            ▼                                             │
┌─────────────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐
│  │States::AZ│ │States::FL│ │States::CA│ │States::TX│ │States::NC│
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘
└───────┼──────────┼──────────┼──────────┼──────────┼──────┘
        │          │          │          │          │
        │          │          │          │          │
        ▼          ▼          ▼          ▼          ▼
┌─────────────────────────────────────────────────────────────┐
│                     Shared Resources                         │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │Utilities::Rounding│  │Utilities::TierLookup│  │STATE_RULES│ │
│  └──────────────────┘  └──────────────────┘  └────────────┘ │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │     RateTier     │  │     CPLRate      │  │ Endorsement│ │
│  └──────────────────┘  └──────────────────┘  └────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## State Transitions

Not applicable - calculators are stateless. Each call to `calculate_*` is independent.

---

## Validation Rules

### Factory Validation
- State code MUST be normalized to uppercase before lookup
- Unknown state codes MUST raise `UnsupportedStateError`

### Parameter Validation (within state calculators)
- `liability_cents` MUST be a positive integer
- `policy_type` MUST be one of: "standard", "homeowners", "extended"
- `underwriter` MUST be valid for the state (per `STATE_RULES`)
- `as_of_date` MUST be a valid Date object

### Contract Enforcement
- Calling abstract methods on `BaseStateCalculator` directly MUST raise `NotImplementedError`
- All state calculators MUST implement both required contract methods
