# frozen_string_literal: true

module RateNode
  module Output
    class ClosingDisclosure
      attr_reader :transaction, :owners_policy, :lenders_policy, :endorsements, :cpl, :totals

      def initialize(transaction:, owners_policy:, lenders_policy:, endorsements:, totals:, cpl: nil)
        @transaction = transaction
        @owners_policy = owners_policy
        @lenders_policy = lenders_policy
        @endorsements = endorsements
        @cpl = cpl
        @totals = totals
      end

      def to_h
        {
          transaction: transaction,
          owners_policy: owners_policy,
          lenders_policy: lenders_policy,
          endorsements: endorsements,
          cpl: cpl,
          totals: totals
        }
      end

      def to_json(*args)
        require "json"
        to_h.to_json(*args)
      end

      def format_currency(cents)
        return "$0.00" if cents.nil? || cents.zero?

        dollars = cents / 100.0
        whole, decimal = format("%.2f", dollars).split(".")
        whole_with_commas = whole.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        "$#{whole_with_commas}.#{decimal}"
      end

      def to_s
        lines = []
        lines << "=" * 50
        lines << "TITLE INSURANCE PREMIUM CALCULATION"
        lines << "=" * 50
        lines << ""
        lines << "Transaction: #{transaction[:type].capitalize}"
        lines << "Property: #{transaction[:property_address]}" if transaction[:property_address]
        lines << "Purchase Price: #{format_currency(transaction[:purchase_price_cents])}" if transaction[:purchase_price_cents].positive?
        lines << "Loan Amount: #{format_currency(transaction[:loan_amount_cents])}" if transaction[:loan_amount_cents].positive?
        lines << ""
        lines << "-" * 50

        if owners_policy
          lines << ""
          lines << "OWNER'S POLICY"
          lines << "  #{owners_policy[:line_item]}"
          lines << "  Liability: #{format_currency(owners_policy[:liability_cents])}"

          # Show reissue discount breakdown if applicable
          if owners_policy[:reissue_discount_cents] && owners_policy[:reissue_discount_cents] > 0
            base_premium = owners_policy[:premium_cents] + owners_policy[:reissue_discount_cents]
            lines << "  Base Premium: #{format_currency(base_premium)}"
            lines << "  Less: Reissue Discount (50%): -#{format_currency(owners_policy[:reissue_discount_cents])}"
            lines << "  Net Premium: #{format_currency(owners_policy[:premium_cents])}"
          else
            lines << "  Premium: #{format_currency(owners_policy[:premium_cents])}"
          end
        end

        if lenders_policy
          lines << ""
          lines << "LENDER'S POLICY"
          lines << "  #{lenders_policy[:line_item]}"
          lines << "  Liability: #{format_currency(lenders_policy[:liability_cents])}"
          lines << "  Premium: #{format_currency(lenders_policy[:premium_cents])}"
        end

        unless endorsements.empty?
          lines << ""
          lines << "ENDORSEMENTS"
          endorsements.each do |e|
            lines << "  #{e[:code]}: #{format_currency(e[:amount_cents])}"
          end
        end

        if cpl && cpl[:amount_cents] && cpl[:amount_cents] > 0
          lines << ""
          lines << "CLOSING PROTECTION LETTER"
          lines << "  #{cpl[:line_item]}: #{format_currency(cpl[:amount_cents])}"
        end

        lines << ""
        lines << "-" * 50
        lines << "TOTALS"
        lines << "  Title Insurance: #{format_currency(totals[:title_insurance_cents])}"
        lines << "  Endorsements: #{format_currency(totals[:endorsements_cents])}" unless endorsements.empty?
        lines << "  CPL: #{format_currency(totals[:cpl_cents])}" if totals[:cpl_cents] && totals[:cpl_cents] > 0
        lines << "  GRAND TOTAL: #{format_currency(totals[:grand_total_cents])}"
        lines << "=" * 50

        lines.join("\n")
      end
    end
  end
end
