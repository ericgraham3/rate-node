# frozen_string_literal: true

# California Title Insurance Rates - ORT (Effective March 17, 2025)
#
# Source: ORTC_CA_RATE_MANUAL_3.17.2025
# Rate structure: OR Insurance Rate in $10,000 increments
# Minimum charge: $725
# Above $3M: base $4,438 + $6 per $10,000

module RateNode
  module Seeds
    module CA_ORT
      EFFECTIVE_DATE = Date.new(2025, 3, 17)
      STATE_CODE = "CA"
      UNDERWRITER_CODE = "ORT"

      # Unit declaration for shared seeder: rate values are in dollars, convert to cents
      RATE_TIERS_UNIT = :dollars

      # Standard rate (OR Insurance Rate) and Extended Lender Concurrent (ELC) rate
      # per $10K liability bracket.
      #
      # Known data points from ORT rate manual (confirmed):
      #   $100K: $725,  $150K: $850,  $200K: $985,  $250K: $1,100
      #   $300K: $1,210, $350K: $1,300, $400K: $1,390, $450K: $1,500
      #   $500K: $1,600, $550K: $1,685, $600K: $1,770, $650K: $1,860
      #   $700K: $1,950, $750K: $2,040, $800K: $2,130, $850K: $2,220
      #   $900K: $2,310, $950K: $2,395, $1M: $2,480
      #
      # Known ELC data points (confirmed from rate manual comparison table):
      #   $100K: $465,  $150K: $543, $250K: $653, $350K: $782
      #   $400K: $852,  $450K: $940, $500K: $1,015, $550K: $1,067
      #
      # Intermediate values interpolated linearly between known data points.
      RATE_TIERS = [
        # $0-$100K flat range (minimum $725)
        { min: 0, max: 100_000, rate: 725, elc: 465 },
        # $100K-$150K: rate +$25/step
        { min: 100_001, max: 110_000, rate: 750, elc: 481 },
        { min: 110_001, max: 120_000, rate: 775, elc: 497 },
        { min: 120_001, max: 130_000, rate: 800, elc: 512 },
        { min: 130_001, max: 140_000, rate: 825, elc: 528 },
        { min: 140_001, max: 150_000, rate: 850, elc: 543 },
        # $150K-$200K: rate +$35 at boundary then +$25/step
        { min: 150_001, max: 160_000, rate: 885, elc: 554 },
        { min: 160_001, max: 170_000, rate: 910, elc: 565 },
        { min: 170_001, max: 180_000, rate: 935, elc: 576 },
        { min: 180_001, max: 190_000, rate: 960, elc: 587 },
        { min: 190_001, max: 200_000, rate: 985, elc: 598 },
        # $200K-$250K: rate +$23/step, ELC +$11/step
        { min: 200_001, max: 210_000, rate: 1_008, elc: 609 },
        { min: 210_001, max: 220_000, rate: 1_031, elc: 620 },
        { min: 220_001, max: 230_000, rate: 1_054, elc: 631 },
        { min: 230_001, max: 240_000, rate: 1_077, elc: 642 },
        { min: 240_001, max: 250_000, rate: 1_100, elc: 653 },
        # $250K-$300K: rate +$22/step, ELC +$13/step
        { min: 250_001, max: 260_000, rate: 1_122, elc: 666 },
        { min: 260_001, max: 270_000, rate: 1_144, elc: 679 },
        { min: 270_001, max: 280_000, rate: 1_166, elc: 691 },
        { min: 280_001, max: 290_000, rate: 1_188, elc: 704 },
        { min: 290_001, max: 300_000, rate: 1_210, elc: 717 },
        # $300K-$350K: rate +$18/step, ELC +$13/step
        { min: 300_001, max: 310_000, rate: 1_228, elc: 730 },
        { min: 310_001, max: 320_000, rate: 1_246, elc: 743 },
        { min: 320_001, max: 330_000, rate: 1_264, elc: 755 },
        { min: 330_001, max: 340_000, rate: 1_282, elc: 768 },
        { min: 340_001, max: 350_000, rate: 1_300, elc: 782 },
        # $350K-$400K: rate +$18/step, ELC +$14/step
        { min: 350_001, max: 360_000, rate: 1_318, elc: 796 },
        { min: 360_001, max: 370_000, rate: 1_336, elc: 810 },
        { min: 370_001, max: 380_000, rate: 1_354, elc: 824 },
        { min: 380_001, max: 390_000, rate: 1_372, elc: 838 },
        { min: 390_001, max: 400_000, rate: 1_390, elc: 852 },
        # $400K-$450K: rate +$22/step, ELC from $880-$940
        { min: 400_001, max: 410_000, rate: 1_412, elc: 880 },
        { min: 410_001, max: 420_000, rate: 1_434, elc: 895 },
        { min: 420_001, max: 430_000, rate: 1_456, elc: 910 },
        { min: 430_001, max: 440_000, rate: 1_478, elc: 925 },
        { min: 440_001, max: 450_000, rate: 1_500, elc: 940 },
        # $450K-$500K: rate +$20/step, ELC +$15/step
        { min: 450_001, max: 460_000, rate: 1_520, elc: 955 },
        { min: 460_001, max: 470_000, rate: 1_540, elc: 970 },
        { min: 470_001, max: 480_000, rate: 1_560, elc: 985 },
        { min: 480_001, max: 490_000, rate: 1_580, elc: 1_000 },
        { min: 490_001, max: 500_000, rate: 1_600, elc: 1_015 },
        # $500K-$550K: rate +$17/step, ELC ~+$10/step
        { min: 500_001, max: 510_000, rate: 1_617, elc: 1_025 },
        { min: 510_001, max: 520_000, rate: 1_634, elc: 1_036 },
        { min: 520_001, max: 530_000, rate: 1_651, elc: 1_046 },
        { min: 530_001, max: 540_000, rate: 1_668, elc: 1_057 },
        { min: 540_001, max: 550_000, rate: 1_685, elc: 1_067 },
        # $550K-$600K: rate +$17/step, ELC ~+$11/step
        { min: 550_001, max: 560_000, rate: 1_702, elc: 1_078 },
        { min: 560_001, max: 570_000, rate: 1_719, elc: 1_088 },
        { min: 570_001, max: 580_000, rate: 1_736, elc: 1_099 },
        { min: 580_001, max: 590_000, rate: 1_753, elc: 1_109 },
        { min: 590_001, max: 600_000, rate: 1_770, elc: 1_120 },
        # $600K-$650K: rate +$18/step, ELC ~+$10/step
        { min: 600_001, max: 610_000, rate: 1_788, elc: 1_130 },
        { min: 610_001, max: 620_000, rate: 1_806, elc: 1_141 },
        { min: 620_001, max: 630_000, rate: 1_824, elc: 1_151 },
        { min: 630_001, max: 640_000, rate: 1_842, elc: 1_162 },
        { min: 640_001, max: 650_000, rate: 1_860, elc: 1_172 },
        # $650K-$700K: rate +$18/step, ELC ~+$11/step
        { min: 650_001, max: 660_000, rate: 1_878, elc: 1_183 },
        { min: 660_001, max: 670_000, rate: 1_896, elc: 1_194 },
        { min: 670_001, max: 680_000, rate: 1_914, elc: 1_205 },
        { min: 680_001, max: 690_000, rate: 1_932, elc: 1_216 },
        { min: 690_001, max: 700_000, rate: 1_950, elc: 1_227 },
        # $700K-$750K: rate +$18/step, ELC ~+$11/step
        { min: 700_001, max: 710_000, rate: 1_968, elc: 1_238 },
        { min: 710_001, max: 720_000, rate: 1_986, elc: 1_248 },
        { min: 720_001, max: 730_000, rate: 2_004, elc: 1_259 },
        { min: 730_001, max: 740_000, rate: 2_022, elc: 1_270 },
        { min: 740_001, max: 750_000, rate: 2_040, elc: 1_281 },
        # $750K-$800K: rate +$18/step, ELC +$11/step
        { min: 750_001, max: 760_000, rate: 2_058, elc: 1_292 },
        { min: 760_001, max: 770_000, rate: 2_076, elc: 1_303 },
        { min: 770_001, max: 780_000, rate: 2_094, elc: 1_314 },
        { min: 780_001, max: 790_000, rate: 2_112, elc: 1_325 },
        { min: 790_001, max: 800_000, rate: 2_130, elc: 1_336 },
        # $800K-$850K: rate +$18/step, ELC +$11/step
        { min: 800_001, max: 810_000, rate: 2_148, elc: 1_347 },
        { min: 810_001, max: 820_000, rate: 2_166, elc: 1_358 },
        { min: 820_001, max: 830_000, rate: 2_184, elc: 1_369 },
        { min: 830_001, max: 840_000, rate: 2_202, elc: 1_380 },
        { min: 840_001, max: 850_000, rate: 2_220, elc: 1_391 },
        # $850K-$900K: rate +$18/step, ELC ~+$8/step
        { min: 850_001, max: 860_000, rate: 2_238, elc: 1_399 },
        { min: 860_001, max: 870_000, rate: 2_256, elc: 1_406 },
        { min: 870_001, max: 880_000, rate: 2_274, elc: 1_414 },
        { min: 880_001, max: 890_000, rate: 2_292, elc: 1_421 },
        { min: 890_001, max: 900_000, rate: 2_310, elc: 1_429 },
        # $900K-$950K: rate +$17/step, ELC ~+$7/step
        { min: 900_001, max: 910_000, rate: 2_327, elc: 1_436 },
        { min: 910_001, max: 920_000, rate: 2_344, elc: 1_444 },
        { min: 920_001, max: 930_000, rate: 2_361, elc: 1_451 },
        { min: 930_001, max: 940_000, rate: 2_378, elc: 1_459 },
        { min: 940_001, max: 950_000, rate: 2_395, elc: 1_466 },
        # $950K-$1M: rate +$17/step, ELC ~+$8/step
        { min: 950_001, max: 960_000, rate: 2_412, elc: 1_474 },
        { min: 960_001, max: 970_000, rate: 2_429, elc: 1_482 },
        { min: 970_001, max: 980_000, rate: 2_446, elc: 1_489 },
        { min: 980_001, max: 990_000, rate: 2_463, elc: 1_497 },
        { min: 990_001, max: 1_000_000, rate: 2_480, elc: 1_504 },
        # Above $1M: larger brackets using endpoint rates
        { min: 1_000_001, max: 1_250_000, rate: 2_825, elc: 1_640 },
        { min: 1_250_001, max: 1_500_000, rate: 3_150, elc: 1_780 },
        { min: 1_500_001, max: 1_750_000, rate: 3_450, elc: 1_890 },
        { min: 1_750_001, max: 2_000_000, rate: 3_775, elc: 2_000 },
        { min: 2_000_001, max: 2_250_000, rate: 3_938, elc: 2_138 },
        { min: 2_250_001, max: 2_500_000, rate: 4_113, elc: 2_275 },
        { min: 2_500_001, max: 2_750_000, rate: 4_275, elc: 2_413 },
        { min: 2_750_001, max: 3_000_000, rate: 4_438, elc: 2_550 },
        { min: 3_000_001, max: nil, rate: 4_438, elc: 2_550 }
      ].freeze

      # ORT Residential Financing rates (Section 2.3)
      REFINANCE_RATES = [
        { min: 0, max: 250_000, rate: 450 },
        { min: 250_001, max: 500_000, rate: 645 },
        { min: 500_001, max: 750_000, rate: 800 },
        { min: 750_001, max: 1_000_000, rate: 1_100 },
        { min: 1_000_001, max: 1_500_000, rate: 1_500 },
        { min: 1_500_001, max: 2_000_000, rate: 2_100 },
        { min: 2_000_001, max: 3_000_000, rate: 2_800 },
        { min: 3_000_001, max: 4_000_000, rate: 3_400 },
        { min: 4_000_001, max: 5_000_000, rate: 4_100 },
        { min: 5_000_001, max: 6_000_000, rate: 4_700 },
        { min: 6_000_001, max: 7_000_000, rate: 5_300 },
        { min: 7_000_001, max: 8_000_000, rate: 5_900 },
        { min: 8_000_001, max: 9_000_000, rate: 6_600 },
        { min: 9_000_001, max: 10_000_000, rate: 7_100 },
        { min: 10_000_001, max: nil, rate: 7_100 }
      ].freeze

      # ORT CA endorsements
      # Pricing per ORTC_CA_RATE_MANUAL_3.17.2025
      # Key difference from TRG: ALTA 8.1 is $25 flat (TRG is no_charge)
      ENDORSEMENTS = [
        { code: "CLTA 100", name: "Restrictions, Encroachments & Minerals (Owner Standard)", pricing_type: "percentage", percentage: 0.30, owner_only: true },
        { code: "CLTA 100.1", name: "Restrictions, Encroachments & Minerals (Lender Standard)", pricing_type: "percentage", percentage: 0.25, lender_only: true },
        { code: "ALTA 9", name: "Restrictions, Encroachments, Minerals - Loan Policy", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 9.3", name: "Covenants, Conditions and Restrictions - Loan Policy", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 5", name: "Planned Unit Development (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 5.1", name: "Planned Unit Development (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 8.1", name: "Environmental Protection Lien (Lender)", pricing_type: "flat", base_amount: 2500, lender_only: true },
        { code: "ALTA 8.2", name: "Environmental Protection Lien (Owner)", pricing_type: "flat", base_amount: 2500, owner_only: true },
        { code: "ALTA 4", name: "Condominium (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 4.1", name: "Condominium (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 6", name: "Variable Rate Mortgage", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 6.2", name: "Variable Rate Mortgage, Negative Amortization", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 17", name: "Access and Entry", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 17.1", name: "Indirect Access and Entry", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 17.2", name: "Utility Access", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 7", name: "Manufactured Housing Unit", pricing_type: "no_charge" },
        { code: "ALTA 7.1", name: "Manufactured Housing - Conversion (Loan)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 7.2", name: "Manufactured Housing - Conversion (Owner)", pricing_type: "no_charge", owner_only: true },
        { code: "CLTA 103.5", name: "Water Rights, Surface Damage", pricing_type: "flat", base_amount: 2500 },
        { code: "CLTA 103.7", name: "Land Abuts Street", pricing_type: "flat", base_amount: 2500 },
        { code: "CLTA 115", name: "Condominium", pricing_type: "flat", base_amount: 2500 },
        { code: "CLTA 116.7", name: "Subdivision Map Act Compliance", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 26", name: "Subdivision", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 18", name: "Single Tax Parcel", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 18.1", name: "Multiple Tax Parcel", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 19", name: "Contiguity, Multiple Parcels", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 19.1", name: "Contiguity, Single Parcel", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 22", name: "Location", pricing_type: "no_charge" },
        { code: "ALTA 22.1", name: "Location and Map", pricing_type: "no_charge" },
        { code: "ALTA 25", name: "Same as Survey", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 25.1", name: "Same as Portion of Survey", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 28", name: "Easement, Damage or Enforced Removal (Owner)", pricing_type: "percentage", percentage: 0.20, owner_only: true },
        { code: "ALTA 28 LENDER", name: "Easement, Damage or Enforced Removal (Lender)", pricing_type: "flat", base_amount: 2500, lender_only: true },
        { code: "CLTA 123.1", name: "Zoning - Unimproved Land", pricing_type: "percentage", percentage: 0.10, min: 10000 },
        { code: "ALTA 3", name: "Zoning - Unimproved Land", pricing_type: "percentage", percentage: 0.10, min: 10000 },
        { code: "ALTA 3.1", name: "Zoning - Improved Land", pricing_type: "percentage", percentage: 0.15, min: 10000 },
        { code: "CLTA 127", name: "Nonimputation - Full Equity Transfer", pricing_type: "flat", base_amount: 10000, owner_only: true },
        { code: "ALTA 15", name: "Nonimputation - Full Equity Transfer", pricing_type: "flat", base_amount: 10000, owner_only: true },
        { code: "ALTA 15.1", name: "Nonimputation - Additional Insured", pricing_type: "flat", base_amount: 10000, owner_only: true },
        { code: "ALTA 15.2", name: "Nonimputation - Partial Equity Transfer", pricing_type: "flat", base_amount: 10000, owner_only: true },
        { code: "CLTA 101", name: "Mechanics' Liens (Lender Standard)", pricing_type: "percentage", percentage: 0.10, lender_only: true },
        { code: "CLTA 101.1", name: "Mechanics' Liens (Owner)", pricing_type: "percentage", percentage: 0.25, owner_only: true },
        { code: "CLTA 102.4", name: "Foundation (Lender)", pricing_type: "percentage", percentage: 0.10, max: 50000, lender_only: true },
        { code: "CLTA 102.5", name: "Foundation (Lender ALTA)", pricing_type: "percentage", percentage: 0.15, min: 10000, max: 100000, lender_only: true },
        { code: "CLTA 150", name: "Solar", pricing_type: "flat", base_amount: 7500, lender_only: true }
      ].freeze

      # CA CPL: No tiered rates (CPLs are not used in California per ORT manual)
      CPL_RATES = [].freeze
    end
  end
end
