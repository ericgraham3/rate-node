# frozen_string_literal: true

module RateNode
  # Centralized state-specific constants for easy addition of new states.
  # To add a new state, copy an existing state block and adjust values.
  #
  # Keys:
  #   concurrent_base_fee_cents    - Flat fee for concurrent lender's policy
  #   concurrent_uses_elc          - true: use ELC rate for excess, false: use full base rate
  #   cpl_flat_fee_cents           - Flat CPL fee (nil = use tiered rates from database)
  #   has_cpl                      - Whether state has CPL at all
  #   reissue_discount_percent     - Discount percentage for reissue (0.0 = no discount)
  #   reissue_eligibility_years    - Years prior policy valid for reissue (nil = not eligible)
  #   rounds_liability             - Whether to round liability
  #   rounding_increment_cents     - Amount to round to (default 1_000_000 = $10,000)
  #   has_reissue_rate_table       - Whether state has separate reissue rate table (FL)
  #   supports_property_type       - Whether endorsement pricing varies by property type
  #   minimum_premium_cents        - Minimum premium for any policy
  #
  STATE_RULES = {
    "CA" => {
      concurrent_base_fee_cents: 15_000,        # $150
      concurrent_uses_elc: true,
      cpl_flat_fee_cents: 0,
      has_cpl: true,
      reissue_discount_percent: 0.0,
      reissue_eligibility_years: nil,
      rounds_liability: true,
      rounding_increment_cents: 1_000_000,      # $10,000
      has_reissue_rate_table: false,
      supports_property_type: false,
      minimum_premium_cents: 0,
    },
    "NC" => {
      concurrent_base_fee_cents: 2_850,         # $28.50
      concurrent_uses_elc: true,
      cpl_flat_fee_cents: nil,                  # Uses tiered rates
      has_cpl: true,
      reissue_discount_percent: 0.50,           # 50%
      reissue_eligibility_years: 15,
      rounds_liability: true,
      rounding_increment_cents: 1_000_000,      # $10,000
      has_reissue_rate_table: false,
      supports_property_type: false,
      minimum_premium_cents: 0,
    },
    "TX" => {
      concurrent_base_fee_cents: 10_000,        # $100
      concurrent_uses_elc: false,               # TX uses full base rate for excess
      cpl_flat_fee_cents: nil,
      has_cpl: false,
      reissue_discount_percent: 0.0,
      reissue_eligibility_years: nil,
      rounds_liability: false,                  # TX uses exact amounts
      rounding_increment_cents: nil,
      has_reissue_rate_table: false,
      supports_property_type: false,
      minimum_premium_cents: 0,
    },
    "FL" => {
      concurrent_base_fee_cents: 2_500,         # $25 minimum
      concurrent_uses_elc: true,
      cpl_flat_fee_cents: nil,
      has_cpl: false,
      reissue_discount_percent: 0.0,            # FL uses separate rate table instead
      reissue_eligibility_years: 3,             # 3 years for reissue rate table
      rounds_liability: true,
      rounding_increment_cents: 10_000,         # $100 (FL rounds to nearest $100)
      has_reissue_rate_table: true,             # FL has separate reissue rate table
      supports_property_type: true,             # 1-4 family vs commercial affects endorsements
      minimum_premium_cents: 10_000,            # $100 minimum premium
    },
  }.freeze

  # Default rules for states not explicitly configured.
  # Falls back to CA-like behavior.
  DEFAULT_STATE_RULES = {
    concurrent_base_fee_cents: 15_000,
    concurrent_uses_elc: true,
    cpl_flat_fee_cents: nil,
    has_cpl: true,
    reissue_discount_percent: 0.0,
    reissue_eligibility_years: nil,
    rounds_liability: true,
    rounding_increment_cents: 1_000_000,
    has_reissue_rate_table: false,
    supports_property_type: false,
    minimum_premium_cents: 0,
  }.freeze

  def self.rules_for(state)
    STATE_RULES.fetch(state, DEFAULT_STATE_RULES)
  end
end
