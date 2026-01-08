-- TRG Title Premium Calculator Schema

-- Schedule of Rates (base rates for all policies)
CREATE TABLE IF NOT EXISTS rate_tiers (
  id INTEGER PRIMARY KEY,
  min_liability_cents INTEGER NOT NULL,
  max_liability_cents INTEGER,
  base_rate_cents INTEGER NOT NULL,
  per_thousand_cents INTEGER,
  extended_lender_concurrent_cents INTEGER,
  state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
  underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
  effective_date DATE NOT NULL DEFAULT '2024-01-01',
  expires_date DATE
);

CREATE INDEX IF NOT EXISTS idx_rate_tiers_liability ON rate_tiers(min_liability_cents, max_liability_cents);
CREATE INDEX IF NOT EXISTS idx_rate_tiers_jurisdiction ON rate_tiers(state_code, underwriter_code, effective_date);

-- Refinance flat rates (1-4 family residential)
CREATE TABLE IF NOT EXISTS refinance_rates (
  id INTEGER PRIMARY KEY,
  min_liability_cents INTEGER NOT NULL,
  max_liability_cents INTEGER,
  flat_rate_cents INTEGER NOT NULL,
  state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
  underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
  effective_date DATE NOT NULL DEFAULT '2024-01-01',
  expires_date DATE
);

CREATE INDEX IF NOT EXISTS idx_refinance_rates_liability ON refinance_rates(min_liability_cents, max_liability_cents);
CREATE INDEX IF NOT EXISTS idx_refinance_rates_jurisdiction ON refinance_rates(state_code, underwriter_code, effective_date);

-- Endorsements catalog
CREATE TABLE IF NOT EXISTS endorsements (
  id INTEGER PRIMARY KEY,
  code VARCHAR(20) NOT NULL,
  name VARCHAR(255) NOT NULL,
  pricing_type VARCHAR(20) NOT NULL,
  base_amount_cents INTEGER,
  percentage DECIMAL(8,6),
  min_cents INTEGER,
  max_cents INTEGER,
  concurrent_discount_pct INTEGER,
  owner_only INTEGER DEFAULT 0,
  lender_only INTEGER DEFAULT 0,
  notes TEXT,
  state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
  underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
  effective_date DATE NOT NULL DEFAULT '2024-01-01',
  expires_date DATE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_endorsements_code_jurisdiction ON endorsements(code, state_code, underwriter_code, effective_date);
CREATE INDEX IF NOT EXISTS idx_endorsements_jurisdiction ON endorsements(state_code, underwriter_code, effective_date);

-- Policy type multipliers
CREATE TABLE IF NOT EXISTS policy_types (
  id INTEGER PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  multiplier DECIMAL(4,2) NOT NULL,
  state_code VARCHAR(2) NOT NULL DEFAULT 'CA',
  underwriter_code VARCHAR(50) NOT NULL DEFAULT 'TRG',
  effective_date DATE NOT NULL DEFAULT '2024-01-01',
  expires_date DATE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_policy_types_unique ON policy_types(name, state_code, underwriter_code, effective_date);
CREATE INDEX IF NOT EXISTS idx_policy_types_jurisdiction ON policy_types(state_code, underwriter_code, effective_date);

-- Closing Protection Letter (CPL) / Closing Services Insurance rates
CREATE TABLE IF NOT EXISTS cpl_rates (
  id INTEGER PRIMARY KEY,
  state_code VARCHAR(2) NOT NULL,
  underwriter_code VARCHAR(50) NOT NULL,
  min_liability_cents INTEGER NOT NULL,
  max_liability_cents INTEGER,
  rate_per_thousand_cents INTEGER NOT NULL,
  effective_date DATE NOT NULL DEFAULT '2024-01-01',
  expires_date DATE
);

CREATE INDEX IF NOT EXISTS idx_cpl_rates_lookup ON cpl_rates(state_code, underwriter_code, min_liability_cents, effective_date);
CREATE INDEX IF NOT EXISTS idx_cpl_rates_jurisdiction ON cpl_rates(state_code, underwriter_code, effective_date);
