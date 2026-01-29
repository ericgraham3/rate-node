# frozen_string_literal: true

require 'csv'
require 'spec_helper'

RSpec.describe "CSV Scenario Testing" do
  let(:csv_path) { File.join(__dir__, '../fixtures/scenarios_input.csv') }
  let(:tolerance) { 2.00 } # Allow $2 difference for rounding

  before(:all) do
    RateNode.setup_database(":memory:")
  end

  # Helper to parse CSV value - converts empty strings to nil
  def parse_value(value)
    return nil if value.nil? || value.to_s.strip.empty?
    value.strip
  end

  # Helper to parse numeric value
  def parse_number(value)
    parsed = parse_value(value)
    return nil if parsed.nil?
    parsed.to_f
  end

  # Helper to parse integer value
  def parse_int(value)
    parsed = parse_value(value)
    return nil if parsed.nil?
    parsed.to_i
  end

  # Helper to parse boolean (TRUE/FALSE strings)
  def parse_bool(value)
    parsed = parse_value(value)
    return false if parsed.nil?
    parsed.upcase == 'TRUE'
  end

  # Helper to parse date (M/D/YYYY format)
  def parse_date(value)
    parsed = parse_value(value)
    return nil if parsed.nil?
    Date.strptime(parsed, '%m/%d/%Y')
  rescue ArgumentError
    nil
  end

  # Helper to format currency
  def fmt(amount)
    "$#{format('%.2f', amount || 0)}"
  end

  # Helper to get default underwriter for state
  def default_underwriter(state)
    case state
    when 'CA' then 'TRG'
    when 'NC' then 'TRG'
    when 'TX' then 'DEFAULT'
    when 'FL' then 'TRG'
    else nil
    end
  end

  it "passes all scenarios from CSV" do
    scenarios = []
    results = []

    # Parse all scenarios from CSV
    CSV.foreach(csv_path, headers: true) do |row|
      scenario_name = parse_value(row['scenario_name'])
      next if scenario_name.nil?

      scenarios << {
        name: scenario_name,
        state: parse_value(row['state']),
        underwriter: parse_value(row['underwriter']),
        transaction_type: parse_value(row['transaction_type']),
        purchase_price: parse_int(row['purchase_price']),
        loan_amount: parse_int(row['loan_amount']),
        prior_policy_amount: parse_int(row['prior_policy_amount']),
        prior_policy_date: parse_date(row['prior_policy_date']),
        owners_policy_type: parse_value(row['owners_policy_type']),
        lender_policy_type: parse_value(row['lender_policy_type']),
        endorsements: parse_value(row['endorsements']),
        cpl: parse_bool(row['cpl']),
        property_type: parse_value(row['property_type']),
        expected_owners_premium: parse_number(row['expected_owners_premium']),
        expected_lenders_premium: parse_number(row['expected_lenders_premium']),
        expected_endorsement_charges: parse_number(row['expected_endorsement_charges']),
        expected_cpl_charges: parse_number(row['expected_cpl_charges']),
        expected_reissue_discount: parse_number(row['expected_reissue_discount']),
        expected_total: parse_number(row['expected_total'])
      }
    end

    puts "\n"
    puts "=" * 60
    puts "RateNode CSV Scenario Tests"
    puts "=" * 60

    # Process each scenario
    scenarios.each do |scenario|
      state = scenario[:state]
      underwriter = scenario[:underwriter] || default_underwriter(state)

      # Build parameters
      params = {
        state: state,
        underwriter: underwriter,
        transaction_type: (scenario[:transaction_type] || 'purchase').to_sym
      }

      if params[:transaction_type] == :purchase
        params[:purchase_price_cents] = (scenario[:purchase_price] || 0) * 100
        params[:loan_amount_cents] = (scenario[:loan_amount] || 0) * 100
        params[:owner_policy_type] = (scenario[:owners_policy_type] || 'standard').to_sym
        params[:include_lenders_policy] = (scenario[:loan_amount] || 0) > 0
      else # refinance
        params[:loan_amount_cents] = (scenario[:loan_amount] || 0) * 100
        params[:include_lenders_policy] = true
      end

      # Endorsements
      if scenario[:endorsements]
        codes = scenario[:endorsements].split(',').map(&:strip).reject(&:empty?)
        params[:endorsement_codes] = codes unless codes.empty?
      end

      # CPL
      params[:include_cpl] = scenario[:cpl]

      # Prior policy (reissue discount)
      if scenario[:prior_policy_amount] && scenario[:prior_policy_date]
        params[:prior_policy_amount_cents] = scenario[:prior_policy_amount] * 100
        params[:prior_policy_date] = scenario[:prior_policy_date]
      end

      # Property type (for FL endorsements)
      params[:property_type] = scenario[:property_type] if scenario[:property_type]

      # Calculate
      result = {
        scenario: scenario[:name],
        passed: true,
        error: nil,
        checks: [],
        failed_checks: []
      }

      begin
        calc_result = RateNode.calculate(params)

        # Extract actual values
        actual = {
          owners: calc_result.owners_policy ? (calc_result.owners_policy[:premium_cents] / 100.0) : 0.0,
          lenders: calc_result.lenders_policy ? (calc_result.lenders_policy[:premium_cents] / 100.0) : 0.0,
          endorsements: (calc_result.totals[:endorsements_cents] / 100.0),
          cpl: calc_result.cpl ? (calc_result.cpl[:amount_cents] / 100.0) : 0.0,
          reissue_discount: calc_result.owners_policy&.dig(:reissue_discount_cents) ?
            (calc_result.owners_policy[:reissue_discount_cents] / 100.0) : 0.0,
          total: (calc_result.totals[:grand_total_cents] / 100.0)
        }

        # Expected values
        expected = {
          owners: scenario[:expected_owners_premium] || 0.0,
          lenders: scenario[:expected_lenders_premium] || 0.0,
          endorsements: scenario[:expected_endorsement_charges] || 0.0,
          cpl: scenario[:expected_cpl_charges] || 0.0,
          reissue_discount: scenario[:expected_reissue_discount] || 0.0,
          total: scenario[:expected_total]
        }

        # Calculate expected total if not provided
        if expected[:total].nil?
          expected[:total] = expected[:owners] + expected[:lenders] +
                            expected[:endorsements] + expected[:cpl] -
                            expected[:reissue_discount]
        end

        # Check each field
        checks = [
          { name: 'Owners Premium', key: :owners, expected: expected[:owners], actual: actual[:owners] },
          { name: 'Lenders Premium', key: :lenders, expected: expected[:lenders], actual: actual[:lenders] },
          { name: 'Endorsements', key: :endorsements, expected: expected[:endorsements], actual: actual[:endorsements] },
          { name: 'CPL', key: :cpl, expected: expected[:cpl], actual: actual[:cpl] },
          { name: 'Reissue Discount', key: :reissue_discount, expected: expected[:reissue_discount], actual: actual[:reissue_discount] },
          { name: 'Total', key: :total, expected: expected[:total], actual: actual[:total] }
        ]

        checks.each do |check|
          diff = (check[:actual] - check[:expected]).abs
          within_tolerance = diff <= tolerance
          warning = diff > 0 && within_tolerance

          check[:diff] = diff
          check[:passed] = within_tolerance
          check[:warning] = warning

          # Only show check if expected is non-zero OR actual is non-zero
          if check[:expected] != 0 || check[:actual] != 0
            result[:checks] << check
            result[:failed_checks] << check unless check[:passed]
          end
        end

        result[:passed] = result[:failed_checks].empty?

      rescue => e
        result[:passed] = false
        result[:error] = "#{e.class}: #{e.message}"
        result[:backtrace] = e.backtrace.first
      end

      results << result

      # Output for this scenario
      puts "\n  Scenario: #{scenario[:name]}"

      if result[:error]
        puts "    ERROR: #{result[:error]}"
        puts "    #{result[:backtrace]}" if result[:backtrace]
      else
        result[:checks].each do |check|
          if check[:passed]
            status = check[:warning] ? "\u2713 (within tolerance)" : "\u2713"
            diff_note = check[:warning] ? " [diff: #{fmt(check[:diff])}]" : ""
            puts "    #{status} #{check[:name]}: #{fmt(check[:actual])} (expected #{fmt(check[:expected])})#{diff_note}"
          else
            puts "    \u2717 #{check[:name]}: #{fmt(check[:actual])} (expected #{fmt(check[:expected])}) DIFF: #{fmt(check[:diff])}"
          end
        end
      end

      status_text = result[:passed] ? "PASSED" : "FAILED"
      puts "    Status: #{status_text}"
    end

    # Summary
    passed = results.count { |r| r[:passed] }
    failed = results.count { |r| !r[:passed] }
    total = results.length

    puts "\n"
    puts "=" * 60
    puts "Test Summary"
    puts "=" * 60
    puts "Total Scenarios: #{total}"
    puts "Passed: #{passed}"
    puts "Failed: #{failed}"

    if failed > 0
      puts "\nFailed Scenarios:"
      results.reject { |r| r[:passed] }.each do |result|
        if result[:error]
          puts "  - #{result[:scenario]}: #{result[:error]}"
        else
          issues = result[:failed_checks].map do |check|
            "#{check[:name]} off by #{fmt(check[:diff])}"
          end.join(', ')
          puts "  - #{result[:scenario]}: #{issues}"
        end
      end
    end

    puts "=" * 60
    puts "\n"

    # Single assertion
    expect(failed).to eq(0),
      "#{failed} of #{total} scenarios failed. See output above for details."
  end
end
