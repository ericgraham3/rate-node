# frozen_string_literal: true

require "date"

module RateNode
  module States
    # North Carolina-specific rate calculator.
    #
    # NC uses percentage-based reissue discounts (50%) instead of a separate rate table.
    # NC always uses flat fee for concurrent lender's policy regardless of loan vs owner amount.
    #
    class NC < BaseStateCalculator
      # Calculate owner's title insurance premium for North Carolina.
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

        calculate_standard
      end

      # Calculate lender's title insurance premium for North Carolina.
      #
      # NC: Always flat fee when concurrent, regardless of loan vs owner amount
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
        concurrent = params[:concurrent] || false
        underwriter = params[:underwriter]
        as_of_date = params[:as_of_date] || Date.today

        rules = rules_for("NC", underwriter: underwriter)

        unless concurrent
          # Standalone lender's policy
          return Calculators::BaseRate.new(
            loan_amount_cents,
            state: "NC",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate
        end

        # NC: Always flat fee when concurrent, regardless of loan vs owner amount
        rules[:concurrent_base_fee_cents]
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

      # Get reissue discount amount for North Carolina.
      #
      # NC uses percentage-based discount approach.
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

        calculate_reissue_discount
      end

      private

      def state_rules
        @state_rules ||= rules_for("NC", underwriter: @underwriter)
      end

      def calculate_standard
        base_rate = Calculators::BaseRate.new(
          @liability_cents,
          state: "NC",
          underwriter: @underwriter,
          as_of_date: @as_of_date
        ).calculate
        multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "NC", underwriter: @underwriter, as_of_date: @as_of_date)
        full_premium = (base_rate * multiplier).round

        # Apply reissue discount if applicable (NC style)
        if eligible_for_reissue_discount?
          full_premium - calculate_reissue_discount
        else
          full_premium
        end
      end

      def calculate_reissue_discount
        return 0 unless eligible_for_reissue_discount?

        discount_percent = state_rules[:reissue_discount_percent]

        # Calculate the portion of current liability covered by prior policy
        discountable_portion_cents = [@liability_cents, @prior_policy_amount_cents].min

        # Calculate the actual tiered rate on the discountable portion
        discountable_tiered_rate = Models::RateTier.calculate_rate(
          discountable_portion_cents,
          state: "NC",
          underwriter: @underwriter,
          as_of_date: @as_of_date
        )

        # Apply policy type multiplier to the discount base
        multiplier = Models::PolicyType.multiplier_for(
          @policy_type,
          state: "NC",
          underwriter: @underwriter,
          as_of_date: @as_of_date
        )
        discountable_base = (discountable_tiered_rate * multiplier).round

        (discountable_base * discount_percent).round
      end

      def eligible_for_reissue_discount?
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
