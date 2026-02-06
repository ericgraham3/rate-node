# frozen_string_literal: true

require "date"

module RateNode
  module Calculators
    class LendersPolicy
      attr_reader :loan_amount_cents, :owner_liability_cents, :concurrent, :state, :underwriter, :as_of_date, :lender_policy_type

      def initialize(loan_amount_cents:, owner_liability_cents: nil, concurrent: false, state:, underwriter:, as_of_date: Date.today, lender_policy_type: :standard)
        @loan_amount_cents = loan_amount_cents
        @owner_liability_cents = owner_liability_cents
        @concurrent = concurrent
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
        @lender_policy_type = lender_policy_type.to_sym
      end

      def state_rules
        @state_rules ||= RateNode.rules_for(state, underwriter: underwriter)
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
        base_rate = BaseRate.new(loan_amount_cents, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate

        # CA: apply underwriter-specific multiplier for standalone lender policies
        if state == "CA"
          multiplier_key = lender_policy_type == :extended ?
            :standalone_lender_extended_percent :
            :standalone_lender_standard_percent
          multiplier = state_rules[multiplier_key]
          return (base_rate * multiplier / 100.0).round if multiplier
        end

        base_rate
      end

      def calculate_concurrent
        # CA Extended concurrent: full ELC rate lookup on loan amount
        if state == "CA" && lender_policy_type == :extended
          return BaseRate.new(
            loan_amount_cents, state: state, underwriter: underwriter, as_of_date: as_of_date
          ).calculate_elc
        end

        concurrent_fee = state_rules[:concurrent_base_fee_cents]

        case state
        when "NC"
          # NC: Always flat fee when concurrent, regardless of loan vs owner amount
          concurrent_fee
        when "TX"
          # TX: Flat fee for simultaneous issue when loan <= owner
          return concurrent_fee if loan_amount_cents <= owner_liability_cents
          calculate_increased_liability
        when "CA"
          # CA Standard concurrent: $150 flat or $150 + percent × rate_difference
          return concurrent_fee if loan_amount_cents <= owner_liability_cents
          calculate_ca_standard_excess
        when "FL"
          # FL: Flat fee if loan <= owner, or flat fee + ELC if loan > owner
          return concurrent_fee if loan_amount_cents <= owner_liability_cents
          calculate_increased_liability
        else
          # Default logic for unknown states
          return concurrent_fee if loan_amount_cents <= owner_liability_cents
          calculate_increased_liability
        end
      end

      # CA Standard concurrent excess: $150 + percent × (rate_loan - rate_owner)
      def calculate_ca_standard_excess
        concurrent_fee = state_rules[:concurrent_base_fee_cents]

        rate_loan = BaseRate.new(
          loan_amount_cents, state: state, underwriter: underwriter, as_of_date: as_of_date
        ).calculate
        rate_owner = BaseRate.new(
          owner_liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date
        ).calculate

        rate_diff = rate_loan - rate_owner
        excess_percent = state_rules[:concurrent_standard_excess_percent] || 80.0
        excess_rate = (rate_diff * excess_percent / 100.0).round

        [concurrent_fee, concurrent_fee + excess_rate].max
      end

      def calculate_increased_liability
        concurrent_fee = state_rules[:concurrent_base_fee_cents]
        excess = loan_amount_cents - owner_liability_cents

        excess_rate = if state_rules[:concurrent_uses_elc]
                        BaseRate.new(excess, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate_elc
                      else
                        BaseRate.new(excess, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate
                      end

        concurrent_fee + excess_rate
      end
    end
  end
end
