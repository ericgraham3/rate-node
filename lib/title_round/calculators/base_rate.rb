# frozen_string_literal: true

require "date"

module TitleRound
  module Calculators
    class BaseRate
      TEN_THOUSAND_CENTS = 1_000_000

      attr_reader :liability_cents, :state, :underwriter, :as_of_date

      def initialize(liability_cents, state:, underwriter:, as_of_date: Date.today)
        @liability_cents = liability_cents
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
      end

      def calculate
        Models::RateTier.calculate_rate(rounded_liability, state: state, underwriter: underwriter, as_of_date: as_of_date)
      end

      def calculate_elc
        Models::RateTier.calculate_extended_lender_concurrent_rate(rounded_liability, state: state, underwriter: underwriter, as_of_date: as_of_date)
      end

      def rounded_liability
        # TX does not round liabilities (uses exact amounts)
        return @liability_cents if state == "TX"

        return @liability_cents if (@liability_cents % TEN_THOUSAND_CENTS).zero?

        ((@liability_cents / TEN_THOUSAND_CENTS) + 1) * TEN_THOUSAND_CENTS
      end
    end
  end
end
