# frozen_string_literal: true

require "date"

module RateNode
  module Calculators
    class OwnersPolicy
      attr_reader :liability_cents, :policy_type, :state, :underwriter, :as_of_date,
                  :prior_policy_date, :prior_policy_amount_cents

      def initialize(liability_cents:, policy_type: :standard, state:, underwriter:, as_of_date: Date.today, prior_policy_date: nil, prior_policy_amount_cents: nil)
        @liability_cents = liability_cents
        @policy_type = policy_type.to_sym
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
        @prior_policy_date = prior_policy_date
        @prior_policy_amount_cents = prior_policy_amount_cents
      end

      def calculate
        base_rate = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate
        multiplier = Models::PolicyType.multiplier_for(policy_type, state: state, underwriter: underwriter, as_of_date: as_of_date)
        full_premium = (base_rate * multiplier).round

        # Apply reissue discount if applicable
        if eligible_for_reissue_discount?
          full_premium - calculate_reissue_discount(full_premium)
        else
          full_premium
        end
      end

      def calculate_reissue_discount(full_premium)
        return 0 unless eligible_for_reissue_discount?

        # NC: 50% discount on portion up to prior policy amount
        discount_percent = case state
                          when "NC"
                            0.50
                          else
                            0.0
                          end

        # Calculate the portion of current liability covered by prior policy
        discountable_portion_cents = [liability_cents, prior_policy_amount_cents].min

        # Calculate base rate for discountable portion
        discountable_base_rate = if discountable_portion_cents == liability_cents
                                  # All of current policy is discountable
                                  full_premium
                                else
                                  # Proportional discount based on ratio
                                  # This is an approximation; for exact calculation we'd need to recalculate base rate
                                  (full_premium * discountable_portion_cents.to_f / liability_cents).round
                                end

        (discountable_base_rate * discount_percent).round
      end

      def eligible_for_reissue_discount?
        return false unless prior_policy_date && prior_policy_amount_cents

        years_since_prior = ((as_of_date - prior_policy_date) / 365.25).floor

        case state
        when "NC"
          years_since_prior <= 15
        else
          false
        end
      end

      def reissue_discount_amount
        return 0 unless eligible_for_reissue_discount?

        base_rate = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate
        multiplier = Models::PolicyType.multiplier_for(policy_type, state: state, underwriter: underwriter, as_of_date: as_of_date)
        full_premium = (base_rate * multiplier).round

        calculate_reissue_discount(full_premium)
      end

      def policy_type_label
        case policy_type
        when :standard then "Standard"
        when :homeowner then "Homeowner's"
        when :extended then "Extended"
        else policy_type.to_s.capitalize
        end
      end

      def line_item
        "Owner's Title Insurance (#{policy_type_label})"
      end
    end
  end
end
