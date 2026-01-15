# frozen_string_literal: true

require "date"

module TitleRound
  module Calculators
    class CPLCalculator
      # CA flat fee for CPL (if not using tiered rates)
      CA_FLAT_FEE_CENTS = 0

      attr_reader :liability_cents, :state, :underwriter, :as_of_date

      def initialize(liability_cents:, state:, underwriter:, as_of_date: Date.today)
        @liability_cents = liability_cents
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
      end

      def calculate
        case state
        when "CA"
          # CA uses flat fee (currently $0, can be adjusted)
          CA_FLAT_FEE_CENTS
        when "TX"
          # TX does not have CPL
          0
        when "NC"
          # NC uses tiered rate structure
          Models::CPLRate.calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
        else
          # Default: try tiered rates, fall back to 0
          Models::CPLRate.calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
        end
      end

      def line_item
        "Closing Protection Letter"
      end
    end
  end
end
