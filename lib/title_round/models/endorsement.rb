# frozen_string_literal: true

require "date"

module TitleRound
  module Models
    class Endorsement
      PRICING_TYPES = %w[flat percentage percentage_basic tiered no_charge].freeze

      attr_reader :id, :code, :form_code, :name, :pricing_type, :base_amount_cents,
                  :percentage, :min_cents, :max_cents, :concurrent_discount_pct,
                  :owner_only, :lender_only, :notes,
                  :state_code, :underwriter_code, :effective_date, :expires_date

      def initialize(attrs)
        @id = attrs["id"]
        @code = attrs["code"]
        @form_code = attrs["form_code"]
        @name = attrs["name"]
        @pricing_type = attrs["pricing_type"]
        @base_amount_cents = attrs["base_amount_cents"]
        @percentage = attrs["percentage"]
        @min_cents = attrs["min_cents"]
        @max_cents = attrs["max_cents"]
        @concurrent_discount_pct = attrs["concurrent_discount_pct"]
        @owner_only = attrs["owner_only"] == 1
        @lender_only = attrs["lender_only"] == 1
        @notes = attrs["notes"]
        @state_code = attrs["state_code"]
        @underwriter_code = attrs["underwriter_code"]
        @effective_date = attrs["effective_date"]
        @expires_date = attrs["expires_date"]
      end

      def self.find_by_code(code, state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        row = Database.instance.get_first_row(
          "SELECT * FROM endorsements WHERE code = ? AND state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?)",
          [code.to_s.strip, state, underwriter, as_of_date_str, as_of_date_str]
        )
        row ? new(row) : nil
      end

      def self.find_by_form_code(form_code, state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        rows = Database.instance.execute(
          "SELECT * FROM endorsements WHERE form_code = ? AND state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY code",
          [form_code.to_s.upcase.strip, state, underwriter, as_of_date_str, as_of_date_str]
        )
        rows.map { |row| new(row) }
      end

      def self.all(state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        rows = Database.instance.execute(
          "SELECT * FROM endorsements WHERE state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY code",
          [state, underwriter, as_of_date_str, as_of_date_str]
        )
        rows.map { |row| new(row) }
      end

      def self.for_owner(state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        rows = Database.instance.execute(
          "SELECT * FROM endorsements WHERE lender_only = 0 AND state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY code",
          [state, underwriter, as_of_date_str, as_of_date_str]
        )
        rows.map { |row| new(row) }
      end

      def self.for_lender(state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        rows = Database.instance.execute(
          "SELECT * FROM endorsements WHERE owner_only = 0 AND state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?) ORDER BY code",
          [state, underwriter, as_of_date_str, as_of_date_str]
        )
        rows.map { |row| new(row) }
      end

      def calculate_premium(liability_cents, concurrent: false, state: nil, underwriter: nil, as_of_date: Date.today)
        base = case pricing_type
               when "flat"
                 base_amount_cents || 0
               when "percentage"
                 calculate_percentage_premium(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
               when "percentage_basic"
                 calculate_percentage_basic_premium(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date)
               when "tiered"
                 base_amount_cents || 0
               when "no_charge"
                 0
               else
                 0
               end

        apply_concurrent_discount(base, concurrent)
      end

      def self.seed(data, state_code:, underwriter_code:, effective_date:, expires_date: nil)
        db = Database.instance
        effective_date_str = effective_date.is_a?(Date) ? effective_date.to_s : effective_date
        expires_date_str = expires_date.is_a?(Date) ? expires_date.to_s : expires_date
        data.each do |row|
          db.execute(
            "INSERT OR IGNORE INTO endorsements (code, form_code, name, pricing_type, base_amount_cents, percentage, min_cents, max_cents, concurrent_discount_pct, owner_only, lender_only, notes, state_code, underwriter_code, effective_date, expires_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [row[:code], row[:form_code], row[:name], row[:pricing_type], row[:base_amount], row[:percentage], row[:min], row[:max], row[:concurrent_discount], row[:owner_only] ? 1 : 0, row[:lender_only] ? 1 : 0, row[:notes], state_code, underwriter_code, effective_date_str, expires_date_str]
          )
        end
      end

      private

      def calculate_percentage_premium(liability_cents, state:, underwriter:, as_of_date: Date.today)
        return 0 unless percentage

        base_rate = RateTier.calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_type: "premium")
        premium = (base_rate * percentage).ceil
        premium = [premium, min_cents].max if min_cents
        premium = [premium, max_cents].min if max_cents
        premium
      end

      def calculate_percentage_basic_premium(liability_cents, state:, underwriter:, as_of_date: Date.today)
        return 0 unless percentage

        # Use basic rate for TX endorsements
        basic_rate = RateTier.calculate_rate(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date, rate_type: "basic")
        premium = (basic_rate * percentage).ceil
        premium = [premium, min_cents].max if min_cents
        premium = [premium, max_cents].min if max_cents
        premium
      end

      def apply_concurrent_discount(amount, concurrent)
        return amount unless concurrent && concurrent_discount_pct

        discount = (amount * concurrent_discount_pct / 100.0).round
        amount - discount
      end
    end
  end
end
