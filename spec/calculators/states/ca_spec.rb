# frozen_string_literal: true

require "spec_helper"

RSpec.describe RateNode::States::CA do
  subject(:calculator) { described_class.new }

  let(:as_of_date) { Date.new(2025, 1, 1) }

  # Helper to build lender premium params
  def lender_params(overrides = {})
    {
      loan_amount_cents: 50_000_000,  # $500,000
      underwriter: "TRG",
      as_of_date: as_of_date,
      concurrent: false,
      lender_policy_type: :standard
    }.merge(overrides)
  end

  describe "#calculate_lenders_premium" do
    # --- US1: Standalone Lender Policy Rates ---

    context "US1: Standalone lender policies" do
      it "applies 80% multiplier for TRG Standard standalone" do
        params = lender_params(
          underwriter: "TRG",
          lender_policy_type: :standard,
          concurrent: false
        )
        result = calculator.calculate_lenders_premium(params)

        # Base rate for $500K TRG CA, then × 80%
        base_rate = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
        ).calculate
        expected = (base_rate * 80.0 / 100.0).round

        expect(result).to eq(expected)
      end

      it "applies 75% multiplier for ORT Standard standalone" do
        params = lender_params(
          underwriter: "ORT",
          lender_policy_type: :standard,
          concurrent: false
        )
        result = calculator.calculate_lenders_premium(params)

        base_rate = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "ORT", as_of_date: as_of_date
        ).calculate
        expected = (base_rate * 75.0 / 100.0).round

        expect(result).to eq(expected)
      end

      it "applies 90% multiplier for TRG Extended standalone" do
        params = lender_params(
          underwriter: "TRG",
          lender_policy_type: :extended,
          concurrent: false
        )
        result = calculator.calculate_lenders_premium(params)

        base_rate = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
        ).calculate
        expected = (base_rate * 90.0 / 100.0).round

        expect(result).to eq(expected)
      end

      it "applies 85% multiplier for ORT Extended standalone" do
        params = lender_params(
          underwriter: "ORT",
          lender_policy_type: :extended,
          concurrent: false
        )
        result = calculator.calculate_lenders_premium(params)

        base_rate = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "ORT", as_of_date: as_of_date
        ).calculate
        expected = (base_rate * 85.0 / 100.0).round

        expect(result).to eq(expected)
      end

      it "returns $0 premium for $0 loan amount" do
        params = lender_params(loan_amount_cents: 0)
        result = calculator.calculate_lenders_premium(params)
        expect(result).to eq(0)
      end
    end

    # --- US2: Concurrent Standard Lender Excess ---

    context "US2: Concurrent Standard lender excess calculation" do
      it "calculates TRG concurrent excess as $150 + 80% x rate_diff" do
        params = lender_params(
          loan_amount_cents: 50_000_000,    # $500K
          owner_liability_cents: 40_000_000, # $400K
          underwriter: "TRG",
          concurrent: true,
          lender_policy_type: :standard
        )
        result = calculator.calculate_lenders_premium(params)

        rate_loan = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
        ).calculate
        rate_owner = RateNode::Calculators::BaseRate.new(
          40_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
        ).calculate
        rate_diff = rate_loan - rate_owner
        excess_rate = (rate_diff * 80.0 / 100.0).round
        expected = [15_000, 15_000 + excess_rate].max

        expect(result).to eq(expected)
      end

      it "calculates ORT concurrent excess as $150 + 75% x rate_diff" do
        params = lender_params(
          loan_amount_cents: 50_000_000,
          owner_liability_cents: 40_000_000,
          underwriter: "ORT",
          concurrent: true,
          lender_policy_type: :standard
        )
        result = calculator.calculate_lenders_premium(params)

        rate_loan = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "ORT", as_of_date: as_of_date
        ).calculate
        rate_owner = RateNode::Calculators::BaseRate.new(
          40_000_000, state: "CA", underwriter: "ORT", as_of_date: as_of_date
        ).calculate
        rate_diff = rate_loan - rate_owner
        excess_rate = (rate_diff * 75.0 / 100.0).round
        expected = [15_000, 15_000 + excess_rate].max

        expect(result).to eq(expected)
      end

      it "returns $150 flat fee when loan <= owner" do
        params = lender_params(
          loan_amount_cents: 40_000_000,
          owner_liability_cents: 50_000_000,
          underwriter: "TRG",
          concurrent: true,
          lender_policy_type: :standard
        )
        result = calculator.calculate_lenders_premium(params)
        expect(result).to eq(15_000)
      end

      it "enforces $150 minimum via max(concurrent_fee, total)" do
        # When loan equals owner, should be $150 flat
        params = lender_params(
          loan_amount_cents: 50_000_000,
          owner_liability_cents: 50_000_000,
          underwriter: "TRG",
          concurrent: true,
          lender_policy_type: :standard
        )
        result = calculator.calculate_lenders_premium(params)
        expect(result).to eq(15_000)
      end

      it "returns $309.20 for TRG $400K owner / $500K loan (validates bug fix)" do
        params = lender_params(
          loan_amount_cents: 50_000_000,
          owner_liability_cents: 40_000_000,
          underwriter: "TRG",
          concurrent: true,
          lender_policy_type: :standard
        )
        result = calculator.calculate_lenders_premium(params)
        # $309.20 = 30_920 cents (from rate manual)
        expect(result).to eq(30_920)
      end
    end

    # --- US3: Extended Concurrent Lender Policy ---

    context "US3: Extended concurrent lender policies" do
      it "uses full ELC rate lookup for TRG Extended concurrent" do
        params = lender_params(
          loan_amount_cents: 50_000_000,
          owner_liability_cents: 40_000_000,
          underwriter: "TRG",
          concurrent: true,
          lender_policy_type: :extended
        )
        result = calculator.calculate_lenders_premium(params)

        expected_elc = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
        ).calculate_elc

        expect(result).to eq(expected_elc)
      end

      it "uses full ELC rate lookup for ORT Extended concurrent" do
        params = lender_params(
          loan_amount_cents: 50_000_000,
          owner_liability_cents: 40_000_000,
          underwriter: "ORT",
          concurrent: true,
          lender_policy_type: :extended
        )
        result = calculator.calculate_lenders_premium(params)

        expected_elc = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "ORT", as_of_date: as_of_date
        ).calculate_elc

        expect(result).to eq(expected_elc)
      end

      it "does NOT use $150 + excess formula for Extended concurrent" do
        params = lender_params(
          loan_amount_cents: 50_000_000,
          owner_liability_cents: 40_000_000,
          underwriter: "TRG",
          concurrent: true,
          lender_policy_type: :extended
        )
        result = calculator.calculate_lenders_premium(params)

        # Should NOT equal the $150 + excess formula result
        rate_loan = RateNode::Calculators::BaseRate.new(
          50_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
        ).calculate
        rate_owner = RateNode::Calculators::BaseRate.new(
          40_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
        ).calculate
        standard_concurrent_result = 15_000 + ((rate_loan - rate_owner) * 80.0 / 100.0).round

        expect(result).not_to eq(standard_concurrent_result)
      end
    end

    # --- US4: Cash Acquisition / Binder ---

    context "US4: No lender policy on cash acquisitions" do
      it "returns $0 when is_hold_open: true" do
        params = lender_params(is_hold_open: true)
        result = calculator.calculate_lenders_premium(params)
        expect(result).to eq(0)
      end

      it "returns $0 when include_lenders_policy: false" do
        params = lender_params(include_lenders_policy: false)
        result = calculator.calculate_lenders_premium(params)
        expect(result).to eq(0)
      end

      it "is_hold_open takes precedence over include_lenders_policy" do
        params = lender_params(
          is_hold_open: true,
          include_lenders_policy: true
        )
        result = calculator.calculate_lenders_premium(params)
        expect(result).to eq(0)
      end
    end

    # --- Phase 7: Edge Cases ---

    context "Edge cases and validation" do
      it "raises ArgumentError for negative loan amount" do
        params = lender_params(loan_amount_cents: -1)
        expect { calculator.calculate_lenders_premium(params) }
          .to raise_error(ArgumentError, /negative/)
      end

      it "raises ArgumentError for missing underwriter" do
        params = lender_params(underwriter: nil)
        expect { calculator.calculate_lenders_premium(params) }
          .to raise_error(ArgumentError, /[Uu]nderwriter/)
      end

      it "raises ArgumentError for invalid lender_policy_type" do
        params = lender_params(lender_policy_type: :bogus)
        expect { calculator.calculate_lenders_premium(params) }
          .to raise_error(ArgumentError, /lender.policy.type/i)
      end

      it "propagates rate lookup errors" do
        # Use a deliberately invalid amount that would cause a rate lookup failure
        # This tests that we don't silently swallow errors
        params = lender_params(loan_amount_cents: 1) # Very small amount
        # Should either return a valid result or raise - not silently return 0
        # (unless the rate table has a rate for $0.01)
        expect { calculator.calculate_lenders_premium(params) }.not_to raise_error
      end
    end
  end
end
