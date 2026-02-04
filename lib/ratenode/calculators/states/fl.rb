# frozen_string_literal: true

require "date"

module RateNode
  module States
    # Florida-specific rate calculator.
    #
    # FL uses a separate reissue rate table instead of percentage discounts.
    # When reissue rates apply:
    # - Prior policy amount uses reissue rates
    # - Excess over prior amount uses original rates at cumulative tier position
    #
    class FL < BaseStateCalculator
      # Calculate owner's title insurance premium for Florida.
      #
      # @param params [Hash] Calculation inputs
      # @option params [Integer] :liability_cents Policy liability amount in cents (required)
      # @option params [Symbol, String] :policy_type :standard, :homeowners, or :extended (required)
      # @option params [String] :underwriter Underwriter code (required)
      # @option params [Date] :as_of_date Effective date for rate lookup (required)
      # @option params [Integer] :prior_policy_amount_cents Prior policy amount for reissue (optional)
      # @option params [Date] :prior_policy_date Prior policy date for eligibility check (optional)
      #
      # @return [Integer] Premium amount in cents
      #
      def calculate_owners_premium(params)
        @liability_cents = params[:liability_cents]
        @policy_type = (params[:policy_type] || :standard).to_sym
        @underwriter = params[:underwriter]
        @as_of_date = params[:as_of_date] || Date.today
        @prior_policy_amount_cents = params[:prior_policy_amount_cents]
        @prior_policy_date = params[:prior_policy_date]

        if state_rules[:has_reissue_rate_table] && eligible_for_reissue_rates?
          calculate_with_reissue_rate_table
        else
          calculate_standard
        end
      end

      # Calculate lender's title insurance premium for Florida.
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

        rules = rules_for("FL", underwriter: underwriter)

        unless concurrent
          # Standalone lender's policy
          return Calculators::BaseRate.new(
            loan_amount_cents,
            state: "FL",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate
        end

        # FL: Flat fee if loan <= owner, or flat fee + ELC if loan > owner
        concurrent_fee = rules[:concurrent_base_fee_cents]

        return concurrent_fee if loan_amount_cents <= owner_liability_cents

        # Calculate excess
        excess = loan_amount_cents - owner_liability_cents
        if rules[:concurrent_uses_elc]
          excess_rate = Calculators::BaseRate.new(
            excess,
            state: "FL",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate_elc
        else
          excess_rate = Calculators::BaseRate.new(
            excess,
            state: "FL",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate
        end

        concurrent_fee + excess_rate
      end

      # Get the line item description for this calculation.
      #
      # @param params [Hash] Calculation parameters
      # @return [String] Line item description
      #
      def line_item(params = {})
        policy_type = (params[:policy_type] || :standard).to_sym
        "Owner's Title Insurance (#{policy_type_label(policy_type)})"
      end

      # Get reissue discount amount for Florida.
      #
      # FL uses rate table approach: discount = original_premium - reissue_premium
      #
      # @param params [Hash] Calculation parameters
      # @return [Integer] Reissue discount in cents
      #
      def reissue_discount_amount(params)
        @liability_cents = params[:liability_cents]
        @policy_type = (params[:policy_type] || :standard).to_sym
        @underwriter = params[:underwriter]
        @as_of_date = params[:as_of_date] || Date.today
        @prior_policy_amount_cents = params[:prior_policy_amount_cents]
        @prior_policy_date = params[:prior_policy_date]

        if state_rules[:has_reissue_rate_table] && eligible_for_reissue_rates?
          original_premium = calculate_original_premium
          reissue_premium = calculate_with_reissue_rate_table
          original_premium - reissue_premium
        else
          0
        end
      end

      private

      def state_rules
        @state_rules ||= rules_for("FL", underwriter: @underwriter)
      end

      def calculate_standard
        base_rate = Calculators::BaseRate.new(
          @liability_cents,
          state: "FL",
          underwriter: @underwriter,
          as_of_date: @as_of_date
        ).calculate
        multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "FL", underwriter: @underwriter, as_of_date: @as_of_date)
        (base_rate * multiplier).round
      end

      def calculate_with_reissue_rate_table
        # FL: Use reissue rates for amount up to prior policy, original rates for excess
        multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "FL", underwriter: @underwriter, as_of_date: @as_of_date)

        if @liability_cents <= @prior_policy_amount_cents
          # All at reissue rate
          reissue_rate = Calculators::BaseRate.new(
            @liability_cents,
            state: "FL",
            underwriter: @underwriter,
            as_of_date: @as_of_date,
            rate_table: "reissue"
          ).calculate
          (reissue_rate * multiplier).round
        else
          # Reissue rate for prior amount
          reissue_rate = Calculators::BaseRate.new(
            @prior_policy_amount_cents,
            state: "FL",
            underwriter: @underwriter,
            as_of_date: @as_of_date,
            rate_table: "reissue"
          ).calculate

          # Excess must use original rates at the CUMULATIVE tier position
          original_rate_full = Calculators::BaseRate.new(
            @liability_cents,
            state: "FL",
            underwriter: @underwriter,
            as_of_date: @as_of_date,
            rate_table: "original"
          ).calculate
          original_rate_prior = Calculators::BaseRate.new(
            @prior_policy_amount_cents,
            state: "FL",
            underwriter: @underwriter,
            as_of_date: @as_of_date,
            rate_table: "original"
          ).calculate
          excess_rate = original_rate_full - original_rate_prior

          ((reissue_rate + excess_rate) * multiplier).round
        end
      end

      def calculate_original_premium
        base_rate = Calculators::BaseRate.new(
          @liability_cents,
          state: "FL",
          underwriter: @underwriter,
          as_of_date: @as_of_date,
          rate_table: "original"
        ).calculate
        multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "FL", underwriter: @underwriter, as_of_date: @as_of_date)
        (base_rate * multiplier).round
      end

      def eligible_for_reissue_rates?
        return false unless @prior_policy_date && @prior_policy_amount_cents

        eligibility_years = state_rules[:reissue_eligibility_years]
        return false unless eligibility_years

        years_since_prior = ((@as_of_date - @prior_policy_date) / 365.25).floor
        years_since_prior <= eligibility_years
      end

      def policy_type_label(policy_type)
        case policy_type
        when :standard then "Standard"
        when :homeowner then "Homeowner's"
        when :extended then "Extended"
        else policy_type.to_s.capitalize
        end
      end
    end
  end
end
