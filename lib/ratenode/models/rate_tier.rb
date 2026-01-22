# frozen_string_literal: true

require "date"

module RateNode
  module Models
    class RateTier
      OVER_3M_BASE_CENTS = 421_100
      OVER_3M_PER_10K_CENTS = 525
      THREE_MILLION_CENTS = 300_000_000

      attr_reader :id, :min_liability_cents, :max_liability_cents,
                  :base_rate_cents, :per_thousand_cents, :extended_lender_concurrent_cents,
                  :state_code, :underwriter_code, :effective_date, :expires_date, :rate_type

      def initialize(attrs)
        @id = attrs["id"]
        @min_liability_cents = attrs["min_liability_cents"]
        @max_liability_cents = attrs["max_liability_cents"]
        @base_rate_cents = attrs["base_rate_cents"]
        @per_thousand_cents = attrs["per_thousand_cents"]
        @extended_lender_concurrent_cents = attrs["extended_lender_concurrent_cents"]
        @state_code = attrs["state_code"]
        @underwriter_code = attrs["underwriter_code"]
        @effective_date = attrs["effective_date"]
        @expires_date = attrs["expires_date"]
        @rate_type = attrs["rate_type"] || "premium"
      end

      def self.find_by_liability(liability_cents, state:, underwriter:, as_of_date: Date.today, rate_type: "premium")
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        row = Database.instance.get_first_row(
          "SELECT * FROM rate_tiers WHERE min_liability_cents <= ? AND (max_liability_cents IS NULL OR max_liability_cents >= ?) AND state_code = ? AND underwriter_code = ? AND rate_type = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY min_liability_cents DESC LIMIT 1",
          [liability_cents, liability_cents, state, underwriter, rate_type, as_of_date_str, as_of_date_str]
        )
        row ? new(row) : nil
      end

      def self.all_tiers(state:, underwriter:, as_of_date: Date.today, rate_type: "premium")
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        rows = Database.instance.execute(
          "SELECT * FROM rate_tiers WHERE state_code = ? AND underwriter_code = ? AND rate_type = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY min_liability_cents ASC",
          [state, underwriter, rate_type, as_of_date_str, as_of_date_str]
        )
        rows.map { |row| new(row) }
      end

      # Find basic rate (for TX endorsement calculations)
      def self.find_basic_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
        calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_type: "basic")
      end

      # Find premium rate (what customer pays)
      def self.find_premium_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
        calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_type: "premium")
      end

      def self.calculate_rate(liability_cents, state:, underwriter:, as_of_date: Date.today, rate_type: "premium")
        # TX uses its own formula-based calculation for policies > $100,000
        # TX formulas cover all amounts up to $100M+ so don't use CA's $3M logic
        if state == "TX" && liability_cents > 10_000_000
          return calculate_tx_formula_rate(liability_cents)
        end

        # CA-specific: use $3M+ calculation for large policies
        return calculate_over_3m_rate(liability_cents) if liability_cents > THREE_MILLION_CENTS && state != "TX"

        # Get all tiers to check if we should use tiered calculation
        tiers = all_tiers(state: state, underwriter: underwriter, as_of_date: as_of_date, rate_type: rate_type)
        return 0 if tiers.empty?

        # Check if this uses tiered per-thousand calculation (NC style)
        if tiers.first.per_thousand_cents && tiers.first.per_thousand_cents > 0
          # Tiered calculation: sum across all applicable brackets
          calculate_tiered_rate(liability_cents, tiers)
        else
          # Single-tier calculation (CA/TX style)
          tier = find_by_liability(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_type: rate_type)
          return 0 unless tier
          tier.base_rate_cents
        end
      end

      def self.calculate_tiered_rate(liability_cents, tiers)
        total_cents = 0
        liability_dollars = liability_cents / 100.0

        tiers.each do |tier|
          tier_min_dollars = tier.min_liability_cents / 100.0
          tier_max_dollars = tier.max_liability_cents ? tier.max_liability_cents / 100.0 : Float::INFINITY

          # Skip tiers that start above our liability
          next if tier_min_dollars > liability_dollars

          # Calculate the portion of liability that falls within this tier
          applicable_min = [tier_min_dollars, 0].max
          applicable_max = [tier_max_dollars, liability_dollars].min

          if applicable_max > applicable_min
            tier_amount_dollars = applicable_max - applicable_min
            # Calculate: (amount in dollars / 1000) * rate per thousand
            tier_charge = (tier_amount_dollars / 1000.0 * tier.per_thousand_cents).round
            total_cents += tier_charge
          end
        end

        total_cents
      end

      def self.calculate_extended_lender_concurrent_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
        return calculate_elc_over_3m(liability_cents) if liability_cents > THREE_MILLION_CENTS

        tier = find_by_liability(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
        return 0 unless tier

        tier.extended_lender_concurrent_cents || 0
      end

      def self.calculate_over_3m_rate(liability_cents)
        excess = liability_cents - THREE_MILLION_CENTS
        increments = (excess / 1_000_000.0).ceil
        OVER_3M_BASE_CENTS + (increments * OVER_3M_PER_10K_CENTS)
      end

      def self.calculate_elc_over_3m(liability_cents)
        excess = liability_cents - THREE_MILLION_CENTS
        increments = (excess / 1_000_000.0).ceil
        75 + (increments * 75)
      end

      # TX formula-based calculation for policies > $100,000
      # Based on TX Title Insurance Basic Premium Rates (Effective September 1, 2019)
      # Commissioner's Order 2019-5980, Docket No. 2812
      # Per PDF instructions: Round at each step
      def self.calculate_tx_formula_rate(liability_cents)
        liability_dollars = liability_cents / 100.0

        # Determine which formula tier to use and calculate in dollars
        # Round the multiplication result, then add base
        # Formula: (liability - subtract) * multiplier + base
        result_dollars = case liability_dollars
        when 0..100_000
          # Should not reach here, handled by lookup table
          0
        when 100_001..1_000_000
          ((liability_dollars - 100_000) * 0.00527).round + 832
        when 1_000_001..5_000_000
          ((liability_dollars - 1_000_000) * 0.00433).round + 5_575
        when 5_000_001..15_000_000
          ((liability_dollars - 5_000_000) * 0.00357).round + 22_895
        when 15_000_001..25_000_000
          ((liability_dollars - 15_000_000) * 0.00254).round + 58_595
        when 25_000_001..50_000_000
          ((liability_dollars - 25_000_000) * 0.00152).round + 83_995
        when 50_000_001..100_000_000
          ((liability_dollars - 50_000_000) * 0.00138).round + 121_995
        else # > 100_000_000
          ((liability_dollars - 100_000_000) * 0.00124).round + 190_995
        end

        # Convert to cents
        result_dollars * 100
      end

      def self.seed(data, state_code:, underwriter_code:, effective_date:, expires_date: nil, rate_type: "premium")
        db = Database.instance
        effective_date_str = effective_date.is_a?(Date) ? effective_date.to_s : effective_date
        expires_date_str = expires_date.is_a?(Date) ? expires_date.to_s : expires_date
        data.each do |row|
          db.execute(
            "INSERT OR IGNORE INTO rate_tiers (min_liability_cents, max_liability_cents, base_rate_cents, per_thousand_cents, extended_lender_concurrent_cents, state_code, underwriter_code, effective_date, expires_date, rate_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [row[:min], row[:max], row[:base], row[:per_thousand], row[:elc], state_code, underwriter_code, effective_date_str, expires_date_str, rate_type]
          )
        end
      end
    end
  end
end
