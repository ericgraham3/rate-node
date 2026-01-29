# frozen_string_literal: true

require "date"

module RateNode
  module Calculators
    class BaseRate
      DEFAULT_ROUNDING_INCREMENT = 1_000_000  # $10,000 in cents

      attr_reader :liability_cents, :state, :underwriter, :as_of_date, :rate_table

      def initialize(liability_cents, state:, underwriter:, as_of_date: Date.today, rate_table: "original")
        @liability_cents = liability_cents
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
        @rate_table = rate_table
      end

      def state_rules
        @state_rules ||= RateNode.rules_for(state)
      end

      def calculate
        rate = Models::RateTier.calculate_rate(
          rounded_liability,
          state: state,
          underwriter: underwriter,
          as_of_date: as_of_date,
          rate_table: rate_table
        )
        apply_minimum_premium(rate)
      end

      def calculate_elc
        Models::RateTier.calculate_extended_lender_concurrent_rate(rounded_liability, state: state, underwriter: underwriter, as_of_date: as_of_date)
      end

      def rounded_liability
        # Some states (e.g., TX) do not round liabilities
        return @liability_cents unless state_rules[:rounds_liability]

        increment = state_rules[:rounding_increment_cents] || DEFAULT_ROUNDING_INCREMENT
        return @liability_cents if (@liability_cents % increment).zero?

        # Always round UP
        ((@liability_cents / increment) + 1) * increment
      end

      private

      def apply_minimum_premium(rate)
        minimum = state_rules[:minimum_premium_cents] || 0
        [rate, minimum].max
      end
    end
  end
end
