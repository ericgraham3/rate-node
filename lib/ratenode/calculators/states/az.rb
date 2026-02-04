# frozen_string_literal: true

require "date"

module RateNode
  module States
    # Arizona-specific rate calculator.
    #
    # Supports two underwriters:
    # - TRG: 2 regions, $5k rounding, hold-open support
    # - ORT: 3 areas (only Area 1 implemented), $20k rounding, no hold-open
    #
    class AZ < BaseStateCalculator
      # Calculate owner's title insurance premium for Arizona.
      #
      # @param params [Hash] Calculation inputs
      # @option params [Integer] :liability_cents Policy liability amount in cents (required)
      # @option params [Symbol, String] :policy_type :standard, :homeowners, or :extended (required)
      # @option params [String] :underwriter "TRG" or "ORT" (required)
      # @option params [Date] :as_of_date Effective date for rate lookup (required)
      # @option params [String] :county County name for geographic lookups (optional)
      # @option params [Boolean] :is_hold_open Whether this is a hold-open transaction (optional)
      # @option params [String] :hold_open_phase "initial" or "final" for hold-open (optional)
      # @option params [Integer] :prior_policy_amount_cents Prior policy amount for hold-open final (optional)
      #
      # @return [Integer] Premium amount in cents
      #
      def calculate_owners_premium(params)
        @liability_cents = params[:liability_cents]
        @policy_type = (params[:policy_type] || :standard).to_sym
        @underwriter = params[:underwriter]
        @county = params[:county]
        @as_of_date = params[:as_of_date] || Date.today
        @is_hold_open = params[:is_hold_open] || false
        @prior_policy_amount_cents = params[:prior_policy_amount_cents]

        if @is_hold_open && @prior_policy_amount_cents
          calculate_hold_open_final
        elsif @is_hold_open
          calculate_hold_open_initial
        else
          calculate_standard
        end
      end

      # Calculate lender's title insurance premium for Arizona.
      #
      # @param params [Hash] Calculation inputs
      # @option params [Integer] :loan_amount_cents Loan amount in cents (required)
      # @option params [Integer] :owner_liability_cents Owner's policy liability for concurrent (optional)
      # @option params [String] :underwriter Underwriter code (required)
      # @option params [Date] :as_of_date Effective date for rate lookup (required)
      # @option params [Boolean] :concurrent Whether issued concurrently with owner's policy (optional)
      #
      # @return [Integer] Premium amount in cents
      #
      def calculate_lenders_premium(params)
        loan_amount_cents = params[:loan_amount_cents]
        owner_liability_cents = params[:owner_liability_cents]
        concurrent = params[:concurrent] || false
        underwriter = params[:underwriter]
        as_of_date = params[:as_of_date] || Date.today

        rules = rules_for("AZ", underwriter: underwriter)

        unless concurrent
          # Standalone lender's policy - use base rate calculation
          return Calculators::BaseRate.new(
            loan_amount_cents,
            state: "AZ",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate
        end

        # Concurrent: flat fee if loan <= owner, or flat fee + ELC if loan > owner
        concurrent_fee = rules[:concurrent_base_fee_cents]

        return concurrent_fee if loan_amount_cents <= owner_liability_cents

        # Calculate excess using ELC rate
        excess = loan_amount_cents - owner_liability_cents
        if rules[:concurrent_uses_elc]
          excess_rate = Calculators::BaseRate.new(
            excess,
            state: "AZ",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate_elc
        else
          excess_rate = Calculators::BaseRate.new(
            excess,
            state: "AZ",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate
        end

        concurrent_fee + excess_rate
      end

      # Get the line item description for this calculation.
      #
      # @param params [Hash] Same params as calculate_owners_premium
      # @return [String] Line item description
      #
      def line_item(params = {})
        policy_type = (params[:policy_type] || :standard).to_sym
        is_hold_open = params[:is_hold_open] || false
        prior_policy_amount_cents = params[:prior_policy_amount_cents]

        if is_hold_open && prior_policy_amount_cents
          "Owner's Title Insurance (#{policy_type_label(policy_type)}) - Hold-Open Final"
        elsif is_hold_open
          "Owner's Title Insurance (#{policy_type_label(policy_type)}) - Hold-Open Initial"
        else
          "Owner's Title Insurance (#{policy_type_label(policy_type)})"
        end
      end

      # Get reissue discount amount (AZ does not support reissue discounts).
      #
      # @param params [Hash] Calculation parameters
      # @return [Integer] Always 0 for AZ
      #
      def reissue_discount_amount(params = {})
        0
      end

      private

      def state_rules
        @state_rules ||= rules_for("AZ", underwriter: @underwriter)
      end

      def calculate_standard
        base_rate = lookup_base_rate(rounded_liability)
        multiplier = policy_type_multiplier
        premium = (base_rate * multiplier).round
        apply_minimum_premium(premium)
      end

      def calculate_hold_open_initial
        # Hold-open initial: standard premium + 25% fee (min $250)
        raise RateNode::Error, "Hold-open not supported for #{@underwriter}" unless state_rules[:supports_hold_open]

        standard_premium = calculate_standard
        fee_percent = state_rules[:hold_open_fee_percent]
        minimum_fee = state_rules[:hold_open_minimum_cents]

        fee = [(standard_premium * fee_percent).round, minimum_fee].max
        standard_premium + fee
      end

      def calculate_hold_open_final
        # Hold-open final: new premium minus credit for prior premium paid
        raise RateNode::Error, "Hold-open not supported for #{@underwriter}" unless state_rules[:supports_hold_open]

        # Calculate new premium at current liability
        new_premium = calculate_standard

        # Calculate prior premium credit
        saved_liability = @liability_cents
        @liability_cents = @prior_policy_amount_cents
        prior_premium = calculate_standard
        @liability_cents = saved_liability

        # Final premium is the difference (new - prior), minimum $0
        [new_premium - prior_premium, 0].max
      end

      def rounded_liability
        return @liability_cents unless state_rules[:rounds_liability]

        increment = state_rules[:rounding_increment_cents]
        rounding.round_up(@liability_cents, increment)
      end

      def policy_type_multiplier
        multipliers = state_rules[:policy_type_multipliers] || {}
        multipliers[@policy_type] || 1.0
      end

      def region_for_county
        return nil unless state_rules[:regions]

        state_rules[:regions].each do |region_num, region_config|
          return region_num if region_config[:counties].include?(@county)
        end
        nil
      end

      def area_for_county
        return nil unless state_rules[:areas]

        state_rules[:areas].each do |area_num, area_config|
          return area_num if area_config[:counties].include?(@county)
        end
        nil
      end

      def minimum_premium_cents
        if @underwriter == "TRG"
          region = region_for_county
          return state_rules.dig(:regions, region, :minimum_premium_cents) || 0 if region
        elsif @underwriter == "ORT"
          area = area_for_county
          return state_rules.dig(:areas, area, :minimum_premium_cents) || 0 if area
        end

        state_rules[:minimum_premium_cents] || 0
      end

      def lookup_base_rate(liability)
        Models::RateTier.calculate_rate(
          liability,
          state: "AZ",
          underwriter: @underwriter,
          as_of_date: @as_of_date,
          rate_type: "premium",
          county: @county
        )
      end

      def apply_minimum_premium(rate)
        minimum = minimum_premium_cents
        [rate, minimum].max
      end

      def policy_type_label(policy_type)
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
