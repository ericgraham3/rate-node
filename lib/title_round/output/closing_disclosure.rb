# frozen_string_literal: true

module TitleRound
  module Output
    class ClosingDisclosure
      attr_reader :transaction, :owners_policy, :lenders_policy, :endorsements, :totals

      def initialize(transaction:, owners_policy:, lenders_policy:, endorsements:, totals:)
        @transaction = transaction
        @owners_policy = owners_policy
        @lenders_policy = lenders_policy
        @endorsements = endorsements
        @totals = totals
      end

      def to_h
        {
          transaction: transaction,
          owners_policy: owners_policy,
          lenders_policy: lenders_policy,
          endorsements: endorsements,
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
          lines << "  Premium: #{format_currency(owners_policy[:premium_cents])}"
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

        lines << ""
        lines << "-" * 50
        lines << "TOTALS"
        lines << "  Title Insurance: #{format_currency(totals[:title_insurance_cents])}"
        lines << "  Endorsements: #{format_currency(totals[:endorsements_cents])}" unless endorsements.empty?
        lines << "  GRAND TOTAL: #{format_currency(totals[:grand_total_cents])}"
        lines << "=" * 50

        lines.join("\n")
      end
    end
  end
end
