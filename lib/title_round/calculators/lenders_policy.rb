# frozen_string_literal: true

require "date"

module TitleRound
  module Calculators
    class LendersPolicy
      # CA concurrent fee: $150
      CA_CONCURRENT_BASE_FEE_CENTS = 15_000
      # NC concurrent fee: $28.50
      NC_CONCURRENT_BASE_FEE_CENTS = 2_850

      attr_reader :loan_amount_cents, :owner_liability_cents, :concurrent, :state, :underwriter, :as_of_date

      def initialize(loan_amount_cents:, owner_liability_cents: nil, concurrent: false, state:, underwriter:, as_of_date: Date.today)
        @loan_amount_cents = loan_amount_cents
        @owner_liability_cents = owner_liability_cents
        @concurrent = concurrent
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
      end

      def calculate
        return calculate_standalone unless concurrent

        calculate_concurrent
      end

      def concurrent?
        concurrent && owner_liability_cents
      end

      def line_item
        concurrent? ? "Lender's Title Insurance (Concurrent)" : "Lender's Title Insurance"
      end

      private

      def calculate_standalone
        BaseRate.new(loan_amount_cents, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate
      end

      def calculate_concurrent
        case state
        when "NC"
          # NC: Always $28.50 flat fee when concurrent, regardless of loan vs owner amount
          NC_CONCURRENT_BASE_FEE_CENTS
        when "CA"
          # CA: $150 if loan <= owner, or $150 + ELC if loan > owner
          return CA_CONCURRENT_BASE_FEE_CENTS if loan_amount_cents <= owner_liability_cents
          calculate_increased_liability
        else
          # Default to CA logic for unknown states
          return CA_CONCURRENT_BASE_FEE_CENTS if loan_amount_cents <= owner_liability_cents
          calculate_increased_liability
        end
      end

      def calculate_increased_liability
        excess = loan_amount_cents - owner_liability_cents
        elc_rate = BaseRate.new(excess, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate_elc
        CA_CONCURRENT_BASE_FEE_CENTS + elc_rate
      end
    end
  end
end
