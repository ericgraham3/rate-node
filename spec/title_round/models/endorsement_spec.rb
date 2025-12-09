# frozen_string_literal: true

require "spec_helper"

RSpec.describe TitleRound::Models::Endorsement do
  describe "#calculate_premium" do
    context "flat fee endorsement" do
      let(:endorsement) { described_class.find_by_code("CLTA 115") }

      it "returns the flat base amount" do
        expect(endorsement.calculate_premium(50_000_000)).to eq(2500)
      end
    end

    context "no charge endorsement" do
      let(:endorsement) { described_class.find_by_code("ALTA 4.1") }

      it "returns zero" do
        expect(endorsement.calculate_premium(50_000_000)).to eq(0)
      end
    end

    context "percentage endorsement" do
      let(:endorsement) { described_class.find_by_code("CLTA 100") }

      it "calculates percentage of Schedule of Rates, not liability" do
        premium = endorsement.calculate_premium(50_000_000)
        expect(premium).to eq(47_130)
      end
    end

    context "percentage endorsement with minimum" do
      let(:endorsement) { described_class.find_by_code("CLTA 123.1") }

      it "enforces minimum charge" do
        premium = endorsement.calculate_premium(2_000_000)
        expect(premium).to be >= 10_000
      end
    end
  end
end
