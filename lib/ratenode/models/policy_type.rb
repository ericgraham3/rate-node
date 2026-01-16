# frozen_string_literal: true

require "date"

module RateNode
  module Models
    class PolicyType
      # Default types (used for CA/TRG)
      TYPES = {
        standard: { name: "standard", multiplier: 1.00 },
        homeowner: { name: "homeowner", multiplier: 1.10 },
        extended: { name: "extended", multiplier: 1.25 }
      }.freeze

      # NC-specific multipliers
      NC_TYPES = {
        standard: { name: "standard", multiplier: 1.00 },
        homeowner: { name: "homeowner", multiplier: 1.20 },
        extended: { name: "extended", multiplier: 1.20 }
      }.freeze

      attr_reader :id, :name, :multiplier, :state_code, :underwriter_code, :effective_date, :expires_date

      def initialize(attrs)
        @id = attrs["id"]
        @name = attrs["name"]
        @multiplier = attrs["multiplier"].to_f
        @state_code = attrs["state_code"]
        @underwriter_code = attrs["underwriter_code"]
        @effective_date = attrs["effective_date"]
        @expires_date = attrs["expires_date"]
      end

      def self.find_by_name(name, state:, underwriter:, as_of_date: Date.today)
        as_of_date_str = as_of_date.is_a?(Date) ? as_of_date.to_s : as_of_date
        row = Database.instance.get_first_row(
          "SELECT * FROM policy_types WHERE name = ? AND state_code = ? AND underwriter_code = ? AND effective_date <= ? AND (expires_date IS NULL OR expires_date > ?)",
          [name.to_s.downcase, state, underwriter, as_of_date_str, as_of_date_str]
        )
        row ? new(row) : nil
      end

      def self.multiplier_for(type, state:, underwriter:, as_of_date: Date.today)
        policy = find_by_name(type, state: state, underwriter: underwriter, as_of_date: as_of_date)
        policy&.multiplier || TYPES.dig(type.to_sym, :multiplier) || 1.0
      end

      def self.seed(state_code:, underwriter_code:, effective_date:, expires_date: nil, types: nil)
        db = Database.instance
        effective_date_str = effective_date.is_a?(Date) ? effective_date.to_s : effective_date
        expires_date_str = expires_date.is_a?(Date) ? expires_date.to_s : expires_date

        # Use state-specific types if provided, otherwise use state default
        types_to_seed = types || state_specific_types(state_code)

        types_to_seed.each_value do |type|
          db.execute(
            "INSERT OR IGNORE INTO policy_types (name, multiplier, state_code, underwriter_code, effective_date, expires_date) VALUES (?, ?, ?, ?, ?, ?)",
            [type[:name], type[:multiplier], state_code, underwriter_code, effective_date_str, expires_date_str]
          )
        end
      end

      def self.state_specific_types(state_code)
        case state_code
        when "NC"
          NC_TYPES
        else
          TYPES
        end
      end
    end
  end
end
