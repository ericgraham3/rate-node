# frozen_string_literal: true

require "date"

module RateNode
  module Calculators
    # Arizona-specific calculator with multi-underwriter support
    # TRG: 2 regions, $5k rounding, hold-open support
    # ORT: 3 areas (only Area 1 implemented), $20k rounding, no hold-open
    class AZCalculator
      attr_reader :liability_cents, :policy_type, :underwriter, :county, :as_of_date,
                  :is_hold_open, :prior_policy_amount_cents

      def initialize(liability_cents:, policy_type: :standard, underwriter:, county: nil,
                     as_of_date: Date.today, is_hold_open: false, prior_policy_amount_cents: nil)
        @liability_cents = liability_cents
        @policy_type = policy_type.to_sym
        @underwriter = underwriter
        @county = county
        @as_of_date = as_of_date
        @is_hold_open = is_hold_open
        @prior_policy_amount_cents = prior_policy_amount_cents
      end

      def state_rules
        @state_rules ||= RateNode.rules_for("AZ", underwriter: underwriter)
      end

      def calculate
        if is_hold_open && prior_policy_amount_cents
          calculate_hold_open_final
        elsif is_hold_open
          calculate_hold_open_initial
        else
          calculate_standard
        end
      end

      def calculate_standard
        base_rate = lookup_base_rate(rounded_liability)
        multiplier = policy_type_multiplier
        premium = (base_rate * multiplier).round
        apply_minimum_premium(premium)
      end

      def calculate_hold_open_initial
        # Hold-open initial: standard premium + 25% fee (min $250)
        raise RateNode::Error, "Hold-open not supported for #{underwriter}" unless state_rules[:supports_hold_open]

        standard_premium = calculate_standard
        fee_percent = state_rules[:hold_open_fee_percent]
        minimum_fee = state_rules[:hold_open_minimum_cents]

        fee = [(standard_premium * fee_percent).round, minimum_fee].max
        standard_premium + fee
      end

      def calculate_hold_open_final
        # Hold-open final: new premium minus credit for prior premium paid
        # Per TRG manual Section 109: Credit is premium paid on initial purchase
        # (NOT including the 25% hold-open fee)
        # Note: minimum premium does NOT apply to hold-open final
        raise RateNode::Error, "Hold-open not supported for #{underwriter}" unless state_rules[:supports_hold_open]

        # Calculate new premium at current liability
        new_premium = calculate_standard

        # Calculate prior premium credit (the base premium paid at initial hold-open)
        prior_calc = self.class.new(
          liability_cents: prior_policy_amount_cents,
          policy_type: policy_type,
          underwriter: underwriter,
          county: county,
          as_of_date: as_of_date,
          is_hold_open: false
        )
        prior_premium = prior_calc.calculate_standard

        # Final premium is the difference (new - prior), minimum $0
        [new_premium - prior_premium, 0].max
      end

      def round_liability(amount_cents)
        return amount_cents unless state_rules[:rounds_liability]

        increment = state_rules[:rounding_increment_cents]
        return amount_cents if increment.nil? || (amount_cents % increment).zero?

        # Always round UP
        ((amount_cents / increment) + 1) * increment
      end

      def rounded_liability
        return @liability_cents unless state_rules[:rounds_liability]

        increment = state_rules[:rounding_increment_cents]
        return @liability_cents if increment.nil? || (@liability_cents % increment).zero?

        # Always round UP
        ((@liability_cents / increment) + 1) * increment
      end

      def policy_type_multiplier
        multipliers = state_rules[:policy_type_multipliers] || {}
        multipliers[policy_type] || 1.0
      end

      def region_for_county
        return nil unless state_rules[:regions]

        state_rules[:regions].each do |region_num, region_config|
          return region_num if region_config[:counties].include?(county)
        end
        nil
      end

      def area_for_county
        return nil unless state_rules[:areas]

        state_rules[:areas].each do |area_num, area_config|
          return area_num if area_config[:counties].include?(county)
        end
        nil
      end

      def minimum_premium_cents
        if underwriter == "TRG"
          region = region_for_county
          return state_rules.dig(:regions, region, :minimum_premium_cents) || 0 if region
        elsif underwriter == "ORT"
          area = area_for_county
          return state_rules.dig(:areas, area, :minimum_premium_cents) || 0 if area
        end

        state_rules[:minimum_premium_cents] || 0
      end

      def line_item
        if is_hold_open && prior_policy_amount_cents
          "Owner's Title Insurance (#{policy_type_label}) - Hold-Open Final"
        elsif is_hold_open
          "Owner's Title Insurance (#{policy_type_label}) - Hold-Open Initial"
        else
          "Owner's Title Insurance (#{policy_type_label})"
        end
      end

      private

      def lookup_base_rate(liability)
        Models::RateTier.calculate_rate(
          liability,
          state: "AZ",
          underwriter: underwriter,
          as_of_date: as_of_date,
          rate_type: "premium",
          county: county
        )
      end

      def apply_minimum_premium(rate)
        minimum = minimum_premium_cents
        [rate, minimum].max
      end

      def policy_type_label
        case policy_type
        when :standard then "Standard"
        when :homeowners then "Homeowner's"
        when :extended then "Extended"
        else policy_type.to_s.capitalize
        end
      end
    end
  end
end
