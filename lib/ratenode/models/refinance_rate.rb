# frozen_string_literal: true

require "date"

module RateNode
  module Models
    class RefinanceRate
      OVER_5M_BASE_CENTS = 720_000
      OVER_5M_PER_100K_CENTS = 10_000
      FIVE_MILLION_CENTS = 500_000_000

      attr_reader :id, :min_liability_cents, :max_liability_cents, :flat_rate_cents,
                  :state_code, :underwriter_code, :effective_date, :expires_date

      def initialize(attrs)
        @id = attrs["id"]
        @min_liability_cents = attrs["min_liability_cents"]
        @max_liability_cents = attrs["max_liability_cents"]
        @flat_rate_cents = attrs["flat_rate_cents"]
        @state_code = attrs["state_code"]
        @underwriter_code = attrs["underwriter_code"]
        @effective_date = attrs["effective_date"]
        @expires_date = attrs["expires_date"]
      end

      def self.find_by_liability(liability_cents, state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        row = Database.instance.get_first_row(
          "SELECT * FROM refinance_rates WHERE min_liability_cents <= ? AND (max_liability_cents IS NULL OR max_liability_cents >= ?) AND state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY min_liability_cents DESC LIMIT 1",
          [liability_cents, liability_cents, state, underwriter, as_of_date_str, as_of_date_str]
        )
        row ? new(row) : nil
      end

      TEN_MILLION_CENTS = 1_000_000_000

      def self.calculate_rate(liability_cents, state:, underwriter:, as_of_date: Date.today)
        # CA-specific over-$10M refinance formula
        if state == "CA" && liability_cents > TEN_MILLION_CENTS
          return calculate_ca_over_10m_refinance(liability_cents, underwriter: underwriter)
        end

        return calculate_over_5m_rate(liability_cents) if liability_cents > FIVE_MILLION_CENTS

        rate = find_by_liability(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
        return 0 unless rate

        rate.flat_rate_cents
      end

      def self.calculate_over_5m_rate(liability_cents)
        excess = liability_cents - FIVE_MILLION_CENTS
        increments = (excess / 10_000_000.0).ceil
        OVER_5M_BASE_CENTS + (increments * OVER_5M_PER_100K_CENTS)
      end

      def self.calculate_ca_over_10m_refinance(liability_cents, underwriter:)
        rules = RateNode.rules_for("CA", underwriter: underwriter)
        base = rules[:refinance_over_10m_base_cents]
        rate_per_million = rules[:refinance_over_10m_per_million_cents]

        excess_cents = liability_cents - TEN_MILLION_CENTS
        millions_over_10m = (excess_cents / 100_000_000.0).ceil
        base + (millions_over_10m * rate_per_million)
      end

      def self.seed(data, state_code:, underwriter_code:, effective_date:, expires_date: nil)
        db = Database.instance
        effective_date_str = effective_date.is_a?(Date) ? effective_date.to_s : effective_date
        expires_date_str = expires_date.is_a?(Date) ? expires_date.to_s : expires_date
        data.each do |row|
          db.execute(
            "INSERT OR IGNORE INTO refinance_rates (min_liability_cents, max_liability_cents, flat_rate_cents, state_code, underwriter_code, effective_date, expires_date) VALUES (?, ?, ?, ?, ?, ?, ?)",
            [row[:min], row[:max], row[:rate], state_code, underwriter_code, effective_date_str, expires_date_str]
          )
        end
      end
    end
  end
end
