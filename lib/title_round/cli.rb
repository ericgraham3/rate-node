# frozen_string_literal: true

require "thor"
require "date"

module TitleRound
  class CLI < Thor
    desc "calculate", "Calculate title insurance premiums"
    option :type, type: :string, default: "purchase", desc: "Transaction type: purchase or refinance"
    option :state, type: :string, required: true, desc: "State code (e.g., CA, NC)"
    option :underwriter, type: :string, required: true, desc: "Underwriter code (e.g., TRG, INVESTORS)"
    option :as_of_date, type: :string, desc: "Effective date (YYYY-MM-DD), defaults to today"
    option :purchase_price, type: :numeric, desc: "Purchase price in dollars"
    option :loan_amount, type: :numeric, desc: "Loan amount in dollars"
    option :policy_type, type: :string, default: "standard", desc: "Owner policy type: standard, homeowner, or extended"
    option :no_lenders_policy, type: :boolean, default: false, desc: "Exclude lender's policy"
    option :endorsements, type: :string, desc: "Comma-separated endorsement codes"
    option :address, type: :string, desc: "Property address"
    option :json, type: :boolean, default: false, desc: "Output as JSON"

    def calculate
      validate_options!
      ensure_database!

      result = Calculator.new(
        transaction_type: options[:type],
        property_address: options[:address],
        purchase_price_cents: dollars_to_cents(options[:purchase_price]),
        loan_amount_cents: dollars_to_cents(options[:loan_amount]),
        owner_policy_type: options[:policy_type],
        include_lenders_policy: !options[:no_lenders_policy],
        endorsement_codes: parse_endorsements(options[:endorsements]),
        state: options[:state],
        underwriter: options[:underwriter],
        as_of_date: parse_date(options[:as_of_date])
      ).calculate

      if options[:json]
        puts result.to_json
      else
        puts result.to_s
      end
    rescue TitleRound::Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc "seed", "Initialize database with rate tables"
    def seed
      TitleRound.setup_database
      puts "Database seeded successfully!"
    end

    desc "version", "Show version"
    def version
      puts "TitleRound v0.1.0"
    end

    private

    def validate_options!
      case options[:type]
      when "purchase"
        raise Error, "Purchase price is required for purchase transactions" unless options[:purchase_price]
      when "refinance"
        raise Error, "Loan amount is required for refinance transactions" unless options[:loan_amount]
      else
        raise Error, "Unknown transaction type: #{options[:type]}"
      end
    end

    def dollars_to_cents(dollars)
      return 0 unless dollars

      (dollars * 100).to_i
    end

    def parse_endorsements(codes)
      return [] unless codes

      codes.split(",").map(&:strip)
    end

    def parse_date(date_string)
      return Date.today unless date_string

      Date.parse(date_string)
    rescue ArgumentError
      raise Error, "Invalid date format: #{date_string}. Use YYYY-MM-DD"
    end

    def ensure_database!
      return if TitleRound.db.connection

      TitleRound.setup_database
    end
  end
end
