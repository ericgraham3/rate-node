# frozen_string_literal: true

module RateNode
  # Centralized state-specific constants for easy addition of new states.
  # To add a new state, copy an existing state block and adjust values.
  #
  # Structure:
  #   State-level keys (shared across underwriters):
  #     has_cpl                      - Whether state has CPL at all
  #     cpl_flat_fee_cents           - Flat CPL fee (nil = use tiered rates from database)
  #     supports_property_type       - Whether endorsement pricing varies by property type
  #
  #   Underwriter-level keys (nested under underwriters: { "CODE" => { ... } }):
  #     concurrent_base_fee_cents    - Flat fee for concurrent lender's policy
  #     concurrent_uses_elc          - true: use ELC rate for excess, false: use full base rate
  #     reissue_discount_percent     - Discount percentage for reissue (0.0 = no discount)
  #     reissue_eligibility_years    - Years prior policy valid for reissue (nil = not eligible)
  #     rounds_liability             - Whether to round liability
  #     rounding_increment_cents     - Amount to round to (default 1_000_000 = $10,000)
  #     has_reissue_rate_table       - Whether state has separate reissue rate table (FL)
  #     minimum_premium_cents        - Minimum premium for any policy
  #     policy_type_multipliers      - Multipliers for policy types (standard, homeowners, extended)
  #
  STATE_RULES = {
    "CA" => {
      # State-level (shared)
      has_cpl: true,
      cpl_flat_fee_cents: 0,
      supports_property_type: false,

      # Underwriters
      underwriters: {
        "TRG" => {
          concurrent_base_fee_cents: 15_000,        # $150
          concurrent_uses_elc: true,
          reissue_discount_percent: 0.0,
          reissue_eligibility_years: nil,
          rounds_liability: true,
          rounding_increment_cents: 1_000_000,      # $10,000
          has_reissue_rate_table: false,
          minimum_premium_cents: 60_900,             # $609 (TRG rate manual line 36)
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.10,
            extended: 1.25
          },
          # Standalone lender policy multipliers (TRG CA rate manual pp. 182-184)
          standalone_lender_standard_percent: 80.0,
          standalone_lender_extended_percent: 90.0,
          # Concurrent Standard excess percentage (TRG CA rate manual pp. 203-206)
          concurrent_standard_excess_percent: 80.0,
          # Hold-open / binder support (TRG CA rate manual Section 1.2)
          supports_hold_open: true,
          hold_open_surcharge_percent: 0.10,        # 10% of base rate (OR Schedule)
          hold_open_eligibility_years: 2,
          # Over-$3M owner premium formula (TRG rate manual line 65)
          over_3m_base_cents: 421_100,               # $4,211
          over_3m_per_10k_cents: 525,                # $5.25 per $10K increment
          # ELC over-$3M formula (TRG rate manual, clarification)
          elc_over_3m_base_cents: 247_200,           # $2,472
          elc_over_3m_per_10k_cents: 420,            # $4.20 per $10K increment
          # Refinance over-$10M formula (TRG rate manual line 298)
          refinance_over_10m_base_cents: 720_000,    # $7,200
          refinance_over_10m_per_million_cents: 80_000 # $800 per million
        },
        "ORT" => {
          concurrent_base_fee_cents: 15_000,        # $150
          concurrent_uses_elc: true,
          reissue_discount_percent: 0.0,
          reissue_eligibility_years: nil,
          rounds_liability: true,
          rounding_increment_cents: 1_000_000,      # $10,000
          has_reissue_rate_table: false,
          minimum_premium_cents: 72_500,             # $725 (ORT rate manual line 37)
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.10,
            extended: 1.25
          },
          # Standalone lender policy multipliers (ORT CA rate manual pp. 258-262)
          standalone_lender_standard_percent: 75.0,
          standalone_lender_extended_percent: 85.0,
          # Concurrent Standard excess percentage (ORT CA rate manual pp. 293-298)
          concurrent_standard_excess_percent: 75.0,
          # Hold-open / binder support (ORT CA rate manual Section 1.2)
          supports_hold_open: true,
          hold_open_surcharge_percent: 0.10,        # 10% of OR Insurance Rate
          hold_open_eligibility_years: 2,
          # Over-$3M owner premium formula (ORT rate manual line 75)
          over_3m_base_cents: 443_800,               # $4,438
          over_3m_per_10k_cents: 600,                # $6.00 per $10K increment
          # ELC over-$3M formula (ORT rate manual line 327)
          elc_over_3m_base_cents: 255_000,           # $2,550
          elc_over_3m_per_10k_cents: 300,            # $3.00 per $10K increment
          # Refinance over-$10M formula (ORT rate manual Section 2.3)
          refinance_over_10m_base_cents: 761_000,    # $7,610
          refinance_over_10m_per_million_cents: 100_000 # $1,000 per million
        },
        "DEFAULT" => {
          concurrent_base_fee_cents: 15_000,        # $150
          concurrent_uses_elc: true,
          reissue_discount_percent: 0.0,
          reissue_eligibility_years: nil,
          rounds_liability: true,
          rounding_increment_cents: 1_000_000,      # $10,000
          has_reissue_rate_table: false,
          minimum_premium_cents: 0,
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.10,
            extended: 1.25
          }
        }
      }
    },
    "NC" => {
      # State-level (shared)
      has_cpl: true,
      cpl_flat_fee_cents: nil,                      # Uses tiered rates
      supports_property_type: false,

      # Underwriters
      underwriters: {
        "DEFAULT" => {
          concurrent_base_fee_cents: 2_850,         # $28.50
          concurrent_uses_elc: true,
          reissue_discount_percent: 0.50,           # 50%
          reissue_eligibility_years: 15,
          rounds_liability: true,
          rounding_increment_cents: 100_000,        # $1,000 (per NC rate manual PR-1)
          has_reissue_rate_table: false,
          minimum_premium_cents: 5_600,             # $56.00 (per NC rate manual PR-1)
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.20,
            extended: 1.20
          }
        }
      }
    },
    "TX" => {
      # State-level (shared)
      has_cpl: false,
      cpl_flat_fee_cents: nil,
      supports_property_type: false,

      # Underwriters
      underwriters: {
        "DEFAULT" => {
          concurrent_base_fee_cents: 10_000,        # $100
          concurrent_uses_elc: false,               # TX uses full base rate for excess
          reissue_discount_percent: 0.0,
          reissue_eligibility_years: nil,
          rounds_liability: false,                  # TX uses exact amounts
          rounding_increment_cents: nil,
          has_reissue_rate_table: false,
          minimum_premium_cents: 0,
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.10,
            extended: 1.25
          }
        }
      }
    },
    "FL" => {
      # State-level (shared)
      has_cpl: false,
      cpl_flat_fee_cents: nil,
      supports_property_type: true,                 # 1-4 family vs commercial affects endorsements

      # Underwriters
      underwriters: {
        "DEFAULT" => {
          concurrent_base_fee_cents: 2_500,         # $25 minimum
          concurrent_uses_elc: true,
          reissue_discount_percent: 0.0,            # FL uses separate rate table instead
          reissue_eligibility_years: 3,             # 3 years for reissue rate table
          rounds_liability: true,
          rounding_increment_cents: 10_000,         # $100 (FL rounds to nearest $100)
          has_reissue_rate_table: true,             # FL has separate reissue rate table
          minimum_premium_cents: 10_000,            # $100 minimum premium
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.10,
            extended: 1.25
          }
        }
      }
    },
    "AZ" => {
      # State-level (shared)
      has_cpl: true,
      cpl_flat_fee_cents: 2_500,                    # $25 flat
      supports_property_type: false,

      # Underwriters
      underwriters: {
        "TRG" => {
          concurrent_base_fee_cents: 10_000,        # $100 flat
          concurrent_uses_elc: false,
          rounds_liability: true,
          rounding_increment_cents: 500_000,        # $5,000
          has_reissue_rate_table: false,
          minimum_premium_cents: 0,
          supports_hold_open: true,
          hold_open_fee_percent: 0.25,
          hold_open_minimum_cents: 25_000,          # $250
          hold_open_eligibility_years: 2,
          hold_open_final_per_thousand_cents: 241,  # $2.41/thousand for incremental amount
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.10,
            extended: 1.50
          },
          regions: {
            1 => {
              counties: %w[Apache Cochise Coconino Gila Graham Greenlee Maricopa Navajo Pinal Santa\ Cruz Yavapai Yuma],
              minimum_premium_cents: 73_000
            },
            2 => {
              counties: %w[La\ Paz Mohave Pima],
              minimum_premium_cents: 60_000
            }
          }
        },
        "ORT" => {
          concurrent_base_fee_cents: 10_000,        # $100
          concurrent_uses_elc: false,
          rounds_liability: true,
          rounding_increment_cents: 2_000_000,      # $20,000
          has_reissue_rate_table: false,
          minimum_premium_cents: 0,
          supports_hold_open: false,
          policy_type_multipliers: {
            standard: 1.00,
            homeowners: 1.10,
            extended: 1.50
          },
          areas: {
            1 => {
              counties: %w[Coconino Maricopa Pima Pinal Yavapai],
              minimum_premium_cents: 83_000
            }
          }
        }
      }
    },
  }.freeze

  # Default rules for states not explicitly configured.
  # Falls back to CA-like behavior.
  DEFAULT_STATE_RULES = {
    has_cpl: true,
    cpl_flat_fee_cents: nil,
    supports_property_type: false,
    underwriters: {
      "DEFAULT" => {
        concurrent_base_fee_cents: 15_000,
        concurrent_uses_elc: true,
        reissue_discount_percent: 0.0,
        reissue_eligibility_years: nil,
        rounds_liability: true,
        rounding_increment_cents: 1_000_000,
        has_reissue_rate_table: false,
        minimum_premium_cents: 0,
        policy_type_multipliers: {
          standard: 1.00,
          homeowner: 1.10,
          extended: 1.25
        }
      }
    }
  }.freeze

  def self.rules_for(state, underwriter: nil)
    state_config = STATE_RULES.fetch(state, DEFAULT_STATE_RULES)

    # Handle nested underwriter structure
    return state_config unless state_config.key?(:underwriters)

    effective_underwriter = underwriter || "DEFAULT"
    underwriter_config = state_config.dig(:underwriters, effective_underwriter)

    # Fall back to DEFAULT underwriter if specific one not found
    underwriter_config ||= state_config.dig(:underwriters, "DEFAULT")

    raise Error, "Unknown underwriter #{effective_underwriter} for #{state}" unless underwriter_config

    # Merge state-level with underwriter-level (underwriter takes precedence)
    state_level = state_config.reject { |k, _| k == :underwriters }
    state_level.merge(underwriter_config)
  end
end
