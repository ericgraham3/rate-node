# frozen_string_literal: true

# North Carolina Title Insurance Rates - TRG (Effective October 1, 2025)

module RateNode
  module Seeds
    module NC
      EFFECTIVE_DATE = Date.new(2025, 10, 1)
      STATE_CODE = "NC"
      UNDERWRITER_CODE = "TRG"

      # Tiered rate structure: calculate by summing across applicable brackets
      RATE_TIERS = [
        # Up to $100,000: $2.78 per thousand
        { min: 0, max: 100_000, rate: 0, per_thousand: 278, elc: 0 },
        # $100,001 to $500,000: add $2.17 per thousand
        { min: 100_001, max: 500_000, rate: 0, per_thousand: 217, elc: 0 },
        # $500,001 to $2,000,000: add $1.41 per thousand
        { min: 500_001, max: 2_000_000, rate: 0, per_thousand: 141, elc: 0 },
        # $2,000,001 to $7,000,000: add $1.08 per thousand
        { min: 2_000_001, max: 7_000_000, rate: 0, per_thousand: 108, elc: 0 },
        # $7,000,001 and above: add $0.75 per thousand
        { min: 7_000_001, max: nil, rate: 0, per_thousand: 75, elc: 0 }
      ].freeze

      REFINANCE_RATES = [
        { min: 0, max: 50_000, rate: 413 },
        { min: 50_001, max: 150_000, rate: 495 },
        { min: 150_001, max: 250_000, rate: 605 },
        { min: 250_001, max: 350_000, rate: 770 },
        { min: 350_001, max: 450_000, rate: 935 },
        { min: 450_001, max: 500_000, rate: 1_018 },
        { min: 500_001, max: 550_000, rate: 1_100 },
        { min: 550_001, max: 650_000, rate: 1_210 },
        { min: 650_001, max: 750_000, rate: 1_320 },
        { min: 750_001, max: 850_000, rate: 1_430 },
        { min: 850_001, max: 1_000_000, rate: 1_540 },
        { min: 1_000_001, max: 1_500_000, rate: 1_870 },
        { min: 1_500_001, max: 2_000_000, rate: 2_310 },
        { min: 2_000_001, max: 2_500_000, rate: 3_135 },
        { min: 2_500_001, max: 3_000_000, rate: 3_245 },
        { min: 3_000_001, max: 3_500_000, rate: 3_751 },
        { min: 3_500_001, max: 4_000_000, rate: 3_905 },
        { min: 4_000_001, max: 5_000_000, rate: 4_620 },
        { min: 5_000_001, max: 6_000_000, rate: 5_346 },
        { min: 6_000_001, max: 7_000_000, rate: 5_940 },
        { min: 7_000_001, max: 8_000_000, rate: 6_600 },
        { min: 8_000_001, max: 9_000_000, rate: 7_370 },
        { min: 9_000_001, max: 10_000_000, rate: 7_920 },
        { min: 10_000_001, max: nil, rate: 7_920 }
      ].freeze

      # NC endorsements per rate manual PR-10: exactly three endorsements at $23.00 flat each
      ENDORSEMENTS = [
        { code: "ALTA 5", name: "Planned Unit Development", pricing_type: "flat", base_amount: 2300 },
        { code: "ALTA 8.1", name: "Environmental Protection Lien (Owner)", pricing_type: "flat", base_amount: 2300 },
        { code: "ALTA 9", name: "Restrictions, Encroachments, Minerals", pricing_type: "flat", base_amount: 2300 }
      ].freeze

      # CPL (Closing Protection Letter) Rates - Tiered structure
      CPL_RATES = [
        { min: 0, max: 10_000_000, rate: 69 },            # Up to $100,000 at $0.69 per thousand
        { min: 10_000_001, max: 50_000_000, rate: 13 },   # $100,001 - $500,000 at $0.13 per thousand
        { min: 50_000_001, max: nil, rate: 0 }            # Above $500,000 at $0.00 per thousand
      ].freeze
    end
  end
end
