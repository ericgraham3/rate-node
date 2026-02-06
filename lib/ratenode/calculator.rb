# frozen_string_literal: true

require "date"

module RateNode
  class Calculator
    attr_reader :transaction_type, :property_address, :purchase_price_cents,
                :loan_amount_cents, :owner_policy_type, :lender_policy_type,
                :include_lenders_policy,
                :endorsement_codes, :state, :underwriter, :as_of_date,
                :include_cpl, :prior_policy_date, :prior_policy_amount_cents,
                :property_type, :county, :is_hold_open

    def initialize(params)
      @transaction_type = params[:transaction_type]&.to_sym || :purchase
      @property_address = params[:property_address]
      @purchase_price_cents = params[:purchase_price_cents].to_i
      @loan_amount_cents = params[:loan_amount_cents].to_i
      @owner_policy_type = params[:owner_policy_type]&.to_sym || :standard
      @lender_policy_type = params[:lender_policy_type]&.to_sym || :standard
      @include_lenders_policy = params.fetch(:include_lenders_policy, true)
      @endorsement_codes = Array(params[:endorsement_codes])
      @state = params[:state] || raise(Error, "state is required")
      @underwriter = params[:underwriter] || raise(Error, "underwriter is required")
      @as_of_date = params[:as_of_date] || Date.today
      @include_cpl = params.fetch(:include_cpl, false)
      @prior_policy_date = params[:prior_policy_date]
      @prior_policy_amount_cents = params[:prior_policy_amount_cents]&.to_i
      @property_type = params[:property_type]&.to_sym
      @county = params[:county]
      @is_hold_open = params.fetch(:is_hold_open, false)
    end

    def calculate
      case transaction_type
      when :purchase
        calculate_purchase
      when :refinance
        calculate_refinance
      else
        raise Error, "Unknown transaction type: #{transaction_type}"
      end
    end

    private

    def calculate_purchase
      owners = calculate_owners_policy

      lenders = include_lenders_policy ? calculate_lenders_policy(owners[:liability_cents]) : nil

      # For FL percentage_combined endorsements, we need the combined premium
      combined_premium_cents = [owners[:premium_cents], lenders&.dig(:premium_cents)].compact.sum
      endorsements = calculate_endorsements(lenders.nil? ? false : true, combined_premium_cents: combined_premium_cents)
      cpl = include_cpl ? calculate_cpl(owners[:liability_cents]) : nil

      build_result(owners, lenders, endorsements, cpl)
    end

    def calculate_refinance
      refinance = Calculators::Refinance.new(
        loan_amount_cents: loan_amount_cents,
        state: state,
        underwriter: underwriter,
        as_of_date: as_of_date
      )
      lenders = {
        type: "refinance",
        liability_cents: loan_amount_cents,
        premium_cents: refinance.calculate,
        line_item: refinance.line_item
      }
      endorsements = calculate_endorsements(false)

      build_result(nil, lenders, endorsements)
    end

    def calculate_owners_policy
      owner_liability = purchase_price_cents

      # Use the state calculator factory to get the appropriate calculator
      calculator = StateCalculatorFactory.for(state)
      params = {
        liability_cents: owner_liability,
        policy_type: owner_policy_type,
        underwriter: underwriter,
        as_of_date: as_of_date,
        prior_policy_date: prior_policy_date,
        prior_policy_amount_cents: prior_policy_amount_cents,
        county: county,
        is_hold_open: is_hold_open,
        loan_amount_cents: include_lenders_policy ? loan_amount_cents : nil
      }

      {
        type: owner_policy_type.to_s,
        liability_cents: owner_liability,
        premium_cents: calculator.calculate_owners_premium(params),
        line_item: calculator.line_item(params),
        reissue_discount_cents: calculator.reissue_discount_amount(params)
      }
    end

    def calculate_lenders_policy(owner_liability_cents)
      calc = Calculators::LendersPolicy.new(
        loan_amount_cents: loan_amount_cents,
        owner_liability_cents: owner_liability_cents,
        concurrent: true,
        state: state,
        underwriter: underwriter,
        as_of_date: as_of_date,
        lender_policy_type: lender_policy_type
      )

      {
        type: calc.concurrent? ? "concurrent" : "standalone",
        liability_cents: loan_amount_cents,
        premium_cents: calc.calculate,
        line_item: calc.line_item
      }
    end

    def calculate_endorsements(concurrent, combined_premium_cents: nil)
      return [] if endorsement_codes.empty?

      liability = transaction_type == :refinance ? loan_amount_cents : purchase_price_cents
      calc = Calculators::EndorsementCalculator.new(
        endorsement_codes: endorsement_codes,
        liability_cents: liability,
        lender_liability_cents: loan_amount_cents,
        concurrent: concurrent,
        state: state,
        underwriter: underwriter,
        as_of_date: as_of_date,
        combined_premium_cents: combined_premium_cents,
        property_type: property_type
      )
      calc.calculate
    end

    def calculate_cpl(owner_liability_cents)
      calc = Calculators::CPLCalculator.new(
        liability_cents: owner_liability_cents,
        state: state,
        underwriter: underwriter,
        as_of_date: as_of_date
      )

      {
        amount_cents: calc.calculate,
        line_item: calc.line_item
      }
    end

    def build_result(owners, lenders, endorsements, cpl = nil)
      title_insurance_cents = [owners&.dig(:premium_cents), lenders&.dig(:premium_cents)].compact.sum
      endorsements_cents = endorsements.sum { |e| e[:amount_cents] }
      cpl_cents = cpl&.dig(:amount_cents) || 0
      grand_total_cents = round_up_to_dollar(title_insurance_cents + endorsements_cents + cpl_cents)

      Output::ClosingDisclosure.new(
        transaction: {
          type: transaction_type.to_s,
          property_address: property_address,
          purchase_price_cents: purchase_price_cents,
          loan_amount_cents: loan_amount_cents
        },
        owners_policy: owners,
        lenders_policy: lenders,
        endorsements: endorsements,
        cpl: cpl,
        totals: {
          title_insurance_cents: title_insurance_cents,
          endorsements_cents: endorsements_cents,
          cpl_cents: cpl_cents,
          grand_total_cents: grand_total_cents
        }
      )
    end

    def round_up_to_dollar(cents)
      return cents if (cents % 100).zero?

      ((cents / 100) + 1) * 100
    end
  end
end
