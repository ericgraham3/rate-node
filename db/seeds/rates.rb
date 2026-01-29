# frozen_string_literal: true

require "date"
require_relative "data/ca_rates"
require_relative "data/nc_rates"
require_relative "data/tx_rates"
require_relative "data/fl_rates"

module RateNode
  module Seeds
    class Rates
      def self.seed_all
        seed_ca
        seed_nc
        seed_tx
        seed_fl
      end

      # California - TRG
      def self.seed_ca
        state = CA

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
        # Detect if data is already in cents (TX format) vs dollars (CA/NC format)
        # TX data has min values like 2_500_000 (already cents for $25,000)
        # CA/NC data has min values like 0, 20_000 (dollars that need conversion)
        already_in_cents = state::RATE_TIERS.first && state::RATE_TIERS.first[:min] >= 100_000

        schedule_data = if already_in_cents
          # TX format - data is already in cents
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
          # CA/NC format - convert dollars to cents
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
    end
  end
end
