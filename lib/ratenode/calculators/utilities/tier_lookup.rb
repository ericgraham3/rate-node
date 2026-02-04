# frozen_string_literal: true

module RateNode
  module Utilities
    # Pure functions for tiered rate table traversal.
    #
    # These utilities consolidate tier lookup logic that was previously in RateTier
    # and other rate calculation models.
    #
    # Constitution Principle III: Extraction permitted for "generic algorithms:
    # tier lookup traversal" as pre-approved utility.
    #
    module TierLookup
      # Calculate total premium by summing per-thousand rates across tiers.
      #
      # Used by states with tiered rate structures (FL, NC) where different
      # rate-per-thousand values apply to different liability ranges.
      #
      # @param amount_cents [Integer] Total liability amount in cents
      # @param tiers [Array<Hash>] Tier definitions, each with :min, :max, :rate_per_thousand
      # @return [Integer] Total premium in cents
      #
      # @example Calculate tiered rate
      #   tiers = [
      #     { min: 0, max: 10_000_000, rate_per_thousand: 575 },      # $0-$100k: $5.75/k
      #     { min: 10_000_000, max: 50_000_000, rate_per_thousand: 450 }  # $100k-$500k: $4.50/k
      #   ]
      #   TierLookup.calculate_tiered_rate(25_000_000, tiers)
      #   # => (100 * 575) + (150 * 450) = 57500 + 67500 = 125000 ($1,250)
      #
      def self.calculate_tiered_rate(amount_cents, tiers)
        return 0 if amount_cents <= 0 || tiers.nil? || tiers.empty?

        remaining = amount_cents
        total_cents = 0

        tiers.each do |tier|
          break if remaining <= 0

          tier_min = tier[:min] || 0
          tier_max = tier[:max] || Float::INFINITY
          rate = tier[:rate_per_thousand] || 0

          # Amount in this tier
          tier_amount = [remaining, tier_max - tier_min].min
          next if tier_amount <= 0

          # Calculate premium for this tier (amount in thousands * rate per thousand)
          thousands = tier_amount / 100  # Convert cents to "per thousand" units
          total_cents += thousands * rate

          remaining -= tier_amount
        end

        total_cents.to_i
      end

      # Find the single bracket that applies to a given amount.
      #
      # Used by states with bracket-based rates (CA) where a single rate
      # applies to the entire amount based on which bracket it falls into.
      #
      # @param amount_cents [Integer] Liability amount in cents
      # @param tiers [Array<Hash>] Tier definitions with :min, :max, and rate fields
      # @return [Hash, nil] The matching tier, or nil if no match
      #
      # @example Find bracket for $250,000
      #   tiers = [
      #     { min: 0, max: 10_000_000, base_rate: 50000 },
      #     { min: 10_000_000, max: 100_000_000, base_rate: 75000 }
      #   ]
      #   TierLookup.find_bracket(25_000_000, tiers)
      #   # => { min: 10_000_000, max: 100_000_000, base_rate: 75000 }
      #
      def self.find_bracket(amount_cents, tiers)
        return nil if tiers.nil? || tiers.empty?

        tiers.find do |tier|
          min = tier[:min] || 0
          max = tier[:max] || Float::INFINITY
          amount_cents >= min && amount_cents < max
        end
      end
    end
  end
end
