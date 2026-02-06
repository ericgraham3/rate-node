# Contract: CA State Rules Configuration Schema
#
# This contract documents the expected structure of CA-specific
# configuration in STATE_RULES hash within lib/ratenode/state_rules.rb
#
# CHANGES IN 007-fix-ca-lender:
# - Add 3 new underwriter-specific configuration keys for lender policy calculations
# - These keys must be nested under underwriters: { "TRG" => {...}, "ORT" => {...} }

module RateNode
  STATE_RULES = {
    "CA" => {
      # State-level (shared across underwriters)
      has_cpl: true,
      cpl_flat_fee_cents: 0,
      supports_property_type: false,

      # Underwriter-specific configuration
      underwriters: {
        "TRG" => {
          # --- EXISTING KEYS (unchanged) ---
          concurrent_base_fee_cents: 15_000,        # $150 flat fee for concurrent Standard
          concurrent_uses_elc: true,                # Use ELC for Extended concurrent
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
          },

          # --- NEW KEYS (007-fix-ca-lender) ---

          # Standalone lender policy multipliers
          # TRG CA rate manual page 182-184:
          # - Standard Coverage (CLTA/ALTA with WRE): 80% of Schedule
          # - Extended Coverage (ALTA without WRE): 90% of Schedule
          standalone_lender_standard_percent: 80.0,   # 80% for TRG Standard standalone
          standalone_lender_extended_percent: 90.0,   # 90% for TRG Extended standalone

          # Concurrent Standard excess calculation percentage
          # TRG CA rate manual page 203-206:
          # "Apply 80% rate to the increased liability portion"
          # Formula: $150 + (80% × [rate(loan) - rate(owner)])
          concurrent_standard_excess_percent: 80.0    # 80% for TRG concurrent excess
        },

        "ORT" => {
          # --- EXISTING KEYS (unchanged) ---
          concurrent_base_fee_cents: 15_000,        # $150 flat fee for concurrent Standard
          concurrent_uses_elc: true,                # Use ELC for Extended concurrent
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
          },

          # --- NEW KEYS (007-fix-ca-lender) ---

          # Standalone lender policy multipliers
          # ORT CA rate manual page 258-262:
          # - Standard Coverage (CLTA/ALTA): 75% of OR Insurance Rate
          # - Extended Coverage (ALTA Extended): 85% of OR Insurance Rate (standard refinance)
          standalone_lender_standard_percent: 75.0,   # 75% for ORT Standard standalone
          standalone_lender_extended_percent: 85.0,   # 85% for ORT Extended standalone

          # Concurrent Standard excess calculation percentage
          # ORT CA rate manual page 293-298:
          # "Apply 75% to the increased liability portion"
          # Formula: $150 + (75% × [rate(loan) - rate(owner)])
          concurrent_standard_excess_percent: 75.0    # 75% for ORT concurrent excess
        },

        "DEFAULT" => {
          # Fallback configuration (not used for CA lender policies)
          # TRG and ORT must have explicit values above
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
            homeowners: 1.10,
            extended: 1.25
          },
          # Note: DEFAULT does NOT have lender-specific percentages
          # Implementation should explicitly check for TRG/ORT and fail if using DEFAULT
        }
      }
    }
  }

  # Usage example from calculator:
  #
  #   rules = rules_for("CA", underwriter: "TRG")
  #
  #   # Standalone Standard lender policy
  #   multiplier = rules[:standalone_lender_standard_percent] / 100.0  # 0.80
  #   premium = (base_rate * multiplier).round
  #
  #   # Concurrent Standard with excess
  #   excess_percent = rules[:concurrent_standard_excess_percent] / 100.0  # 0.80
  #   rate_diff = rate_loan - rate_owner
  #   excess_rate = (rate_diff * excess_percent).round
  #   premium = [concurrent_base_fee, concurrent_base_fee + excess_rate].max
  #
  # Validation rules:
  # - All percentage values must be > 0 and <= 100
  # - TRG and ORT must have explicit values (cannot use DEFAULT)
  # - Keys must be present when calculate_lenders_premium is called
  #   (raise error if missing to fail fast)
end
