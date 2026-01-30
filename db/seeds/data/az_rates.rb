# frozen_string_literal: true

# Arizona Title Insurance Rates
# Two underwriters: TRG (Title Resources Guaranty) and ORT (Old Republic Title)
#
# TRG: 2 regions, $5k rounding, hold-open support
#   Region 1: Apache, Cochise, Coconino, Gila, Graham, Greenlee, Maricopa, Navajo, Pinal, Santa Cruz, Yavapai, Yuma
#   Region 2: La Paz, Mohave, Pima
#
# ORT: Area 1 only, $20k rounding, no hold-open
#   Area 1: Coconino, Maricopa, Pima, Pinal, Yavapai

module RateNode
  module Seeds
    module AZ_TRG
      EFFECTIVE_DATE = Date.new(2025, 1, 1)
      STATE_CODE = "AZ"
      UNDERWRITER_CODE = "TRG"

      # TRG Region 1 Rate Tiers (values in cents)
      # Per rate manual: Lookup table $100k-$300k, then $12.05 per $5k above $300k
      # Minimum: $730
      RATE_TIERS_REGION_1 = [
        # Lookup table section ($0 - $300,000) from rate manual
        { min: 0, max: 10_000_000, base: 73_000, per_thousand: 0 },              # $0-$100k: $730 (minimum)
        { min: 10_000_001, max: 10_500_000, base: 78_300, per_thousand: 0 },     # $100,001-$105k: $783
        { min: 10_500_001, max: 11_000_000, base: 79_800, per_thousand: 0 },     # $105,001-$110k: $798
        { min: 11_000_001, max: 11_500_000, base: 81_300, per_thousand: 0 },     # $110,001-$115k: $813
        { min: 11_500_001, max: 12_000_000, base: 82_800, per_thousand: 0 },     # $115,001-$120k: $828
        { min: 12_000_001, max: 12_500_000, base: 84_400, per_thousand: 0 },     # $120,001-$125k: $844
        { min: 12_500_001, max: 13_000_000, base: 85_900, per_thousand: 0 },     # $125,001-$130k: $859
        { min: 13_000_001, max: 13_500_000, base: 87_400, per_thousand: 0 },     # $130,001-$135k: $874
        { min: 13_500_001, max: 14_000_000, base: 88_900, per_thousand: 0 },     # $135,001-$140k: $889
        { min: 14_000_001, max: 14_500_000, base: 90_500, per_thousand: 0 },     # $140,001-$145k: $905
        { min: 14_500_001, max: 15_000_000, base: 92_000, per_thousand: 0 },     # $145,001-$150k: $920
        { min: 15_000_001, max: 15_500_000, base: 93_500, per_thousand: 0 },     # $150,001-$155k: $935
        { min: 15_500_001, max: 16_000_000, base: 95_000, per_thousand: 0 },     # $155,001-$160k: $950
        { min: 16_000_001, max: 16_500_000, base: 96_600, per_thousand: 0 },     # $160,001-$165k: $966
        { min: 16_500_001, max: 17_000_000, base: 98_100, per_thousand: 0 },     # $165,001-$170k: $981
        { min: 17_000_001, max: 17_500_000, base: 99_600, per_thousand: 0 },     # $170,001-$175k: $996
        { min: 17_500_001, max: 18_000_000, base: 101_100, per_thousand: 0 },    # $175,001-$180k: $1,011
        { min: 18_000_001, max: 18_500_000, base: 102_700, per_thousand: 0 },    # $180,001-$185k: $1,027
        { min: 18_500_001, max: 19_000_000, base: 104_200, per_thousand: 0 },    # $185,001-$190k: $1,042
        { min: 19_000_001, max: 19_500_000, base: 105_700, per_thousand: 0 },    # $190,001-$195k: $1,057
        { min: 19_500_001, max: 20_000_000, base: 107_200, per_thousand: 0 },    # $195,001-$200k: $1,072
        { min: 20_000_001, max: 20_500_000, base: 108_800, per_thousand: 0 },    # $200,001-$205k: $1,088
        { min: 20_500_001, max: 21_000_000, base: 110_300, per_thousand: 0 },    # $205,001-$210k: $1,103
        { min: 21_000_001, max: 21_500_000, base: 111_800, per_thousand: 0 },    # $210,001-$215k: $1,118
        { min: 21_500_001, max: 22_000_000, base: 113_300, per_thousand: 0 },    # $215,001-$220k: $1,133
        { min: 22_000_001, max: 22_500_000, base: 114_900, per_thousand: 0 },    # $220,001-$225k: $1,149
        { min: 22_500_001, max: 23_000_000, base: 116_400, per_thousand: 0 },    # $225,001-$230k: $1,164
        { min: 23_000_001, max: 23_500_000, base: 117_900, per_thousand: 0 },    # $230,001-$235k: $1,179
        { min: 23_500_001, max: 24_000_000, base: 119_400, per_thousand: 0 },    # $235,001-$240k: $1,194
        { min: 24_000_001, max: 24_500_000, base: 121_000, per_thousand: 0 },    # $240,001-$245k: $1,210
        { min: 24_500_001, max: 25_000_000, base: 122_500, per_thousand: 0 },    # $245,001-$250k: $1,225
        { min: 25_000_001, max: 25_500_000, base: 124_000, per_thousand: 0 },    # $250,001-$255k: $1,240
        { min: 25_500_001, max: 26_000_000, base: 125_500, per_thousand: 0 },    # $255,001-$260k: $1,255
        { min: 26_000_001, max: 26_500_000, base: 127_100, per_thousand: 0 },    # $260,001-$265k: $1,271
        { min: 26_500_001, max: 27_000_000, base: 128_600, per_thousand: 0 },    # $265,001-$270k: $1,286
        { min: 27_000_001, max: 27_500_000, base: 130_100, per_thousand: 0 },    # $270,001-$275k: $1,301
        { min: 27_500_001, max: 28_000_000, base: 131_600, per_thousand: 0 },    # $275,001-$280k: $1,316
        { min: 28_000_001, max: 28_500_000, base: 133_200, per_thousand: 0 },    # $280,001-$285k: $1,332
        { min: 28_500_001, max: 29_000_000, base: 134_700, per_thousand: 0 },    # $285,001-$290k: $1,347
        { min: 29_000_001, max: 29_500_000, base: 136_200, per_thousand: 0 },    # $290,001-$295k: $1,362
        { min: 29_500_001, max: 30_000_000, base: 137_700, per_thousand: 0 },    # $295,001-$300k: $1,377
        # Above $300k: $1,377 base + $12.05 per $5k = $2.41/thousand
        { min: 30_000_001, max: nil, base: 137_700, per_thousand: 241 }          # $300k+: $1,377 + $2.41/thousand
      ].freeze

      # TRG Region 2 Rate Tiers (values in cents)
      # Per rate manual: Minimum $600, tiered calculation
      # $50k-$100k: $786
      # $100k-$300k: $16.48 per $5k = $3.296/thousand
      # $300k+: $12.60 per $5k = $2.52/thousand
      RATE_TIERS_REGION_2 = [
        { min: 0, max: 5_000_000, base: 60_000, per_thousand: 0 },               # $0-$50k: $600 minimum
        { min: 5_000_001, max: 10_000_000, base: 78_600, per_thousand: 0 },      # $50,001-$100k: $786
        # $100k-$300k: $786 + ($16.48 per $5k) = $786 + $3.296/thousand
        { min: 10_000_001, max: 30_000_000, base: 78_600, per_thousand: 330 },   # $3.30/thousand from $100k
        # $300k+: continue from $300k value with $12.60 per $5k = $2.52/thousand
        # At $300k: $786 + (200k × $3.30/thousand) = $786 + $660 = $1,446
        { min: 30_000_001, max: nil, base: 144_600, per_thousand: 252 }          # $1,446 + $2.52/thousand
      ].freeze

      # For unified seeding, we use Region 1 as the default (most common)
      # The calculator handles region-specific logic
      RATE_TIERS = RATE_TIERS_REGION_1

      REFINANCE_RATES = [].freeze  # AZ doesn't have separate refinance rates

      # AZ TRG Endorsements - flat $100 each for common endorsements
      ENDORSEMENTS = [
        { code: "ALTA 5.1", form_code: "ALTA 5.1", name: "Planned Unit Development", pricing_type: "flat", base_amount: 10_000 },
        { code: "ALTA 8.1", form_code: "ALTA 8.1", name: "Environmental Protection Lien", pricing_type: "flat", base_amount: 10_000 },
        { code: "ALTA 9", form_code: "ALTA 9", name: "Restrictions, Encroachments, Minerals", pricing_type: "flat", base_amount: 10_000 }
      ].freeze

      CPL_RATES = [].freeze  # AZ uses flat fee from state_rules
    end

    module AZ_ORT
      EFFECTIVE_DATE = Date.new(2025, 1, 1)
      STATE_CODE = "AZ"
      UNDERWRITER_CODE = "ORT"

      # ORT Area 1 Rate Tiers (values in cents)
      # Per rate manual: Fixed $20k brackets up to $1M, then $40 per $20k above $1M
      # Minimum: $830
      RATE_TIERS = [
        { min: 0, max: 10_000_000, base: 83_000, per_thousand: 0 },              # $0-$100k: $830
        { min: 10_000_001, max: 12_000_000, base: 91_700, per_thousand: 0 },     # $100,001-$120k: $917
        { min: 12_000_001, max: 14_000_000, base: 98_400, per_thousand: 0 },     # $120,001-$140k: $984
        { min: 14_000_001, max: 16_000_000, base: 107_400, per_thousand: 0 },    # $140,001-$160k: $1,074
        { min: 16_000_001, max: 18_000_000, base: 114_900, per_thousand: 0 },    # $160,001-$180k: $1,149
        { min: 18_000_001, max: 20_000_000, base: 122_400, per_thousand: 0 },    # $180,001-$200k: $1,224
        { min: 20_000_001, max: 22_000_000, base: 128_100, per_thousand: 0 },    # $200,001-$220k: $1,281
        { min: 22_000_001, max: 24_000_000, base: 134_100, per_thousand: 0 },    # $220,001-$240k: $1,341
        { min: 24_000_001, max: 26_000_000, base: 140_300, per_thousand: 0 },    # $240,001-$260k: $1,403
        { min: 26_000_001, max: 28_000_000, base: 146_400, per_thousand: 0 },    # $260,001-$280k: $1,464
        { min: 28_000_001, max: 30_000_000, base: 152_500, per_thousand: 0 },    # $280,001-$300k: $1,525
        { min: 30_000_001, max: 32_000_000, base: 157_900, per_thousand: 0 },    # $300,001-$320k: $1,579
        { min: 32_000_001, max: 34_000_000, base: 164_000, per_thousand: 0 },    # $320,001-$340k: $1,640
        { min: 34_000_001, max: 36_000_000, base: 170_100, per_thousand: 0 },    # $340,001-$360k: $1,701
        { min: 36_000_001, max: 38_000_000, base: 176_200, per_thousand: 0 },    # $360,001-$380k: $1,762
        { min: 38_000_001, max: 40_000_000, base: 182_200, per_thousand: 0 },    # $380,001-$400k: $1,822
        { min: 40_000_001, max: 42_000_000, base: 187_700, per_thousand: 0 },    # $400,001-$420k: $1,877
        { min: 42_000_001, max: 44_000_000, base: 193_100, per_thousand: 0 },    # $420,001-$440k: $1,931
        { min: 44_000_001, max: 46_000_000, base: 198_400, per_thousand: 0 },    # $440,001-$460k: $1,984
        { min: 46_000_001, max: 48_000_000, base: 203_800, per_thousand: 0 },    # $460,001-$480k: $2,038
        { min: 48_000_001, max: 50_000_000, base: 209_200, per_thousand: 0 },    # $480,001-$500k: $2,092
        # Above $1M: Add $40 per $20k = $2/thousand
        { min: 100_000_001, max: nil, base: 325_700, per_thousand: 200 }         # $1M+: base + $40 per $20k
      ].freeze

      REFINANCE_RATES = [].freeze  # AZ doesn't have separate refinance rates

      # ORT Endorsements - same as TRG
      ENDORSEMENTS = [
        { code: "ALTA 5.1", form_code: "ALTA 5.1", name: "Planned Unit Development", pricing_type: "flat", base_amount: 10_000 },
        { code: "ALTA 8.1", form_code: "ALTA 8.1", name: "Environmental Protection Lien", pricing_type: "flat", base_amount: 10_000 },
        { code: "ALTA 9", form_code: "ALTA 9", name: "Restrictions, Encroachments, Minerals", pricing_type: "flat", base_amount: 10_000 }
      ].freeze

      CPL_RATES = [].freeze  # AZ uses flat fee from state_rules
    end
  end
end
