# frozen_string_literal: true

require "date"
require_relative "data/ca_rates"
require_relative "data/ca_ort_rates"
require_relative "data/nc_rates"
require_relative "data/tx_rates"
require_relative "data/fl_rates"
require_relative "data/az_rates"

module RateNode
  module Seeds
    class Rates
      def self.seed_all
        seed_ca
        seed_nc
        seed_tx
        seed_fl
        seed_az
      end

      # California - TRG and ORT underwriters
      def self.seed_ca
        seed_ca_trg
        seed_ca_ort
      end

      # California - TRG
      def self.seed_ca_trg
        state = CA

        seed_rate_tiers(state, rate_type: "premium")
        seed_refinance_rates(state)
        seed_policy_types(state)
        seed_endorsements(state)
        seed_cpl_rates(state)
      end

      # California - ORT
      def self.seed_ca_ort
        state = CA_ORT

        seed_rate_tiers(state, rate_type: "premium")
        seed_refinance_rates(state)
        seed_policy_types(state)
        seed_endorsements(state)
        seed_cpl_rates(state)
      end

      # North Carolina - TRG
      def self.seed_nc
        state = NC

        seed_rate_tiers(state, rate_type: "premium")
        seed_refinance_rates(state)
        seed_policy_types(state)
        seed_endorsements(state)
        seed_cpl_rates(state)
      end

      # Texas - DEFAULT (Promulgated Rates)
      def self.seed_tx
        state = TX

        # TX uses both 'basic' and 'premium' rate types (same values)
        seed_rate_tiers(state, rate_type: "basic")
        seed_rate_tiers(state, rate_type: "premium")
        seed_policy_types(state)
        seed_endorsements(state)
        # TX has no refinance rates or CPL
      end

      # Florida - TRG
      def self.seed_fl
        state = FL

        # FL uses separate original and reissue rate tables
        seed_fl_rate_tiers(state)
        seed_refinance_rates(state)
        seed_policy_types(state)
        seed_endorsements(state)
        # FL has no CPL
      end

      private

      # FL-specific: seed both original and reissue rate tables
      def self.seed_fl_rate_tiers(state)
        # Original rate table
        original_data = state::RATE_TIERS_ORIGINAL.map do |row|
          {
            min: row[:min],
            max: row[:max],
            base: row[:base],
            per_thousand: row[:per_thousand],
            elc: row[:elc] || 0
          }
        end

        Models::RateTier.seed(
          original_data,
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil,
          rate_type: "premium",
          rate_table: "original"
        )

        # Reissue rate table
        reissue_data = state::RATE_TIERS_REISSUE.map do |row|
          {
            min: row[:min],
            max: row[:max],
            base: row[:base],
            per_thousand: row[:per_thousand],
            elc: row[:elc] || 0
          }
        end

        Models::RateTier.seed(
          reissue_data,
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil,
          rate_type: "premium",
          rate_table: "reissue"
        )
      end

      def self.seed_rate_tiers(state, rate_type: nil)
        # Read explicit unit declaration (required)
        unless state.const_defined?(:RATE_TIERS_UNIT)
          raise ArgumentError, "#{state}::RATE_TIERS_UNIT must be declared (:dollars or :cents)"
        end

        unit = state::RATE_TIERS_UNIT
        unless [:dollars, :cents].include?(unit)
          raise ArgumentError, "#{state}::RATE_TIERS_UNIT must be :dollars or :cents, got #{unit.inspect}"
        end

        schedule_data = if unit == :cents
          # Data is already in cents (TX format) - pass through unchanged
          state::RATE_TIERS.map do |row|
            {
              min: row[:min],
              max: row[:max],
              base: row[:base],
              per_thousand: row[:per_thousand],
              elc: row[:elc] || 0
            }
          end
        else
          # Data is in dollars (CA/NC format) - convert to cents
          state::RATE_TIERS.map do |row|
            {
              min: row[:min] * 100,
              max: row[:max] ? row[:max] * 100 : nil,
              base: row[:rate] ? row[:rate] * 100 : (row[:base] || 0),
              per_thousand: row[:per_thousand],
              elc: row[:elc] ? row[:elc] * 100 : 0
            }
          end
        end

        Models::RateTier.seed(
          schedule_data,
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil,
          rate_type: rate_type
        )
      end

      def self.seed_refinance_rates(state)
        return if state::REFINANCE_RATES.empty?

        data = state::REFINANCE_RATES.map do |row|
          {
            min: row[:min] * 100,
            max: row[:max] ? row[:max] * 100 : nil,
            rate: row[:rate] * 100
          }
        end

        Models::RefinanceRate.seed(
          data,
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil
        )
      end

      def self.seed_policy_types(state)
        Models::PolicyType.seed(
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil
        )
      end

      def self.seed_endorsements(state)
        Models::Endorsement.seed(
          state::ENDORSEMENTS,
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil
        )
      end

      def self.seed_cpl_rates(state)
        return if state::CPL_RATES.empty?

        Models::CPLRate.seed(
          state::CPL_RATES,
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil
        )
      end

      # Arizona - TRG and ORT underwriters
      def self.seed_az
        seed_az_trg
        seed_az_ort
      end

      def self.seed_az_trg
        state = AZ_TRG

        # Seed TRG Region 1 rates (default)
        seed_az_rate_tiers(state, state::RATE_TIERS_REGION_1, region: 1)
        # Seed TRG Region 2 rates
        seed_az_rate_tiers(state, state::RATE_TIERS_REGION_2, region: 2)

        seed_endorsements(state)
      end

      def self.seed_az_ort
        state = AZ_ORT

        seed_az_rate_tiers(state, state::RATE_TIERS)
        seed_endorsements(state)
      end

      def self.seed_az_rate_tiers(state, rate_tiers, region: nil)
        # AZ data is already in cents
        schedule_data = rate_tiers.map do |row|
          {
            min: row[:min],
            max: row[:max],
            base: row[:base],
            per_thousand: row[:per_thousand],
            elc: row[:elc] || 0
          }
        end

        # For region-specific rates, append region to rate_table
        rate_table = region ? "original_region_#{region}" : "original"

        Models::RateTier.seed(
          schedule_data,
          state_code: state::STATE_CODE,
          underwriter_code: state::UNDERWRITER_CODE,
          effective_date: state::EFFECTIVE_DATE,
          expires_date: nil,
          rate_type: "premium",
          rate_table: rate_table
        )
      end
    end
  end
end
