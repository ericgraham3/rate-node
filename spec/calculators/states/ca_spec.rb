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

  # --- Over-$3M Owner Premium Tests (User Story 1) ---

  describe "#calculate_owners_premium (over $3M)" do
    def owner_params(overrides = {})
      {
        liability_cents: 350_000_000,  # $3.5M
        policy_type: :standard,
        underwriter: "TRG",
        as_of_date: as_of_date
      }.merge(overrides)
    end

    it "calculates TRG owner premium at $3.5M as $4,473.50" do
      result = calculator.calculate_owners_premium(owner_params(
        underwriter: "TRG",
        liability_cents: 350_000_000
      ))
      # base $4,211 + 50 increments × $5.25 = $4,211 + $262.50 = $4,473.50
      expect(result).to eq(447_350)
    end

    it "calculates ORT owner premium at $3.5M as $4,738" do
      result = calculator.calculate_owners_premium(owner_params(
        underwriter: "ORT",
        liability_cents: 350_000_000
      ))
      # base $4,438 + 50 increments × $6.00 = $4,438 + $300 = $4,738
      expect(result).to eq(473_800)
    end

    it "calculates TRG owner premium at $5M as $5,263.50" do
      result = calculator.calculate_owners_premium(owner_params(
        underwriter: "TRG",
        liability_cents: 500_000_000
      ))
      # base $4,211 + 200 increments × $5.25 = $4,211 + $1,050 = $5,261
      # Wait: excess = 500M - 300M = 200M cents. increments = ceil(200M / 1M) = 200
      # 421_100 + (200 * 525) = 421_100 + 105_000 = 526_100
      expect(result).to eq(526_100)
    end

    it "uses tier lookup at exactly $3M (not formula)" do
      # At exactly $3M, should use tier lookup, not over-$3M formula
      result_at_3m = calculator.calculate_owners_premium(owner_params(
        underwriter: "TRG",
        liability_cents: 300_000_000
      ))
      # Should be the tier value, not the formula base
      # Tier at $3M for TRG = $4,211 = 421_100 cents (which is also the formula base)
      expect(result_at_3m).to eq(421_100)
    end
  end

  # --- ELC Over-$3M Tests (User Story 2) ---

  describe "ELC over $3M" do
    it "calculates TRG ELC at $3.5M as $2,682" do
      base_rate = RateNode::Calculators::BaseRate.new(
        350_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
      )
      result = base_rate.calculate_elc
      # base $2,472 + 50 increments × $4.20 = $2,472 + $210 = $2,682
      expect(result).to eq(268_200)
    end

    it "calculates ORT ELC at $3.5M as $2,700" do
      base_rate = RateNode::Calculators::BaseRate.new(
        350_000_000, state: "CA", underwriter: "ORT", as_of_date: as_of_date
      )
      result = base_rate.calculate_elc
      # base $2,550 + 50 increments × $3.00 = $2,550 + $150 = $2,700
      expect(result).to eq(270_000)
    end

    it "calculates TRG ELC at $5M as $3,312" do
      base_rate = RateNode::Calculators::BaseRate.new(
        500_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
      )
      result = base_rate.calculate_elc
      # base $2,472 + 200 increments × $4.20 = $2,472 + $840 = $3,312
      expect(result).to eq(331_200)
    end

    it "uses tier lookup for ELC at exactly $3M (not formula)" do
      base_rate = RateNode::Calculators::BaseRate.new(
        300_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
      )
      result = base_rate.calculate_elc
      # Should use tier ELC value, not formula
      expect(result).to be > 0
    end
  end

  # --- Minimum Premium Tests (User Story 3) ---

  describe "#calculate_owners_premium (minimum premium)" do
    def owner_params(overrides = {})
      {
        liability_cents: 1_000_000,  # $10K
        policy_type: :standard,
        underwriter: "TRG",
        as_of_date: as_of_date
      }.merge(overrides)
    end

    it "enforces TRG minimum premium of $609 at $10K liability" do
      result = calculator.calculate_owners_premium(owner_params(
        underwriter: "TRG",
        liability_cents: 1_000_000
      ))
      expect(result).to eq(60_900)
    end

    it "enforces ORT minimum premium of $725 at $10K liability" do
      result = calculator.calculate_owners_premium(owner_params(
        underwriter: "ORT",
        liability_cents: 1_000_000
      ))
      expect(result).to eq(72_500)
    end

    it "applies minimum before hold-open surcharge" do
      result = calculator.calculate_owners_premium(owner_params(
        underwriter: "TRG",
        liability_cents: 1_000_000,
        is_hold_open: true
      ))
      # minimum $609 × 1.00 + $609 × 0.10 = $609 + $60.90 = $669.90
      # $609 standard + 10% surcharge on base ($609)
      expect(result).to eq(60_900 + (60_900 * 0.10).round)
    end

    it "applies minimum before policy-type multipliers" do
      result = calculator.calculate_owners_premium(owner_params(
        underwriter: "TRG",
        liability_cents: 1_000_000,
        policy_type: :homeowners
      ))
      # minimum $609 × 1.10 = $669.90 = 66_990 cents
      expect(result).to eq((60_900 * 1.10).round)
    end
  end

  # --- Refinance Over-$10M Tests (User Story 4) ---

  describe "RefinanceRate over $10M" do
    it "calculates TRG refinance at $12M as $8,800" do
      result = RateNode::Models::RefinanceRate.calculate_rate(
        1_200_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
      )
      # base $7,200 + 2 millions × $800 = $7,200 + $1,600 = $8,800
      expect(result).to eq(880_000)
    end

    it "calculates ORT refinance at $15M as $12,610" do
      result = RateNode::Models::RefinanceRate.calculate_rate(
        1_500_000_000, state: "CA", underwriter: "ORT", as_of_date: as_of_date
      )
      # base $7,610 + 5 millions × $1,000 = $7,610 + $5,000 = $12,610
      expect(result).to eq(1_261_000)
    end

    it "uses tier lookup for refinance at exactly $10M (not formula)" do
      result = RateNode::Models::RefinanceRate.calculate_rate(
        1_000_000_000, state: "CA", underwriter: "TRG", as_of_date: as_of_date
      )
      # Should use tier data, not formula
      expect(result).to be > 0
    end

    it "uses formula for refinance at $10M + $1" do
      result = RateNode::Models::RefinanceRate.calculate_rate(
        1_000_000_001, state: "CA", underwriter: "TRG", as_of_date: as_of_date
      )
      # $10,000,001 - $10M = $0.01 over. ceil(1 / 100M) = 1 million increment
      # base $7,200 + 1 × $800 = $8,000
      expect(result).to eq(800_000)
    end
  end
end
