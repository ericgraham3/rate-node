#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require_relative '../../lib/ratenode'

# Initialize database
RateNode.setup_database

input_csv = File.join(__dir__, '../fixtures/scenarios_input.csv')
output_csv = File.join(__dir__, '../fixtures/test_scenarios.csv')

puts "Reading scenarios from: #{input_csv}"
puts "Generating expected values..."

scenarios = []
CSV.foreach(input_csv, headers: true) do |row|
  scenarios << row.to_h
end

results = []

scenarios.each do |scenario|
  scenario_name = scenario['scenario_name']
  state = scenario['state']
  underwriter = scenario['underwriter']
  transaction_type = scenario['transaction_type']
  
  # Skip empty rows
  next if scenario_name.nil? || scenario_name.strip.empty?
  
  puts "\nProcessing: #{scenario_name}"
  
  # Validate state/underwriter combination
  if (state == 'CA' && underwriter != 'TRG') || (state == 'NC' && underwriter != 'INVESTORS')
    puts "  ERROR: Invalid combination - #{state} + #{underwriter}"
    next
  end
  
  # Build parameters
  params = {
    state: state,
    underwriter: underwriter,
    transaction_type: transaction_type.to_sym
  }
  
  if transaction_type == 'purchase'
    params[:purchase_price_cents] = scenario['purchase_price'].to_i * 100
    params[:loan_amount_cents] = scenario['loan_amount'].to_i * 100
    params[:owner_policy_type] = scenario['policy_type'].to_sym
    params[:include_lenders_policy] = scenario['loan_amount'].to_i > 0
  else # refinance
    params[:loan_amount_cents] = scenario['loan_amount'].to_i * 100
    params[:include_lenders_policy] = true
  end
  
  # Parse endorsements
  endorsement_codes = scenario['endorsements'].to_s.split(',').map(&:strip).reject(&:empty?)
  params[:endorsement_codes] = endorsement_codes unless endorsement_codes.empty?
  
  # Calculate
  begin
    result = RateNode.calculate(params)
    
    owners_premium = result.owners_policy ? (result.owners_policy[:premium_cents] / 100.0) : 0.0
    lenders_premium = result.lenders_policy ? (result.lenders_policy[:premium_cents] / 100.0) : 0.0
    endorsements_total = (result.totals[:endorsements_cents] / 100.0)
    grand_total = (result.totals[:grand_total_cents] / 100.0)
    
    results << {
      scenario_name: scenario_name,
      state: state,
      underwriter: underwriter,
      transaction_type: transaction_type,
      purchase_price: scenario['purchase_price'],
      loan_amount: scenario['loan_amount'],
      policy_type: scenario['policy_type'],
      endorsements: scenario['endorsements'],
      expected_owners_premium: format('%.2f', owners_premium),
      expected_lenders_premium: format('%.2f', lenders_premium),
      expected_endorsements: format('%.2f', endorsements_total),
      expected_total: format('%.2f', grand_total)
    }
    
    puts "  ✓ Owners: $#{format('%.2f', owners_premium)}, Lenders: $#{format('%.2f', lenders_premium)}, Endorsements: $#{format('%.2f', endorsements_total)}, Total: $#{format('%.2f', grand_total)}"
  rescue => e
    puts "  ✗ ERROR: #{e.message}"
    puts "  #{e.backtrace.first}"
  end
end

# Write output CSV
puts "\n\nWriting results to: #{output_csv}"

CSV.open(output_csv, 'w', write_headers: true, headers: [
  'scenario_name', 'state', 'underwriter', 'transaction_type', 'purchase_price', 
  'loan_amount', 'policy_type', 'endorsements', 
  'expected_owners_premium', 'expected_lenders_premium', 'expected_endorsements', 'expected_total'
]) do |csv|
  results.each do |result|
    csv << [
      result[:scenario_name],
      result[:state],
      result[:underwriter],
      result[:transaction_type],
      result[:purchase_price],
      result[:loan_amount],
      result[:policy_type],
      result[:endorsements],
      result[:expected_owners_premium],
      result[:expected_lenders_premium],
      result[:expected_endorsements],
      result[:expected_total]
    ]
  end
end

puts "\n✓ Generated #{results.length} scenarios in #{output_csv}"

