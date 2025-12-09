# frozen_string_literal: true

require "date"

module TitleRound
  module Seeds
    class Rates
      CA_TRG_EFFECTIVE_DATE = Date.new(2024, 1, 1)
      NC_INVESTORS_EFFECTIVE_DATE = Date.new(2024, 1, 1)

      def self.seed_all
        seed_ca_trg
        seed_nc_investors
      end

      def self.seed_ca_trg
        seed_ca_trg_rate_tiers
        seed_ca_trg_refinance_rates
        seed_ca_trg_policy_types
        seed_ca_trg_endorsements
      end

      def self.seed_nc_investors
        seed_nc_investors_rate_tiers
        seed_nc_investors_refinance_rates
        seed_nc_investors_policy_types
        seed_nc_investors_endorsements
      end

      def self.seed_ca_trg_rate_tiers
        schedule_data = SCHEDULE_OF_RATES.map do |row|
          {
            min: row[:min] * 100,
            max: row[:max] ? row[:max] * 100 : nil,
            base: row[:rate] * 100,
            per_thousand: nil,
            elc: row[:elc] * 100
          }
        end

        Models::RateTier.seed(schedule_data, state_code: "CA", underwriter_code: "TRG", effective_date: CA_TRG_EFFECTIVE_DATE, expires_date: nil)
      end

      def self.seed_ca_trg_refinance_rates
        data = REFINANCE_RATES.map do |row|
          {
            min: row[:min] * 100,
            max: row[:max] ? row[:max] * 100 : nil,
            rate: row[:rate] * 100
          }
        end

        Models::RefinanceRate.seed(data, state_code: "CA", underwriter_code: "TRG", effective_date: CA_TRG_EFFECTIVE_DATE, expires_date: nil)
      end

      def self.seed_ca_trg_policy_types
        Models::PolicyType.seed(state_code: "CA", underwriter_code: "TRG", effective_date: CA_TRG_EFFECTIVE_DATE, expires_date: nil)
      end

      def self.seed_ca_trg_endorsements
        Models::Endorsement.seed(ENDORSEMENTS, state_code: "CA", underwriter_code: "TRG", effective_date: CA_TRG_EFFECTIVE_DATE, expires_date: nil)
      end

      def self.seed_nc_investors_rate_tiers
        schedule_data = NC_INVESTORS_RATE_TIERS.map do |row|
          {
            min: row[:min] * 100,
            max: row[:max] ? row[:max] * 100 : nil,
            base: row[:rate] * 100,
            per_thousand: nil,
            elc: row[:elc] * 100
          }
        end

        Models::RateTier.seed(schedule_data, state_code: "NC", underwriter_code: "INVESTORS", effective_date: NC_INVESTORS_EFFECTIVE_DATE, expires_date: nil)
      end

      def self.seed_nc_investors_refinance_rates
        data = NC_INVESTORS_REFINANCE_RATES.map do |row|
          {
            min: row[:min] * 100,
            max: row[:max] ? row[:max] * 100 : nil,
            rate: row[:rate] * 100
          }
        end

        Models::RefinanceRate.seed(data, state_code: "NC", underwriter_code: "INVESTORS", effective_date: NC_INVESTORS_EFFECTIVE_DATE, expires_date: nil)
      end

      def self.seed_nc_investors_policy_types
        Models::PolicyType.seed(state_code: "NC", underwriter_code: "INVESTORS", effective_date: NC_INVESTORS_EFFECTIVE_DATE, expires_date: nil)
      end

      def self.seed_nc_investors_endorsements
        Models::Endorsement.seed(NC_INVESTORS_ENDORSEMENTS, state_code: "NC", underwriter_code: "INVESTORS", effective_date: NC_INVESTORS_EFFECTIVE_DATE, expires_date: nil)
      end

      SCHEDULE_OF_RATES = [
        { min: 0, max: 20_000, rate: 609, elc: 463 },
        { min: 20_001, max: 30_000, rate: 609, elc: 463 },
        { min: 30_001, max: 40_000, rate: 609, elc: 463 },
        { min: 40_001, max: 50_000, rate: 609, elc: 463 },
        { min: 50_001, max: 60_000, rate: 609, elc: 463 },
        { min: 60_001, max: 70_000, rate: 609, elc: 463 },
        { min: 70_001, max: 80_000, rate: 648, elc: 475 },
        { min: 80_001, max: 90_000, rate: 685, elc: 486 },
        { min: 90_001, max: 100_000, rate: 729, elc: 498 },
        { min: 100_001, max: 110_000, rate: 753, elc: 508 },
        { min: 110_001, max: 120_000, rate: 777, elc: 519 },
        { min: 120_001, max: 130_000, rate: 802, elc: 529 },
        { min: 130_001, max: 140_000, rate: 826, elc: 540 },
        { min: 140_001, max: 150_000, rate: 851, elc: 550 },
        { min: 150_001, max: 160_000, rate: 875, elc: 561 },
        { min: 160_001, max: 170_000, rate: 899, elc: 571 },
        { min: 170_001, max: 180_000, rate: 924, elc: 581 },
        { min: 180_001, max: 190_000, rate: 947, elc: 592 },
        { min: 190_001, max: 200_000, rate: 982, elc: 603 },
        { min: 200_001, max: 210_000, rate: 998, elc: 613 },
        { min: 210_001, max: 220_000, rate: 1_022, elc: 624 },
        { min: 220_001, max: 230_000, rate: 1_045, elc: 634 },
        { min: 230_001, max: 240_000, rate: 1_069, elc: 645 },
        { min: 240_001, max: 250_000, rate: 1_092, elc: 657 },
        { min: 250_001, max: 260_000, rate: 1_115, elc: 669 },
        { min: 260_001, max: 270_000, rate: 1_139, elc: 680 },
        { min: 270_001, max: 280_000, rate: 1_162, elc: 693 },
        { min: 280_001, max: 290_000, rate: 1_187, elc: 705 },
        { min: 290_001, max: 300_000, rate: 1_210, elc: 716 },
        { min: 300_001, max: 310_000, rate: 1_211, elc: 730 },
        { min: 310_001, max: 320_000, rate: 1_229, elc: 744 },
        { min: 320_001, max: 330_000, rate: 1_246, elc: 758 },
        { min: 330_001, max: 340_000, rate: 1_264, elc: 773 },
        { min: 340_001, max: 350_000, rate: 1_282, elc: 786 },
        { min: 350_001, max: 360_000, rate: 1_300, elc: 800 },
        { min: 360_001, max: 370_000, rate: 1_318, elc: 815 },
        { min: 370_001, max: 380_000, rate: 1_337, elc: 828 },
        { min: 380_001, max: 390_000, rate: 1_355, elc: 842 },
        { min: 390_001, max: 400_000, rate: 1_372, elc: 856 },
        { min: 400_001, max: 410_000, rate: 1_411, elc: 870 },
        { min: 410_001, max: 420_000, rate: 1_428, elc: 885 },
        { min: 420_001, max: 430_000, rate: 1_446, elc: 899 },
        { min: 430_001, max: 440_000, rate: 1_464, elc: 912 },
        { min: 440_001, max: 450_000, rate: 1_482, elc: 927 },
        { min: 450_001, max: 460_000, rate: 1_499, elc: 941 },
        { min: 460_001, max: 470_000, rate: 1_517, elc: 954 },
        { min: 470_001, max: 480_000, rate: 1_535, elc: 969 },
        { min: 480_001, max: 490_000, rate: 1_553, elc: 983 },
        { min: 490_001, max: 500_000, rate: 1_571, elc: 996 },
        { min: 500_001, max: 510_000, rate: 1_582, elc: 1_007 },
        { min: 510_001, max: 520_000, rate: 1_599, elc: 1_017 },
        { min: 520_001, max: 530_000, rate: 1_616, elc: 1_028 },
        { min: 530_001, max: 540_000, rate: 1_633, elc: 1_038 },
        { min: 540_001, max: 550_000, rate: 1_650, elc: 1_049 },
        { min: 550_001, max: 560_000, rate: 1_666, elc: 1_059 },
        { min: 560_001, max: 570_000, rate: 1_682, elc: 1_070 },
        { min: 570_001, max: 580_000, rate: 1_699, elc: 1_080 },
        { min: 580_001, max: 590_000, rate: 1_716, elc: 1_091 },
        { min: 590_001, max: 600_000, rate: 1_733, elc: 1_101 },
        { min: 600_001, max: 610_000, rate: 1_745, elc: 1_112 },
        { min: 610_001, max: 620_000, rate: 1_761, elc: 1_122 },
        { min: 620_001, max: 630_000, rate: 1_778, elc: 1_133 },
        { min: 630_001, max: 640_000, rate: 1_794, elc: 1_143 },
        { min: 640_001, max: 650_000, rate: 1_811, elc: 1_154 },
        { min: 650_001, max: 660_000, rate: 1_828, elc: 1_164 },
        { min: 660_001, max: 670_000, rate: 1_845, elc: 1_175 },
        { min: 670_001, max: 680_000, rate: 1_861, elc: 1_185 },
        { min: 680_001, max: 690_000, rate: 1_877, elc: 1_196 },
        { min: 690_001, max: 700_000, rate: 1_894, elc: 1_206 },
        { min: 700_001, max: 710_000, rate: 1_907, elc: 1_217 },
        { min: 710_001, max: 720_000, rate: 1_924, elc: 1_227 },
        { min: 720_001, max: 730_000, rate: 1_939, elc: 1_238 },
        { min: 730_001, max: 740_000, rate: 1_956, elc: 1_248 },
        { min: 740_001, max: 750_000, rate: 1_973, elc: 1_259 },
        { min: 750_001, max: 760_000, rate: 1_990, elc: 1_269 },
        { min: 760_001, max: 770_000, rate: 2_007, elc: 1_280 },
        { min: 770_001, max: 780_000, rate: 2_023, elc: 1_290 },
        { min: 780_001, max: 790_000, rate: 2_039, elc: 1_301 },
        { min: 790_001, max: 800_000, rate: 2_056, elc: 1_311 },
        { min: 800_001, max: 810_000, rate: 2_083, elc: 1_322 },
        { min: 810_001, max: 820_000, rate: 2_100, elc: 1_332 },
        { min: 820_001, max: 830_000, rate: 2_116, elc: 1_343 },
        { min: 830_001, max: 840_000, rate: 2_134, elc: 1_353 },
        { min: 840_001, max: 850_000, rate: 2_149, elc: 1_364 },
        { min: 850_001, max: 860_000, rate: 2_165, elc: 1_371 },
        { min: 860_001, max: 870_000, rate: 2_181, elc: 1_379 },
        { min: 870_001, max: 880_000, rate: 2_197, elc: 1_386 },
        { min: 880_001, max: 890_000, rate: 2_213, elc: 1_393 },
        { min: 890_001, max: 900_000, rate: 2_229, elc: 1_401 },
        { min: 900_001, max: 910_000, rate: 2_249, elc: 1_408 },
        { min: 910_001, max: 920_000, rate: 2_265, elc: 1_415 },
        { min: 920_001, max: 930_000, rate: 2_281, elc: 1_423 },
        { min: 930_001, max: 940_000, rate: 2_296, elc: 1_430 },
        { min: 940_001, max: 950_000, rate: 2_313, elc: 1_437 },
        { min: 950_001, max: 960_000, rate: 2_329, elc: 1_448 },
        { min: 960_001, max: 970_000, rate: 2_345, elc: 1_452 },
        { min: 970_001, max: 980_000, rate: 2_360, elc: 1_460 },
        { min: 980_001, max: 990_000, rate: 2_376, elc: 1_467 },
        { min: 990_001, max: 1_000_000, rate: 2_393, elc: 1_474 },
        { min: 1_000_001, max: 1_010_000, rate: 2_406, elc: 1_479 },
        { min: 1_010_001, max: 1_500_000, rate: 3_023, elc: 1_737 },
        { min: 1_500_001, max: 2_000_000, rate: 3_581, elc: 1_947 },
        { min: 2_000_001, max: 2_500_000, rate: 3_896, elc: 2_209 },
        { min: 2_500_001, max: 3_000_000, rate: 4_211, elc: 2_472 },
        { min: 3_000_001, max: nil, rate: 4_211, elc: 2_472 }
      ].freeze

      REFINANCE_RATES = [
        { min: 0, max: 50_000, rate: 375 },
        { min: 50_001, max: 150_000, rate: 450 },
        { min: 150_001, max: 250_000, rate: 550 },
        { min: 250_001, max: 350_000, rate: 700 },
        { min: 350_001, max: 450_000, rate: 850 },
        { min: 450_001, max: 500_000, rate: 925 },
        { min: 500_001, max: 550_000, rate: 1_000 },
        { min: 550_001, max: 650_000, rate: 1_100 },
        { min: 650_001, max: 750_000, rate: 1_200 },
        { min: 750_001, max: 850_000, rate: 1_300 },
        { min: 850_001, max: 1_000_000, rate: 1_400 },
        { min: 1_000_001, max: 1_500_000, rate: 1_700 },
        { min: 1_500_001, max: 2_000_000, rate: 2_100 },
        { min: 2_000_001, max: 2_500_000, rate: 2_850 },
        { min: 2_500_001, max: 3_000_000, rate: 2_950 },
        { min: 3_000_001, max: 3_500_000, rate: 3_410 },
        { min: 3_500_001, max: 4_000_000, rate: 3_550 },
        { min: 4_000_001, max: 5_000_000, rate: 4_200 },
        { min: 5_000_001, max: 6_000_000, rate: 4_860 },
        { min: 6_000_001, max: 7_000_000, rate: 5_400 },
        { min: 7_000_001, max: 8_000_000, rate: 6_000 },
        { min: 8_000_001, max: 9_000_000, rate: 6_700 },
        { min: 9_000_001, max: 10_000_000, rate: 7_200 },
        { min: 10_000_001, max: nil, rate: 7_200 }
      ].freeze

      ENDORSEMENTS = [
        { code: "CLTA 100", name: "Restrictions, Encroachments & Minerals (Owner Standard)", pricing_type: "percentage", percentage: 0.30, owner_only: true },
        { code: "CLTA 100.1", name: "Restrictions, Encroachments & Minerals (Lender Standard)", pricing_type: "percentage", percentage: 0.25, lender_only: true },
        { code: "ALTA 9", name: "Restrictions, Encroachments, Minerals - Loan Policy", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 9.3", name: "Covenants, Conditions and Restrictions - Loan Policy", pricing_type: "no_charge", lender_only: true },
        { code: "CLTA 103.7", name: "Land Abuts Street", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 17", name: "Access and Entry", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 17.1", name: "Indirect Access and Entry", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 17.2", name: "Utility Access", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 4", name: "Condominium (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 4.1", name: "Condominium (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 5", name: "Planned Unit Development (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 5.1", name: "Planned Unit Development (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 6", name: "Variable Rate Mortgage", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 6.2", name: "Variable Rate Mortgage, Negative Amortization", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 8.1", name: "Environmental Protection Lien (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 8.2", name: "Environmental Protection Lien (Owner)", pricing_type: "flat", base_amount: 10000, owner_only: true },
        { code: "CLTA 115", name: "Condominium", pricing_type: "flat", base_amount: 2500 },
        { code: "CLTA 116", name: "Designation of Improvements, Address", pricing_type: "no_charge", notes: "No charge if concurrent, 10% if subsequent" },
        { code: "ALTA 22", name: "Location", pricing_type: "no_charge", notes: "No charge if concurrent, 10% if subsequent" },
        { code: "ALTA 22.1", name: "Location and Map", pricing_type: "no_charge", notes: "No charge if concurrent, 10% if subsequent" },
        { code: "CLTA 116.7", name: "Subdivision Map Act Compliance", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 26", name: "Subdivision", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 18", name: "Single Tax Parcel", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 18.1", name: "Multiple Tax Parcel", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 19", name: "Contiguity, Multiple Parcels", pricing_type: "flat", base_amount: 10000 },
        { code: "ALTA 19.1", name: "Contiguity, Single Parcel", pricing_type: "flat", base_amount: 10000 },
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
        { code: "ALTA 7", name: "Manufactured Housing Unit", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 7.1", name: "Manufactured Housing - Conversion (Loan)", pricing_type: "flat", base_amount: 2500, lender_only: true },
        { code: "ALTA 7.2", name: "Manufactured Housing - Conversion (Owner)", pricing_type: "flat", base_amount: 2500, owner_only: true },
        { code: "CLTA 150", name: "Solar", pricing_type: "flat", base_amount: 10000, lender_only: true }
      ].freeze

      # North Carolina Investors Title dummy data (~10% different from CA for testing)
      NC_INVESTORS_RATE_TIERS = [
        { min: 0, max: 20_000, rate: 670, elc: 509 },
        { min: 20_001, max: 30_000, rate: 670, elc: 509 },
        { min: 30_001, max: 40_000, rate: 670, elc: 509 },
        { min: 40_001, max: 50_000, rate: 670, elc: 509 },
        { min: 50_001, max: 60_000, rate: 670, elc: 509 },
        { min: 60_001, max: 70_000, rate: 670, elc: 509 },
        { min: 70_001, max: 80_000, rate: 713, elc: 523 },
        { min: 80_001, max: 90_000, rate: 754, elc: 535 },
        { min: 90_001, max: 100_000, rate: 802, elc: 548 },
        { min: 100_001, max: 110_000, rate: 828, elc: 559 },
        { min: 110_001, max: 120_000, rate: 855, elc: 571 },
        { min: 120_001, max: 130_000, rate: 882, elc: 582 },
        { min: 130_001, max: 140_000, rate: 909, elc: 594 },
        { min: 140_001, max: 150_000, rate: 936, elc: 605 },
        { min: 150_001, max: 160_000, rate: 963, elc: 617 },
        { min: 160_001, max: 170_000, rate: 989, elc: 628 },
        { min: 170_001, max: 180_000, rate: 1_016, elc: 639 },
        { min: 180_001, max: 190_000, rate: 1_042, elc: 651 },
        { min: 190_001, max: 200_000, rate: 1_080, elc: 663 },
        { min: 200_001, max: 210_000, rate: 1_098, elc: 674 },
        { min: 210_001, max: 220_000, rate: 1_124, elc: 686 },
        { min: 220_001, max: 230_000, rate: 1_150, elc: 697 },
        { min: 230_001, max: 240_000, rate: 1_176, elc: 710 },
        { min: 240_001, max: 250_000, rate: 1_201, elc: 723 },
        { min: 250_001, max: 260_000, rate: 1_227, elc: 736 },
        { min: 260_001, max: 270_000, rate: 1_253, elc: 748 },
        { min: 270_001, max: 280_000, rate: 1_278, elc: 762 },
        { min: 280_001, max: 290_000, rate: 1_306, elc: 776 },
        { min: 290_001, max: 300_000, rate: 1_331, elc: 788 },
        { min: 300_001, max: 310_000, rate: 1_332, elc: 803 },
        { min: 310_001, max: 320_000, rate: 1_352, elc: 818 },
        { min: 320_001, max: 330_000, rate: 1_371, elc: 834 },
        { min: 330_001, max: 340_000, rate: 1_390, elc: 850 },
        { min: 340_001, max: 350_000, rate: 1_410, elc: 865 },
        { min: 350_001, max: 360_000, rate: 1_430, elc: 880 },
        { min: 360_001, max: 370_000, rate: 1_450, elc: 897 },
        { min: 370_001, max: 380_000, rate: 1_471, elc: 911 },
        { min: 380_001, max: 390_000, rate: 1_491, elc: 926 },
        { min: 390_001, max: 400_000, rate: 1_509, elc: 942 },
        { min: 400_001, max: 410_000, rate: 1_552, elc: 957 },
        { min: 410_001, max: 420_000, rate: 1_571, elc: 974 },
        { min: 420_001, max: 430_000, rate: 1_591, elc: 989 },
        { min: 430_001, max: 440_000, rate: 1_610, elc: 1_003 },
        { min: 440_001, max: 450_000, rate: 1_630, elc: 1_020 },
        { min: 450_001, max: 460_000, rate: 1_649, elc: 1_035 },
        { min: 460_001, max: 470_000, rate: 1_669, elc: 1_049 },
        { min: 470_001, max: 480_000, rate: 1_689, elc: 1_066 },
        { min: 480_001, max: 490_000, rate: 1_708, elc: 1_081 },
        { min: 490_001, max: 500_000, rate: 1_728, elc: 1_096 },
        { min: 500_001, max: 510_000, rate: 1_740, elc: 1_108 },
        { min: 510_001, max: 520_000, rate: 1_759, elc: 1_119 },
        { min: 520_001, max: 530_000, rate: 1_778, elc: 1_131 },
        { min: 530_001, max: 540_000, rate: 1_796, elc: 1_142 },
        { min: 540_001, max: 550_000, rate: 1_815, elc: 1_154 },
        { min: 550_001, max: 560_000, rate: 1_833, elc: 1_165 },
        { min: 560_001, max: 570_000, rate: 1_850, elc: 1_177 },
        { min: 570_001, max: 580_000, rate: 1_869, elc: 1_188 },
        { min: 580_001, max: 590_000, rate: 1_888, elc: 1_200 },
        { min: 590_001, max: 600_000, rate: 1_906, elc: 1_211 },
        { min: 600_001, max: 610_000, rate: 1_920, elc: 1_223 },
        { min: 610_001, max: 620_000, rate: 1_937, elc: 1_234 },
        { min: 620_001, max: 630_000, rate: 1_956, elc: 1_246 },
        { min: 630_001, max: 640_000, rate: 1_973, elc: 1_257 },
        { min: 640_001, max: 650_000, rate: 1_992, elc: 1_269 },
        { min: 650_001, max: 660_000, rate: 2_011, elc: 1_280 },
        { min: 660_001, max: 670_000, rate: 2_030, elc: 1_293 },
        { min: 670_001, max: 680_000, rate: 2_047, elc: 1_304 },
        { min: 680_001, max: 690_000, rate: 2_065, elc: 1_316 },
        { min: 690_001, max: 700_000, rate: 2_083, elc: 1_327 },
        { min: 700_001, max: 710_000, rate: 2_098, elc: 1_339 },
        { min: 710_001, max: 720_000, rate: 2_116, elc: 1_350 },
        { min: 720_001, max: 730_000, rate: 2_133, elc: 1_362 },
        { min: 730_001, max: 740_000, rate: 2_152, elc: 1_373 },
        { min: 740_001, max: 750_000, rate: 2_170, elc: 1_385 },
        { min: 750_001, max: 760_000, rate: 2_189, elc: 1_396 },
        { min: 760_001, max: 770_000, rate: 2_208, elc: 1_408 },
        { min: 770_001, max: 780_000, rate: 2_225, elc: 1_419 },
        { min: 780_001, max: 790_000, rate: 2_243, elc: 1_431 },
        { min: 790_001, max: 800_000, rate: 2_262, elc: 1_442 },
        { min: 800_001, max: 810_000, rate: 2_291, elc: 1_454 },
        { min: 810_001, max: 820_000, rate: 2_310, elc: 1_465 },
        { min: 820_001, max: 830_000, rate: 2_328, elc: 1_477 },
        { min: 830_001, max: 840_000, rate: 2_347, elc: 1_488 },
        { min: 840_001, max: 850_000, rate: 2_364, elc: 1_500 },
        { min: 850_001, max: 860_000, rate: 2_382, elc: 1_508 },
        { min: 860_001, max: 870_000, rate: 2_399, elc: 1_517 },
        { min: 870_001, max: 880_000, rate: 2_417, elc: 1_525 },
        { min: 880_001, max: 890_000, rate: 2_434, elc: 1_532 },
        { min: 890_001, max: 900_000, rate: 2_452, elc: 1_541 },
        { min: 900_001, max: 910_000, rate: 2_474, elc: 1_549 },
        { min: 910_001, max: 920_000, rate: 2_492, elc: 1_557 },
        { min: 920_001, max: 930_000, rate: 2_509, elc: 1_565 },
        { min: 930_001, max: 940_000, rate: 2_526, elc: 1_573 },
        { min: 940_001, max: 950_000, rate: 2_544, elc: 1_581 },
        { min: 950_001, max: 960_000, rate: 2_562, elc: 1_593 },
        { min: 960_001, max: 970_000, rate: 2_580, elc: 1_597 },
        { min: 970_001, max: 980_000, rate: 2_596, elc: 1_606 },
        { min: 980_001, max: 990_000, rate: 2_614, elc: 1_614 },
        { min: 990_001, max: 1_000_000, rate: 2_632, elc: 1_621 },
        { min: 1_000_001, max: 1_010_000, rate: 2_647, elc: 1_627 },
        { min: 1_010_001, max: 1_500_000, rate: 3_325, elc: 1_911 },
        { min: 1_500_001, max: 2_000_000, rate: 3_939, elc: 2_142 },
        { min: 2_000_001, max: 2_500_000, rate: 4_286, elc: 2_430 },
        { min: 2_500_001, max: 3_000_000, rate: 4_632, elc: 2_719 },
        { min: 3_000_001, max: nil, rate: 4_632, elc: 2_719 }
      ].freeze

      NC_INVESTORS_REFINANCE_RATES = [
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

      NC_INVESTORS_ENDORSEMENTS = [
        { code: "CLTA 100", name: "Restrictions, Encroachments & Minerals (Owner Standard)", pricing_type: "percentage", percentage: 0.30, owner_only: true },
        { code: "CLTA 100.1", name: "Restrictions, Encroachments & Minerals (Lender Standard)", pricing_type: "percentage", percentage: 0.25, lender_only: true },
        { code: "ALTA 9", name: "Restrictions, Encroachments, Minerals - Loan Policy", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 9.3", name: "Covenants, Conditions and Restrictions - Loan Policy", pricing_type: "no_charge", lender_only: true },
        { code: "CLTA 103.7", name: "Land Abuts Street", pricing_type: "flat", base_amount: 2750 },
        { code: "ALTA 17", name: "Access and Entry", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 17.1", name: "Indirect Access and Entry", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 17.2", name: "Utility Access", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 4", name: "Condominium (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 4.1", name: "Condominium (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 5", name: "Planned Unit Development (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 5.1", name: "Planned Unit Development (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 6", name: "Variable Rate Mortgage", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 6.2", name: "Variable Rate Mortgage, Negative Amortization", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 8.1", name: "Environmental Protection Lien (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 8.2", name: "Environmental Protection Lien (Owner)", pricing_type: "flat", base_amount: 11000, owner_only: true },
        { code: "CLTA 115", name: "Condominium", pricing_type: "flat", base_amount: 2750 },
        { code: "CLTA 116", name: "Designation of Improvements, Address", pricing_type: "no_charge", notes: "No charge if concurrent, 10% if subsequent" },
        { code: "ALTA 22", name: "Location", pricing_type: "no_charge", notes: "No charge if concurrent, 10% if subsequent" },
        { code: "ALTA 22.1", name: "Location and Map", pricing_type: "no_charge", notes: "No charge if concurrent, 10% if subsequent" },
        { code: "CLTA 116.7", name: "Subdivision Map Act Compliance", pricing_type: "flat", base_amount: 2750 },
        { code: "ALTA 26", name: "Subdivision", pricing_type: "flat", base_amount: 2750 },
        { code: "ALTA 18", name: "Single Tax Parcel", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 18.1", name: "Multiple Tax Parcel", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 19", name: "Contiguity, Multiple Parcels", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 19.1", name: "Contiguity, Single Parcel", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 25", name: "Same as Survey", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 25.1", name: "Same as Portion of Survey", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 28", name: "Easement, Damage or Enforced Removal (Owner)", pricing_type: "percentage", percentage: 0.20, owner_only: true },
        { code: "ALTA 28 LENDER", name: "Easement, Damage or Enforced Removal (Lender)", pricing_type: "flat", base_amount: 2750, lender_only: true },
        { code: "CLTA 123.1", name: "Zoning - Unimproved Land", pricing_type: "percentage", percentage: 0.10, min: 11000 },
        { code: "ALTA 3", name: "Zoning - Unimproved Land", pricing_type: "percentage", percentage: 0.10, min: 11000 },
        { code: "ALTA 3.1", name: "Zoning - Improved Land", pricing_type: "percentage", percentage: 0.15, min: 11000 },
        { code: "CLTA 127", name: "Nonimputation - Full Equity Transfer", pricing_type: "flat", base_amount: 11000, owner_only: true },
        { code: "ALTA 15", name: "Nonimputation - Full Equity Transfer", pricing_type: "flat", base_amount: 11000, owner_only: true },
        { code: "ALTA 15.1", name: "Nonimputation - Additional Insured", pricing_type: "flat", base_amount: 11000, owner_only: true },
        { code: "ALTA 15.2", name: "Nonimputation - Partial Equity Transfer", pricing_type: "flat", base_amount: 11000, owner_only: true },
        { code: "CLTA 101", name: "Mechanics' Liens (Lender Standard)", pricing_type: "percentage", percentage: 0.10, lender_only: true },
        { code: "CLTA 101.1", name: "Mechanics' Liens (Owner)", pricing_type: "percentage", percentage: 0.25, owner_only: true },
        { code: "CLTA 102.4", name: "Foundation (Lender)", pricing_type: "percentage", percentage: 0.10, max: 55000, lender_only: true },
        { code: "CLTA 102.5", name: "Foundation (Lender ALTA)", pricing_type: "percentage", percentage: 0.15, min: 11000, max: 110000, lender_only: true },
        { code: "ALTA 7", name: "Manufactured Housing Unit", pricing_type: "flat", base_amount: 2750 },
        { code: "ALTA 7.1", name: "Manufactured Housing - Conversion (Loan)", pricing_type: "flat", base_amount: 2750, lender_only: true },
        { code: "ALTA 7.2", name: "Manufactured Housing - Conversion (Owner)", pricing_type: "flat", base_amount: 2750, owner_only: true },
        { code: "CLTA 150", name: "Solar", pricing_type: "flat", base_amount: 11000, lender_only: true }
      ].freeze
    end
  end
end
