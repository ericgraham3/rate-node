# frozen_string_literal: true

require "date"
require "csv"

module RateNode
  module Seeds
    # Texas - DEFAULT (Promulgated Rates) - Effective July 1, 2025
    # All underwriters in TX use identical state-regulated rates (underwriter_code: "DEFAULT")
    module TX_DEFAULT
      TX_EFFECTIVE_DATE = Date.new(2025, 7, 1)

      # Parse endorsements from CSV
      def self.load_endorsements
        csv_path = File.expand_path("../../../tx_endorsements.csv", __FILE__)
        return [] unless File.exist?(csv_path)

        endorsements = []
        CSV.foreach(csv_path, headers: true, encoding: "bom|utf-8") do |row|
          form_code = row["Form"]&.strip
          name = row["Endorsements"]&.strip
          premium_text = row["Premium"]&.strip
          policy_type = row["Policy Type"]&.strip
          code = row["Code"]&.strip

          # Skip rows without a code (the unique identifier)
          next if code.nil? || code.empty?
          next if name.nil? || name.empty?

          # Parse pricing from premium_text
          pricing = parse_pricing(premium_text)

          # Determine owner_only / lender_only
          owner_only = policy_type == "OTP"
          lender_only = policy_type == "MTP"

          endorsements << {
            code: code,
            form_code: form_code,
            name: name,
            pricing_type: pricing[:type],
            base_amount: pricing[:base_amount],
            percentage: pricing[:percentage],
            min: pricing[:min],
            owner_only: owner_only,
            lender_only: lender_only
          }
        end

        endorsements
      end

      def self.parse_pricing(text)
        return { type: "no_charge", base_amount: nil, percentage: nil, min: nil } if text.nil? || text.empty?

        text_lower = text.downcase

        # No charge
        if text_lower.include?("no charge")
          return { type: "no_charge", base_amount: nil, percentage: nil, min: nil }
        end

        # Percentage of basic rate
        if text_lower.match?(/(\d+)%\s+of\s+(the\s+)?basic\s+(premium\s+)?rate/i)
          match = text.match(/(\d+(?:\.\d+)?)%/i)
          percentage = match[1].to_f / 100.0 if match

          # Check for minimum
          min_match = text.match(/min(?:imum)?[.\s]*\$(\d+)/i)
          min_cents = min_match ? min_match[1].to_i * 100 : nil

          return { type: "percentage_basic", base_amount: nil, percentage: percentage, min: min_cents }
        end

        # Flat dollar amount (simple)
        if text.match?(/^\$\s*(\d+)\s*$/i)
          match = text.match(/^\$\s*(\d+)\s*$/i)
          amount_cents = match[1].to_i * 100
          return { type: "flat", base_amount: amount_cents, percentage: nil, min: nil }
        end

        # Complex pricing - try to extract first dollar amount as flat fee
        dollar_match = text.match(/\$\s*(\d+)/i)
        if dollar_match
          amount_cents = dollar_match[1].to_i * 100
          return { type: "flat", base_amount: amount_cents, percentage: nil, min: nil }
        end

        # Default to no_charge if we can't parse
        { type: "no_charge", base_amount: nil, percentage: nil, min: nil }
      end

      # Endorsements will be loaded dynamically from CSV
      ENDORSEMENTS = load_endorsements.freeze
    end
  end
end
