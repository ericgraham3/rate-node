# frozen_string_literal: true

require "csv"
require "date"

# This script parses TX rates and endorsements to create seed data

module TitleRound
  module Seeds
    class ParseTXData
      # Parse TX endorsements CSV
      def self.parse_endorsements(csv_path)
        endorsements = []

        CSV.foreach(csv_path, headers: true, encoding: "bom|utf-8") do |row|
          form_code = row["Form"]&.strip
          name = row["Endorsements"]&.strip
          premium_text = row["Premium"]&.strip
          policy_type = row["Policy Type"]&.strip

          next if form_code.nil? || form_code.empty? || name.nil? || name.empty?

          # Parse pricing from premium_text
          pricing = parse_pricing(premium_text)

          # Determine owner_only / lender_only
          owner_only = policy_type == "OTP"
          lender_only = policy_type == "MTP"

          endorsements << {
            code: form_code,
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

      # Generate TX rate tiers from the PDF data
      def self.generate_tx_rate_tiers
        tiers = []

        # Detailed tiers for $25,000 to $100,000 (from page 1 of PDF)
        # We'll create tiers in $500 increments
        detailed_rates = {
          25_000 => 295, 25_500 => 298, 26_000 => 302, 26_500 => 304, 27_000 => 306,
          27_500 => 309, 28_000 => 312, 28_500 => 315, 29_000 => 320, 29_500 => 322,
          30_000 => 325, 30_500 => 328, 31_000 => 331, 31_500 => 334, 32_000 => 337,
          32_500 => 340, 33_000 => 343, 33_500 => 347, 34_000 => 349, 34_500 => 353,
          35_000 => 356, 35_500 => 358, 36_000 => 361, 36_500 => 365, 37_000 => 367,
          37_500 => 371, 38_000 => 374, 38_500 => 377, 39_000 => 379, 39_500 => 383,
          40_000 => 385, 40_500 => 390, 41_000 => 392, 41_500 => 395, 42_000 => 398,
          42_500 => 401, 43_000 => 403, 43_500 => 407, 44_000 => 410, 44_500 => 413,
          45_000 => 417, 45_500 => 419, 46_000 => 422, 46_500 => 426, 47_000 => 428,
          47_500 => 430, 48_000 => 435, 48_500 => 438, 49_000 => 441, 49_500 => 444,
          50_000 => 446, 50_500 => 449, 51_000 => 451, 51_500 => 455, 52_000 => 459,
          52_500 => 463, 53_000 => 464, 53_500 => 468, 54_000 => 471, 54_500 => 473,
          55_000 => 476, 55_500 => 479, 56_000 => 483, 56_500 => 486, 57_000 => 489,
          57_500 => 492, 58_000 => 496, 58_500 => 498, 59_000 => 500, 59_500 => 504,
          60_000 => 508, 60_500 => 511, 61_000 => 514, 61_500 => 516, 62_000 => 519,
          62_500 => 523, 63_000 => 525, 63_500 => 528, 64_000 => 532, 64_500 => 535,
          65_000 => 537, 65_500 => 540, 66_000 => 544, 66_500 => 548, 67_000 => 551,
          67_500 => 552, 68_000 => 555, 68_500 => 559, 69_000 => 562, 69_500 => 564,
          70_000 => 568, 70_500 => 572, 71_000 => 575, 71_500 => 577, 72_000 => 580,
          72_500 => 583, 73_000 => 586, 73_500 => 589, 74_000 => 592, 74_500 => 596,
          75_000 => 599, 75_500 => 601, 76_000 => 604, 76_500 => 607, 77_000 => 610,
          77_500 => 613, 78_000 => 617, 78_500 => 620, 79_000 => 624, 79_500 => 625,
          80_000 => 628, 80_500 => 632, 81_000 => 635, 81_500 => 637, 82_000 => 640,
          82_500 => 644, 83_000 => 648, 83_500 => 650, 84_000 => 653, 84_500 => 656,
          85_000 => 659, 85_500 => 662, 86_000 => 664, 86_500 => 669, 87_000 => 672,
          87_500 => 674, 88_000 => 677, 88_500 => 680, 89_000 => 684, 89_500 => 686,
          90_000 => 689, 90_500 => 692, 91_000 => 696, 91_500 => 699, 92_000 => 701,
          92_500 => 705, 93_000 => 707, 93_500 => 711, 94_000 => 712, 94_500 => 716,
          95_000 => 721, 95_500 => 724, 96_000 => 725, 96_500 => 728, 97_000 => 732,
          97_500 => 735, 98_000 => 738, 98_500 => 742, 99_000 => 744, 99_500 => 747,
          100_000 => 749
        }

        # Create tiers for the detailed table
        sorted_amounts = detailed_rates.keys.sort
        sorted_amounts.each_with_index do |amount, index|
          min_val = amount
          max_val = sorted_amounts[index + 1] ? sorted_amounts[index + 1] - 1 : amount
          rate = detailed_rates[amount]

          tiers << {
            min: min_val,
            max: max_val,
            rate: rate,
            per_thousand: nil,
            elc: 0
          }
        end

        # Formula-based tiers for > $100,000 (from page 2-3 of PDF)
        # These use a formula: (liability - subtract) * multiply_by + add
        # We'll store these as per_thousand rates for consistency
        formula_tiers = [
          { min: 100_001, max: 1_000_000, subtract: 100_000, multiply: 0.00474, add: 749 },
          { min: 1_000_001, max: 5_000_000, subtract: 1_000_000, multiply: 0.00390, add: 5_018 },
          { min: 5_000_001, max: 15_000_000, subtract: 5_000_000, multiply: 0.00321, add: 20_606 },
          { min: 15_000_001, max: 25_000_000, subtract: 15_000_000, multiply: 0.00229, add: 52_736 },
          { min: 25_000_001, max: 50_000_000, subtract: 25_000_000, multiply: 0.00137, add: 75_596 },
          { min: 50_000_001, max: 100_000_000, subtract: 50_000_000, multiply: 0.00124, add: 109_796 },
          { min: 100_000_001, max: nil, subtract: 100_000_000, multiply: 0.00112, add: 171_896 }
        ]

        # Store formula parameters in notes or we could implement a formula-based calculation
        # For now, we'll pre-calculate some sample points and use per_thousand approximation
        # Or better: we'll implement custom TX calculation logic in RateTier model

        # Return both detailed and formula tiers
        { detailed: tiers, formula: formula_tiers }
      end
    end
  end
end

# Run if executed directly
if __FILE__ == $0
  # Parse endorsements
  csv_path = File.expand_path("../../../tx_endorsements.csv", __FILE__)
  endorsements = TitleRound::Seeds::ParseTXData.parse_endorsements(csv_path)

  puts "Parsed #{endorsements.length} endorsements"
  puts "\nSample endorsements:"
  endorsements.first(5).each do |e|
    puts "  #{e[:code]}: #{e[:name]} - #{e[:pricing_type]} - #{e[:percentage] || e[:base_amount]}"
  end

  # Generate rate tiers
  tiers = TitleRound::Seeds::ParseTXData.generate_tx_rate_tiers
  puts "\nGenerated #{tiers[:detailed].length} detailed rate tiers"
  puts "\nSample detailed tiers:"
  tiers[:detailed].first(3).each do |t|
    puts "  $#{t[:min]} - $#{t[:max]}: $#{t[:rate]}"
  end
end
