# frozen_string_literal: true

require "date"

module RateNode
  module Models
    class CPLRate
      attr_reader :id, :state_code, :underwriter_code,
                  :min_liability_cents, :max_liability_cents,
                  :rate_per_thousand_cents, :effective_date, :expires_date

      def initialize(attrs)
        @id = attrs["id"]
        @state_code = attrs["state_code"]
        @underwriter_code = attrs["underwriter_code"]
        @min_liability_cents = attrs["min_liability_cents"]
        @max_liability_cents = attrs["max_liability_cents"]
        @rate_per_thousand_cents = attrs["rate_per_thousand_cents"]
        @effective_date = attrs["effective_date"]
        @expires_date = attrs["expires_date"]
      end

      def self.all_tiers(state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        rows = Database.instance.execute(
          "SELECT * FROM cpl_rates WHERE state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY min_liability_cents ASC",
          [state, underwriter, as_of_date_str, as_of_date_str]
        )
        rows.map { |row| new(row) }
      end

      def self.calculate_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
        tiers = all_tiers(state: state, underwriter: underwriter, as_of_date: as_of_date)
        return 0 if tiers.empty?

        total_cents = 0

        tiers.each do |tier|
          # Skip tiers that start above our liability
          break if tier.min_liability_cents > liability_cents

          # Calculate the portion of liability that falls within this tier
          tier_min = tier.min_liability_cents
          tier_max = tier.max_liability_cents || Float::INFINITY

          # Find the amount subject to this tier's rate
          applicable_min = [tier_min, 0].max
          applicable_max = [tier_max, liability_cents].min

          if applicable_max > applicable_min
            tier_amount = applicable_max - applicable_min
            # Convert to thousands and apply rate
            tier_charge = (tier_amount / 1000.0 * tier.rate_per_thousand_cents / 100.0).round
            total_cents += tier_charge
          end
        end

        total_cents
      end

      def self.seed(data, state_code:, underwriter_code:, effective_date:, expires_date: nil)
        db = Database.instance
        effective_date_str = effective_date.is_a?(Date) ? effective_date.to_s : effective_date
        expires_date_str = expires_date.is_a?(Date) ? expires_date.to_s : expires_date

        data.each do |row|
          db.execute(
            "INSERT OR IGNORE INTO cpl_rates (state_code, underwriter_code, min_liability_cents, max_liability_cents, rate_per_thousand_cents, effective_date, expires_date) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [state_code, underwriter_code, row[:min], row[:max], row[:rate], effective_date_str, expires_date_str]
          )
        end
      end
    end
  end
end
