# frozen_string_literal: true

require "spec_helper"

RSpec.describe TitleRound::Calculators::BaseRate do
  describe "#rounded_liability" do
    it "returns same value when already on $10K boundary" do
      rate = described_class.new(50_000_000, state: "CA", underwriter: "TRG")
      expect(rate.rounded_liability).to eq(50_000_000)
    end

    it "rounds up to next $10K for values not on boundary" do
      rate = described_class.new(50_000_001, state: "CA", underwriter: "TRG")
      expect(rate.rounded_liability).to eq(51_000_000)
    end

    it "rounds $550,001 up to $560,000" do
      rate = described_class.new(55_000_100, state: "CA", underwriter: "TRG")
      expect(rate.rounded_liability).to eq(56_000_000)
    end
  end

  describe "#calculate" do
    it "uses rounded liability for rate lookup" do
      rate_on_boundary = described_class.new(50_000_000, state: "CA", underwriter: "TRG").calculate
      rate_just_over = described_class.new(50_000_100, state: "CA", underwriter: "TRG").calculate

      expect(rate_just_over).to be > rate_on_boundary
    end
  end
end
