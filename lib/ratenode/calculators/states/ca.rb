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
      # @option params [Boolean] :is_hold_open Whether this is a hold-open/binder transaction (optional)
      # @option params [Integer] :prior_policy_amount_cents Prior policy amount for hold-open final (optional)
      #
      # @return [Integer] Premium amount in cents
      #
      def calculate_owners_premium(params)
        @liability_cents = params[:liability_cents]
        @policy_type = (params[:policy_type] || :standard).to_sym
        @underwriter = params[:underwriter]
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

      # Calculate lender's title insurance premium for California.
      #
      # Calculation paths:
      #   Standalone Standard:  base_rate × standalone_lender_standard_percent
      #   Standalone Extended:  base_rate × standalone_lender_extended_percent
      #   Concurrent Standard:  $150 flat (loan ≤ owner) or $150 + percent × (rate_loan - rate_owner)
      #   Concurrent Extended:  Full ELC rate table lookup on loan amount
      #
      # @param params [Hash] Calculation inputs
      # @option params [Integer] :loan_amount_cents Loan amount in cents (required)
      # @option params [Integer] :owner_liability_cents Owner's policy liability for concurrent (optional)
      # @option params [String] :underwriter Underwriter code (required)
      # @option params [Date] :as_of_date Effective date for rate lookup (required)
      # @option params [Boolean] :concurrent Whether issued concurrently with owner's policy (optional)
      # @option params [Symbol] :lender_policy_type :standard or :extended (optional, defaults to :standard)
      # @option params [Boolean] :is_hold_open Whether cash/binder acquisition (optional)
      # @option params [Boolean] :include_lenders_policy Whether to include lender policy (optional)
      #
      # @return [Integer] Premium amount in cents
      #
      def calculate_lenders_premium(params)
        loan_amount_cents = params[:loan_amount_cents]
        owner_liability_cents = params[:owner_liability_cents]
        concurrent = params[:concurrent] || false
        underwriter = params[:underwriter]
        as_of_date = params[:as_of_date] || Date.today
        lender_policy_type = (params[:lender_policy_type] || :standard).to_sym

        # Input validation
        raise ArgumentError, "Underwriter is required" if underwriter.nil?
        raise ArgumentError, "Loan amount cannot be negative" if loan_amount_cents.is_a?(Integer) && loan_amount_cents < 0
        unless %i[standard extended].include?(lender_policy_type)
          raise ArgumentError, "Invalid lender policy type: #{lender_policy_type}. Must be :standard or :extended"
        end

        # Guard: skip lender policy for cash/binder acquisitions (same as AZ hold-open)
        return 0 if params[:is_hold_open] == true
        return 0 if params[:include_lenders_policy] == false

        # Guard: $0 loan means no lender premium
        return 0 if loan_amount_cents == 0

        rules = rules_for("CA", underwriter: underwriter)

        unless concurrent
          # Standalone lender policy: base_rate × underwriter-specific multiplier
          # TRG: 80% Standard / 90% Extended; ORT: 75% Standard / 85% Extended
          base_rate = Calculators::BaseRate.new(
            loan_amount_cents,
            state: "CA",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate

          multiplier_key = lender_policy_type == :extended ?
            :standalone_lender_extended_percent :
            :standalone_lender_standard_percent
          multiplier = rules[multiplier_key]

          return base_rate unless multiplier
          return (base_rate * multiplier / 100.0).round
        end

        # Concurrent lender policy
        if lender_policy_type == :extended
          # Extended concurrent: full ELC rate table lookup on loan amount
          return Calculators::BaseRate.new(
            loan_amount_cents,
            state: "CA",
            underwriter: underwriter,
            as_of_date: as_of_date
          ).calculate_elc
        end

        # Concurrent Standard: $150 flat or $150 + percent × rate_difference
        concurrent_fee = rules[:concurrent_base_fee_cents]

        return concurrent_fee if loan_amount_cents <= owner_liability_cents

        # Calculate rate difference (not ELC on excess amount)
        rate_loan = Calculators::BaseRate.new(
          loan_amount_cents, state: "CA", underwriter: underwriter, as_of_date: as_of_date
        ).calculate
        rate_owner = Calculators::BaseRate.new(
          owner_liability_cents, state: "CA", underwriter: underwriter, as_of_date: as_of_date
        ).calculate

        rate_diff = rate_loan - rate_owner
        excess_percent = rules[:concurrent_standard_excess_percent] || 80.0
        excess_rate = (rate_diff * excess_percent / 100.0).round

        [concurrent_fee, concurrent_fee + excess_rate].max
      end

      # Get the line item description for this calculation.
      #
      # @param params [Hash] Calculation parameters
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
        base_rate = lookup_base_rate(@liability_cents)
        multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "CA", underwriter: @underwriter, as_of_date: @as_of_date)
        (base_rate * multiplier).round
      end

      def calculate_hold_open_initial
        # Hold-open initial: standard premium + 10% surcharge of base rate (OR Rate)
        # Formula: base_rate × policy_type_multiplier + base_rate × surcharge_percent
        base_rate = lookup_base_rate(@liability_cents)
        multiplier = Models::PolicyType.multiplier_for(@policy_type, state: "CA", underwriter: @underwriter, as_of_date: @as_of_date)
        surcharge_percent = state_rules[:hold_open_surcharge_percent]

        standard_premium = (base_rate * multiplier).round
        surcharge = (base_rate * surcharge_percent).round
        standard_premium + surcharge
      end

      def calculate_hold_open_final
        # Hold-open final: incremental owner's premium (rate at new amount - rate at original amount)
        # Credit = full base charge from original binder
        # Additional = new premium - credit (minimum $0)
        new_premium = calculate_standard

        saved_liability = @liability_cents
        @liability_cents = @prior_policy_amount_cents
        prior_premium = calculate_standard
        @liability_cents = saved_liability

        [new_premium - prior_premium, 0].max
      end

      def lookup_base_rate(liability_cents)
        Calculators::BaseRate.new(
          liability_cents,
          state: "CA",
          underwriter: @underwriter,
          as_of_date: @as_of_date
        ).calculate
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
