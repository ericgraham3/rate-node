# frozen_string_literal: true

require "date"

module RateNode
  module Calculators
    class Refinance
      attr_reader :loan_amount_cents, :state, :underwriter, :as_of_date

      def initialize(loan_amount_cents:, state:, underwriter:, as_of_date: Date.today)
        @loan_amount_cents = loan_amount_cents
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
      end

      def calculate
        Models::RefinanceRate.calculate_rate(loan_amount_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
      end

      def line_item
        "Lender's Title Insurance (Refinance)"
      end
    end
  end
end
