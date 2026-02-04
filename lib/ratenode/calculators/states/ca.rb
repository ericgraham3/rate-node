# frozen_string_literal: true

require "date"

module RateNode
  module States
    # California-specific rate calculator.
    #
    # CA uses simple bracket-based calculation with special handling for
    # policies over $3M (formula-based rates for large policies).
    #
    class CA < BaseStateCalculator
      # Calculate owner's title insurance premium for California.
      #
      # @param params [Hash] Calculation inputs
      # @option params [Integer] :liability_cents Policy liability amount in cents (required)
      # @option params [Symbol, String] :policy_type :standard, :homeowners, or :extended (required)
      # @option params [String] :underwriter Underwriter code (required)
      # @option params [Date] :as_of_date Effective date for rate lookup (required)
      #
      # @return [Integer] Premium amount in cents
      #
      def calculate_owners_premium(params)
        @liability_cents = params[:liability_cents]
        @policy_type = (params[:policy_type] || :standard).to_sym
        @underwriter = params[:underwriter]
        @as_of_date = params[:as_of_date] || Date.today

        calculate_standard
      end

      # Calculate lender's title insurance premium for California.
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

        rules = rules_for("CA", underwriter: underwriter)

        unless concurrent
          # Standalone lender's policy
          return Calculators::BaseRate.new(
            loan_amount_cents,
            state: "CA",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate
        end

        # CA: Flat fee if loan <= owner, or flat fee + ELC if loan > owner
        concurrent_fee = rules[:concurrent_base_fee_cents]

        return concurrent_fee if loan_amount_cents <= owner_liability_cents

        # Calculate excess
        excess = loan_amount_cents - owner_liability_cents
        if rules[:concurrent_uses_elc]
          excess_rate = Calculators::BaseRate.new(
            excess,
            state: "CA",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate_elc
        else
          excess_rate = Calculators::BaseRate.new(
            excess,
            state: "CA",
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

      # Get reissue discount amount (CA does not support reissue discounts).
      #
      # @param params [Hash] Calculation parameters
      # @return [Integer] Always 0 for CA
      #
      def reissue_discount_amount(params = {})
        0
      end

      private

      def state_rules
        @state_rules ||= rules_for("CA", underwriter: @underwriter)
      end

      def calculate_standard
        base_rate = Calculators::BaseRate.new(
          @liability_cents,
          state: "CA",
          underwriter: @underwriter,
          as_of_date: @as_of_date
        ).calculate
        multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "CA", underwriter: @underwriter, as_of_date: @as_of_date)
        (base_rate * multiplier).round
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
