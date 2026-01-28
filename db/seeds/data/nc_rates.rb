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

      ENDORSEMENTS = [
        { code: "CLTA 100", name: "Restrictions, Encroachments & Minerals (Owner Standard)", pricing_type: "percentage", percentage: 0.30, owner_only: true },
        { code: "CLTA 100.1", name: "Restrictions, Encroachments & Minerals (Lender Standard)", pricing_type: "percentage", percentage: 0.25, lender_only: true },
        { code: "ALTA 9", name: "Restrictions, Encroachments, Minerals", pricing_type: "flat", base_amount: 2300 },
        { code: "ALTA 9.3", name: "Covenants, Conditions and Restrictions - Loan Policy", pricing_type: "no_charge", lender_only: true },
        { code: "CLTA 103.7", name: "Land Abuts Street", pricing_type: "flat", base_amount: 2750 },
        { code: "ALTA 17", name: "Access and Entry", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 17.1", name: "Indirect Access and Entry", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 17.2", name: "Utility Access", pricing_type: "flat", base_amount: 11000 },
        { code: "ALTA 4", name: "Condominium (Lender)", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 4.1", name: "Condominium (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 5", name: "Planned Unit Development", pricing_type: "flat", base_amount: 2300 },
        { code: "ALTA 5.1", name: "Planned Unit Development (Owner/Lender)", pricing_type: "no_charge" },
        { code: "ALTA 6", name: "Variable Rate Mortgage", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 6.2", name: "Variable Rate Mortgage, Negative Amortization", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 8.1", name: "Environmental Lien Protection", pricing_type: "flat", base_amount: 2300 },
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

      # CPL (Closing Protection Letter) Rates - Tiered structure
      CPL_RATES = [
        { min: 0, max: 10_000_000, rate: 69 },            # Up to $100,000 at $0.69 per thousand
        { min: 10_000_001, max: 50_000_000, rate: 13 },   # $100,001 - $500,000 at $0.13 per thousand
        { min: 50_000_001, max: nil, rate: 0 }            # Above $500,000 at $0.00 per thousand
      ].freeze
    end
  end
end
