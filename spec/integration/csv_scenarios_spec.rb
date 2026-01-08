# frozen_string_literal: true

require 'csv'
require 'spec_helper'

RSpec.describe "CSV Scenario Testing" do
  let(:csv_path) { File.join(__dir__, '../fixtures/scenarios_input.csv') }
  let(:tolerance) { 2.00 } # Allow $2 difference for rounding

  before(:all) do
    # Use persistent database for integration tests
    TitleRound.setup_database
  end

  it "passes all scenarios from CSV" do
    scenarios_passed = 0
    scenarios_failed = 0
    failures = []

    CSV.foreach(csv_path, headers: true) do |row|
      scenario_name = row['scenario_name']
      state = row['state']
      underwriter = row['underwriter']
      transaction_type = row['transaction_type']
      
      # Skip empty rows
      next if scenario_name.nil? || scenario_name.strip.empty?
      
      # Validate state/underwriter combination (allow both NC/INVESTORS and NC/TRG)
      valid_combinations = [
        ['CA', 'TRG'],
        ['NC', 'INVESTORS'],
        ['NC', 'TRG']
      ]
      unless valid_combinations.include?([state, underwriter])
        failures << {
          scenario: scenario_name,
          error: "Invalid state/underwriter combination: #{state} + #{underwriter}"
        }
        scenarios_failed += 1
        next
      end

      # Build parameters hash
      params = {
        state: state,
        underwriter: underwriter,
        transaction_type: transaction_type.to_sym
      }

      if transaction_type == 'purchase'
        params[:purchase_price_cents] = row['purchase_price'].to_i * 100
        params[:loan_amount_cents] = row['loan_amount'].to_i * 100

        # Use owners_policy_type column name from CSV
        policy_type = row['owners_policy_type'] || row['policy_type']
        params[:owner_policy_type] = policy_type.to_sym if policy_type && !policy_type.strip.empty?
        params[:include_lenders_policy] = row['loan_amount'].to_i > 0
      else # refinance
        params[:loan_amount_cents] = row['loan_amount'].to_i * 100
        params[:include_lenders_policy] = true
      end

      # Parse endorsements
      endorsement_codes = row['endorsements'].to_s.split(',').map(&:strip).reject(&:empty?)
      params[:endorsement_codes] = endorsement_codes unless endorsement_codes.empty?

      # Parse CPL flag (TRUE/FALSE string to boolean)
      cpl_value = row['cpl'].to_s.strip.upcase
      params[:include_cpl] = (cpl_value == 'TRUE')

      # Parse prior policy date
      if row['prior_policy_date'] && !row['prior_policy_date'].strip.empty?
        params[:prior_policy_date] = Date.strptime(row['prior_policy_date'], '%m/%d/%Y')
      end

      # Parse prior policy amount
      if row['prior_policy_amount'] && !row['prior_policy_amount'].strip.empty?
        params[:prior_policy_amount_cents] = row['prior_policy_amount'].to_i * 100
      end

      # Calculate
      begin
        result = TitleRound.calculate(params)

        # Extract actual values
        actual_owners = result.owners_policy ? (result.owners_policy[:premium_cents] / 100.0) : 0.0
        actual_lenders = result.lenders_policy ? (result.lenders_policy[:premium_cents] / 100.0) : 0.0
        actual_endorsements = (result.totals[:endorsements_cents] / 100.0)
        actual_cpl = result.cpl ? (result.cpl[:amount_cents] / 100.0) : 0.0
        actual_reissue_discount = result.owners_policy && result.owners_policy[:reissue_discount_cents] ?
          (result.owners_policy[:reissue_discount_cents] / 100.0) : 0.0
        actual_total = (result.totals[:grand_total_cents] / 100.0)

        # Expected values from CSV
        expected_owners = row['expected_owners_premium'].to_f
        expected_lenders = row['expected_lenders_premium'] && !row['expected_lenders_premium'].strip.empty? ?
          row['expected_lenders_premium'].to_f : 0.0
        expected_endorsements = row['expected_endorsement_charges'] && !row['expected_endorsement_charges'].strip.empty? ?
          row['expected_endorsement_charges'].to_f : 0.0
        expected_cpl = row['expected_cpl_charges'] && !row['expected_cpl_charges'].strip.empty? ?
          row['expected_cpl_charges'].to_f : 0.0
        expected_reissue_discount = row['expected_reissue_discount'] && !row['expected_reissue_discount'].strip.empty? ?
          row['expected_reissue_discount'].to_f : 0.0

        # For total, calculate if not provided
        if row['expected_total'] && !row['expected_total'].strip.empty?
          expected_total = row['expected_total'].to_f
        else
          expected_total = expected_owners + expected_lenders + expected_endorsements + expected_cpl
        end

        # Compare with tolerance
        owners_diff = (actual_owners - expected_owners).abs
        lenders_diff = (actual_lenders - expected_lenders).abs
        endorsements_diff = (actual_endorsements - expected_endorsements).abs
        cpl_diff = (actual_cpl - expected_cpl).abs
        reissue_diff = (actual_reissue_discount - expected_reissue_discount).abs
        total_diff = (actual_total - expected_total).abs

        if owners_diff > tolerance || lenders_diff > tolerance ||
           endorsements_diff > tolerance || cpl_diff > tolerance ||
           reissue_diff > tolerance || total_diff > tolerance
          failures << {
            scenario: scenario_name,
            owners: { expected: expected_owners, actual: actual_owners, diff: owners_diff },
            lenders: { expected: expected_lenders, actual: actual_lenders, diff: lenders_diff },
            endorsements: { expected: expected_endorsements, actual: actual_endorsements, diff: endorsements_diff },
            cpl: { expected: expected_cpl, actual: actual_cpl, diff: cpl_diff },
            reissue_discount: { expected: expected_reissue_discount, actual: actual_reissue_discount, diff: reissue_diff },
            total: { expected: expected_total, actual: actual_total, diff: total_diff }
          }
          scenarios_failed += 1
        else
          scenarios_passed += 1
        end
      rescue => e
        failures << {
          scenario: scenario_name,
          error: "Exception: #{e.message}",
          backtrace: e.backtrace.first
        }
        scenarios_failed += 1
      end
    end

    # Output failure details
    if failures.any?
      puts "\n" + "=" * 80
      puts "FAILED SCENARIOS (#{scenarios_failed} of #{scenarios_passed + scenarios_failed})"
      puts "=" * 80
      
      failures.each do |failure|
        puts "\nScenario: #{failure[:scenario]}"
        if failure[:error]
          puts "  ERROR: #{failure[:error]}"
          puts "  #{failure[:backtrace]}" if failure[:backtrace]
        else
          if failure[:owners][:diff] > tolerance
            puts "  Owners Premium: Expected $#{format('%.2f', failure[:owners][:expected])}, " \
                 "Actual $#{format('%.2f', failure[:owners][:actual])}, " \
                 "Diff $#{format('%.2f', failure[:owners][:diff])}"
          end
          if failure[:lenders][:diff] > tolerance
            puts "  Lenders Premium: Expected $#{format('%.2f', failure[:lenders][:expected])}, " \
                 "Actual $#{format('%.2f', failure[:lenders][:actual])}, " \
                 "Diff $#{format('%.2f', failure[:lenders][:diff])}"
          end
          if failure[:endorsements][:diff] > tolerance
            puts "  Endorsements: Expected $#{format('%.2f', failure[:endorsements][:expected])}, " \
                 "Actual $#{format('%.2f', failure[:endorsements][:actual])}, " \
                 "Diff $#{format('%.2f', failure[:endorsements][:diff])}"
          end
          if failure[:cpl] && failure[:cpl][:diff] > tolerance
            puts "  CPL: Expected $#{format('%.2f', failure[:cpl][:expected])}, " \
                 "Actual $#{format('%.2f', failure[:cpl][:actual])}, " \
                 "Diff $#{format('%.2f', failure[:cpl][:diff])}"
          end
          if failure[:reissue_discount] && failure[:reissue_discount][:diff] > tolerance
            puts "  Reissue Discount: Expected $#{format('%.2f', failure[:reissue_discount][:expected])}, " \
                 "Actual $#{format('%.2f', failure[:reissue_discount][:actual])}, " \
                 "Diff $#{format('%.2f', failure[:reissue_discount][:diff])}"
          end
          if failure[:total][:diff] > tolerance
            puts "  Total: Expected $#{format('%.2f', failure[:total][:expected])}, " \
                 "Actual $#{format('%.2f', failure[:total][:actual])}, " \
                 "Diff $#{format('%.2f', failure[:total][:diff])}"
          end
        end
      end
      puts "\n" + "=" * 80
    end

    expect(scenarios_failed).to eq(0), 
      "Expected all scenarios to pass, but #{scenarios_failed} failed. See output above for details."
    expect(scenarios_passed).to be > 0,
      "No scenarios were processed. Check CSV file format."
  end
end




