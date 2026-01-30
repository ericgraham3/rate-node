# frozen_string_literal: true

require "date"

module RateNode
  module Calculators
    class CPLCalculator
      attr_reader :liability_cents, :state, :underwriter, :as_of_date

      def initialize(liability_cents:, state:, underwriter:, as_of_date: Date.today)
        @liability_cents = liability_cents
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
      end

      def state_rules
        @state_rules ||= RateNode.rules_for(state, underwriter: underwriter)
      end

      def calculate
        # First check if state has CPL at all
        return 0 unless state_rules[:has_cpl]

        case state
        when "CA"
          # CA uses flat fee (currently $0, can be adjusted)
          state_rules[:cpl_flat_fee_cents] || 0
        when "TX"
          # TX does not have CPL
          state_rules[:cpl_flat_fee_cents] || 0
        when "NC"
          # NC uses tiered rate structure
          Models::CPLRate.calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
        when "AZ"
          # AZ uses flat $25 fee
          state_rules[:cpl_flat_fee_cents] || 0
        else
          # Default: use flat fee if defined, otherwise try tiered rates
          return state_rules[:cpl_flat_fee_cents] if state_rules[:cpl_flat_fee_cents]
          Models::CPLRate.calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
        end
      end

      def line_item
        "Closing Protection Letter"
      end
    end
  end
end
