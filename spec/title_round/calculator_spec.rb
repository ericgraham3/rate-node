# frozen_string_literal: true

require "spec_helper"

RSpec.describe TitleRound::Calculator do
  describe "#calculate" do
    context "purchase transaction with concurrent lender policy" do
      subject(:result) do
        described_class.new(
          state: "CA",
          underwriter: "TRG",
          transaction_type: :purchase,
          purchase_price_cents: 50_000_000,
          loan_amount_cents: 40_000_000,
          owner_policy_type: :standard,
          include_lenders_policy: true
        ).calculate
      end

      it "returns a ClosingDisclosure" do
        expect(result).to be_a(TitleRound::Output::ClosingDisclosure)
      end

      it "calculates standard owner policy premium at 100% of schedule rate" do
        expect(result.owners_policy[:premium_cents]).to eq(157_100)
      end

      it "calculates concurrent lender policy at $150 flat" do
        expect(result.lenders_policy[:premium_cents]).to eq(15_000)
      end

      it "calculates correct grand total" do
        expect(result.totals[:grand_total_cents]).to eq(172_100)
      end
    end

    context "purchase with extended owner policy (125%)" do
      subject(:result) do
        described_class.new(
          state: "CA",
          underwriter: "TRG",
          transaction_type: :purchase,
          purchase_price_cents: 50_000_000,
          loan_amount_cents: 40_000_000,
          owner_policy_type: :extended,
          include_lenders_policy: true
        ).calculate
      end

      it "calculates extended owner policy premium at 125% of schedule rate" do
        expect(result.owners_policy[:premium_cents]).to eq(196_375)
      end
    end

    context "purchase with homeowner policy (110%)" do
      subject(:result) do
        described_class.new(
          state: "CA",
          underwriter: "TRG",
          transaction_type: :purchase,
          purchase_price_cents: 50_000_000,
          loan_amount_cents: 40_000_000,
          owner_policy_type: :homeowner,
          include_lenders_policy: true
        ).calculate
      end

      it "calculates homeowner policy premium at 110% of schedule rate" do
        expect(result.owners_policy[:premium_cents]).to eq(172_810)
      end
    end

    context "purchase with loan exceeding owner liability" do
      subject(:result) do
        described_class.new(
          state: "CA",
          underwriter: "TRG",
          transaction_type: :purchase,
          purchase_price_cents: 50_000_000,
          loan_amount_cents: 60_000_000,
          owner_policy_type: :standard,
          include_lenders_policy: true
        ).calculate
      end

      it "charges $150 base plus ELC rate for excess" do
        expect(result.lenders_policy[:premium_cents]).to eq(64_800)
      end
    end

    context "refinance transaction" do
      subject(:result) do
        described_class.new(
          state: "CA",
          underwriter: "TRG",
          transaction_type: :refinance,
          loan_amount_cents: 40_000_000
        ).calculate
      end

      it "uses refinance rate table" do
        expect(result.lenders_policy[:premium_cents]).to eq(85_000)
      end

      it "does not include owner policy" do
        expect(result.owners_policy).to be_nil
      end
    end

    context "purchase without lender policy" do
      subject(:result) do
        described_class.new(
          state: "CA",
          underwriter: "TRG",
          transaction_type: :purchase,
          purchase_price_cents: 50_000_000,
          loan_amount_cents: 0,
          owner_policy_type: :standard,
          include_lenders_policy: false
        ).calculate
      end

      it "does not include lender policy" do
        expect(result.lenders_policy).to be_nil
      end

      it "only charges owner premium" do
        expect(result.totals[:grand_total_cents]).to eq(157_100)
      end
    end
  end
end
