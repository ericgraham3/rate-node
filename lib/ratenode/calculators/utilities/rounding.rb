# frozen_string_literal: true

module RateNode
  module Utilities
    # Pure functions for premium amount rounding.
    #
    # These utilities consolidate rounding logic that was previously duplicated
    # across state calculators, BaseRate, and other calculators.
    #
    # Constitution Principle III: Extraction permitted for "mathematical operations:
    # rounding functions" as pre-approved utility.
    #
    module Rounding
      # Round amount up to the next increment boundary.
      #
      # @param amount_cents [Integer] Amount to round in cents
      # @param increment_cents [Integer] Rounding increment in cents (e.g., 500_000 for $5k)
      # @return [Integer] Rounded amount in cents
      #
      # @example Round $487,500 up to next $5,000 increment
      #   Rounding.round_up(48_750_000, 500_000)  # => 49_000_000 ($490,000)
      #
      # @example No rounding when increment is nil or zero
      #   Rounding.round_up(48_750_000, nil)  # => 48_750_000 (unchanged)
      #
      def self.round_up(amount_cents, increment_cents)
        return amount_cents if increment_cents.nil? || increment_cents.zero?
        return amount_cents if amount_cents <= 0
        return amount_cents if (amount_cents % increment_cents).zero?

        ((amount_cents / increment_cents) + 1) * increment_cents
      end

      # Round amount to the nearest increment boundary.
      #
      # @param amount_cents [Integer] Amount to round in cents
      # @param increment_cents [Integer] Rounding increment in cents
      # @return [Integer] Rounded amount in cents
      #
      # @example Round $487,500 to nearest $10,000
      #   Rounding.round_to_nearest(48_750_000, 1_000_000)  # => 49_000_000 ($490,000)
      #
      def self.round_to_nearest(amount_cents, increment_cents)
        return amount_cents if increment_cents.nil? || increment_cents.zero?
        return amount_cents if amount_cents <= 0

        ((amount_cents + (increment_cents / 2)) / increment_cents) * increment_cents
      end

      # Round down to the increment boundary (floor).
      #
      # @param amount_cents [Integer] Amount to round in cents
      # @param increment_cents [Integer] Rounding increment in cents
      # @return [Integer] Rounded amount in cents
      #
      def self.round_down(amount_cents, increment_cents)
        return amount_cents if increment_cents.nil? || increment_cents.zero?
        return amount_cents if amount_cents <= 0

        (amount_cents / increment_cents) * increment_cents
      end
    end
  end
end
