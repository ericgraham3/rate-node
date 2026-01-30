# frozen_string_literal: true

# Florida Title Insurance Rates - TRG (Effective January 1, 2025)
# FL uses tiered per-thousand rates with separate original and reissue rate tables
# Liability amounts are rounded to nearest $100 (10,000 cents)
# Minimum premium: $100 (10,000 cents)

module RateNode
  module Seeds
    module FL
      EFFECTIVE_DATE = Date.new(2025, 1, 1)
      STATE_CODE = "FL"
      UNDERWRITER_CODE = "TRG"

      # Original Rate Table - Tiered per-thousand structure (values in cents)
      # Per FL promulgated rates
      RATE_TIERS_ORIGINAL = [
        # $0 - $100,000: $5.75 per thousand
        { min: 0, max: 10_000_000, base: 0, per_thousand: 575 },
        # $100,001 - $1,000,000: $5.00 per thousand
        { min: 10_000_001, max: 100_000_000, base: 0, per_thousand: 500 },
        # $1,000,001 - $5,000,000: $2.50 per thousand
        { min: 100_000_001, max: 500_000_000, base: 0, per_thousand: 250 },
        # $5,000,001 - $10,000,000: $2.25 per thousand
        { min: 500_000_001, max: 1_000_000_000, base: 0, per_thousand: 225 },
        # Over $10,000,000: $2.00 per thousand
        { min: 1_000_000_001, max: nil, base: 0, per_thousand: 200 }
      ].freeze

      # Reissue Rate Table - Lower rates for prior policy holders (values in cents)
      # Per FL promulgated reissue rates (fl_rate_summary.md Section 2)
      RATE_TIERS_REISSUE = [
        # $0 - $100,000: $3.30 per thousand (reissue)
        { min: 0, max: 10_000_000, base: 0, per_thousand: 330 },
        # $100,001 - $1,000,000: $3.00 per thousand (reissue)
        { min: 10_000_001, max: 100_000_000, base: 0, per_thousand: 300 },
        # $1,000,001 - $10,000,000: $2.00 per thousand (reissue)
        { min: 100_000_001, max: 1_000_000_000, base: 0, per_thousand: 200 },
        # Over $10,000,000: $1.50 per thousand (reissue)
        { min: 1_000_000_001, max: nil, base: 0, per_thousand: 150 }
      ].freeze

      # Refinance rates - FL uses flat rates based on loan amount
      REFINANCE_RATES = [
        { min: 0, max: 100_000, rate: 175 },
        { min: 100_001, max: 250_000, rate: 250 },
        { min: 250_001, max: 500_000, rate: 400 },
        { min: 500_001, max: 1_000_000, rate: 550 },
        { min: 1_000_001, max: nil, rate: 750 }
      ].freeze

      # FL Endorsements
      # Note: FL has percentage_combined (based on combined owner's + lender's premium)
      # and property_tiered (different rates for residential vs commercial)
      ENDORSEMENTS = [
        # Standard endorsements - flat pricing
        { code: "ALTA 4", form_code: "ALTA 4", name: "Condominium", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 4.1", form_code: "ALTA 4.1", name: "Condominium (Planned)", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 5", form_code: "ALTA 5", name: "Planned Unit Development", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 5.1", form_code: "ALTA 5.1", name: "Planned Unit Development (Planned)", pricing_type: "flat", base_amount: 2500 },
        { code: "ALTA 6", form_code: "ALTA 6", name: "Variable Rate Mortgage", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 6.2", form_code: "ALTA 6.2", name: "Variable Rate Mortgage, Negative Amortization", pricing_type: "no_charge", lender_only: true },
        { code: "ALTA 7", form_code: "ALTA 7", name: "Manufactured Housing Unit", pricing_type: "flat", base_amount: 5000 },
        { code: "ALTA 8.1", form_code: "ALTA 8.1", name: "Environmental Protection Lien", pricing_type: "flat", base_amount: 2500 },

        # Percentage on combined premium (FL-specific)
        # ALTA 9: 10% of combined owner's + lender's premium
        { code: "ALTA 9", form_code: "ALTA 9", name: "Restrictions, Encroachments, Minerals", pricing_type: "percentage_combined", percentage: 0.10, min: 2500 },
        { code: "ALTA 9.3", form_code: "ALTA 9.3", name: "Covenants, Conditions and Restrictions - Loan Policy", pricing_type: "no_charge", lender_only: true },

        # Location endorsement: 10% of combined premium
        { code: "ALTA 22", form_code: "ALTA 22", name: "Location", pricing_type: "percentage_combined", percentage: 0.10, min: 5000 },
        { code: "ALTA 22.1", form_code: "ALTA 22.1", name: "Location and Map", pricing_type: "percentage_combined", percentage: 0.10, min: 5000 },

        # Access endorsements: 5% of combined premium
        { code: "ALTA 17", form_code: "ALTA 17", name: "Access and Entry", pricing_type: "percentage_combined", percentage: 0.05, min: 2500 },
        { code: "ALTA 17.1", form_code: "ALTA 17.1", name: "Indirect Access and Entry", pricing_type: "percentage_combined", percentage: 0.05, min: 2500 },

        # Property-tiered endorsements (different for residential vs commercial)
        # Zoning endorsement: $25 residential, $100 commercial
        { code: "ALTA 3", form_code: "ALTA 3", name: "Zoning - Unimproved Land", pricing_type: "property_tiered", residential_amount: 2500, commercial_amount: 10000 },
        { code: "ALTA 3.1", form_code: "ALTA 3.1", name: "Zoning - Improved Land", pricing_type: "property_tiered", residential_amount: 5000, commercial_amount: 15000 },

        # Contiguity endorsement: $50 residential, $150 commercial
        { code: "ALTA 19", form_code: "ALTA 19", name: "Contiguity, Multiple Parcels", pricing_type: "property_tiered", residential_amount: 5000, commercial_amount: 15000 },
        { code: "ALTA 19.1", form_code: "ALTA 19.1", name: "Contiguity, Single Parcel", pricing_type: "property_tiered", residential_amount: 5000, commercial_amount: 15000 },

        # Tax parcel endorsements
        { code: "ALTA 18", form_code: "ALTA 18", name: "Single Tax Parcel", pricing_type: "property_tiered", residential_amount: 2500, commercial_amount: 7500 },
        { code: "ALTA 18.1", form_code: "ALTA 18.1", name: "Multiple Tax Parcel", pricing_type: "property_tiered", residential_amount: 5000, commercial_amount: 10000 },

        # Survey same as endorsement
        { code: "ALTA 25", form_code: "ALTA 25", name: "Same as Survey", pricing_type: "property_tiered", residential_amount: 5000, commercial_amount: 10000 },
        { code: "ALTA 25.1", form_code: "ALTA 25.1", name: "Same as Portion of Survey", pricing_type: "property_tiered", residential_amount: 5000, commercial_amount: 10000 },

        # Subdivision endorsement
        { code: "ALTA 26", form_code: "ALTA 26", name: "Subdivision", pricing_type: "flat", base_amount: 2500 },

        # Additional FL endorsements
        { code: "ALTA 15", form_code: "ALTA 15", name: "Nonimputation - Full Equity Transfer", pricing_type: "flat", base_amount: 10000, owner_only: true },
        { code: "ALTA 15.1", form_code: "ALTA 15.1", name: "Nonimputation - Additional Insured", pricing_type: "flat", base_amount: 10000, owner_only: true }
      ].freeze

      # FL has no CPL per state_rules
      CPL_RATES = [].freeze
    end
  end
end
