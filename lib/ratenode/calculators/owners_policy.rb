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

      def state_rules
        @state_rules ||= RateNode.rules_for(state, underwriter: underwriter)
      end

      def calculate
        # FL uses separate reissue rate table instead of discount percentage
        if state_rules[:has_reissue_rate_table] && eligible_for_reissue_rates?
          calculate_with_reissue_rate_table
        else
          calculate_standard
        end
      end

      def calculate_standard
        base_rate = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate
        multiplier = Models::PolicyType.multiplier_for(policy_type, state: state, underwriter: underwriter, as_of_date: as_of_date)
        full_premium = (base_rate * multiplier).round

        # Apply reissue discount if applicable (NC style)
        if eligible_for_reissue_discount?
          full_premium - calculate_reissue_discount(full_premium)
        else
          full_premium
        end
      end

      def calculate_with_reissue_rate_table
        # FL: Use reissue rates for amount up to prior policy, original rates for excess
        # Per FL manual: "Any amount of new insurance in excess of the amount under the
        # previous policy must be computed at the original rates"
        multiplier = Models::PolicyType.multiplier_for(policy_type, state: state, underwriter: underwriter, as_of_date: as_of_date)

        if liability_cents <= prior_policy_amount_cents
          # All at reissue rate
          reissue_rate = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_table: "reissue").calculate
          (reissue_rate * multiplier).round
        else
          # Reissue rate for prior amount
          reissue_rate = BaseRate.new(prior_policy_amount_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_table: "reissue").calculate

          # Excess must use original rates at the CUMULATIVE tier position
          # Calculate as: (original rate for full liability) - (original rate for prior amount)
          # This gives us the incremental cost from prior to current at original rates
          original_rate_full = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_table: "original").calculate
          original_rate_prior = BaseRate.new(prior_policy_amount_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_table: "original").calculate
          excess_rate = original_rate_full - original_rate_prior

          ((reissue_rate + excess_rate) * multiplier).round
        end
      end

      def eligible_for_reissue_rates?
        return false unless prior_policy_date && prior_policy_amount_cents

        eligibility_years = state_rules[:reissue_eligibility_years]
        return false unless eligibility_years

        years_since_prior = ((as_of_date - prior_policy_date) / 365.25).floor
        years_since_prior <= eligibility_years
      end

      def calculate_reissue_discount(full_premium)
        return 0 unless eligible_for_reissue_discount?

        discount_percent = case state
                          when "NC"
                            state_rules[:reissue_discount_percent]
                          else
                            state_rules[:reissue_discount_percent]
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

        eligibility_years = state_rules[:reissue_eligibility_years]
        return false unless eligibility_years

        years_since_prior = ((as_of_date - prior_policy_date) / 365.25).floor

        case state
        when "NC"
          years_since_prior <= eligibility_years
        else
          years_since_prior <= eligibility_years
        end
      end

      def reissue_discount_amount
        # FL uses rate table approach: discount = original_premium - reissue_premium
        if state_rules[:has_reissue_rate_table] && eligible_for_reissue_rates?
          original_premium = calculate_original_premium
          reissue_premium = calculate_with_reissue_rate_table
          original_premium - reissue_premium
        elsif eligible_for_reissue_discount?
          # NC-style percentage discount
          base_rate = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate
          multiplier = Models::PolicyType.multiplier_for(policy_type, state: state, underwriter: underwriter, as_of_date: as_of_date)
          full_premium = (base_rate * multiplier).round
          calculate_reissue_discount(full_premium)
        else
          0
        end
      end

      def calculate_original_premium
        base_rate = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_table: "original").calculate
        multiplier = Models::PolicyType.multiplier_for(policy_type, state: state, underwriter: underwriter, as_of_date: as_of_date)
        (base_rate * multiplier).round
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
