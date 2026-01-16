#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for TX title insurance calculations

require_relative "../lib/ratenode"

# Setup database in memory
RateNode.setup_database(":memory:")

# Seed all data (CA, NC, TX)
puts "Seeding database..."
RateNode::Seeds::Rates.seed_all

# Test 1: Calculate $300,000 TX owner's policy (standard)
puts "\n=== Test 1: $300,000 TX Owner's Policy (Standard) ==="
liability_cents = 30_000_000  # $300,000
state = "TX"
underwriter = "DEFAULT"

calc = RateNode::Calculators::OwnersPolicy.new(
  liability_cents: liability_cents,
  policy_type: :standard,
  state: state,
  underwriter: underwriter
)

premium_cents = calc.calculate
puts "Liability: $#{liability_cents / 100}"
puts "Premium: $#{premium_cents / 100.0} (#{premium_cents} cents)"

# Verify it matches the TX formula for $300k
# Formula for $100,001 - $1,000,000: (liability - 100,000) * 0.0054775 + $749
# For $300,000: ($300,000 - $100,000) * 0.0054775 + $749 = $200,000 * 0.0054775 + $749 = $1,095.50 + $749 = $1,844.50 -> $1,845
expected_dollars = ((300_000 - 100_000) * 0.0054775).round + 749
expected_cents = expected_dollars * 100
puts "Expected: $#{expected_cents / 100.0} (#{expected_cents} cents)"
puts "Match: #{premium_cents == expected_cents ? 'YES' : 'NO'}"

# Test 2: Check CPL for TX (should be $0)
puts "\n=== Test 2: CPL for TX (Should be $0) ==="
cpl_calc = RateNode::Calculators::CPLCalculator.new(
  liability_cents: liability_cents,
  state: state,
  underwriter: underwriter
)

cpl_cents = cpl_calc.calculate
puts "CPL: $#{cpl_cents / 100.0} (#{cpl_cents} cents)"
puts "Match expected ($0): #{cpl_cents == 0 ? 'YES' : 'NO'}"

# Test 3: Find and test a percentage_basic endorsement
puts "\n=== Test 3: Percentage_Basic Endorsement (by code) ==="
# Find T-19 Residential endorsement by code 0885
endorsement = RateNode::Models::Endorsement.find_by_code("0885", state: state, underwriter: underwriter)

if endorsement
  puts "Found: #{endorsement.code} (Form: #{endorsement.form_code}) - #{endorsement.name}"
  puts "Pricing Type: #{endorsement.pricing_type}"
  puts "Percentage: #{(endorsement.percentage * 100).round}%" if endorsement.percentage

  # Calculate endorsement premium
  endorsement_premium = endorsement.calculate_premium(liability_cents, state: state, underwriter: underwriter)
  puts "Endorsement Premium: $#{endorsement_premium / 100.0} (#{endorsement_premium} cents)"

  # For percentage_basic, it should use the basic rate
  # Basic rate for $300k = $1,697 (same as premium for TX)
  # If 5% of basic: $1,697 * 0.05 = $84.85, with min $50 = $84.85
  if endorsement.percentage
    basic_rate = RateNode::Models::RateTier.find_basic_rate(liability_cents, state: state, underwriter: underwriter)
    expected_endo = (basic_rate * endorsement.percentage).ceil
    expected_endo = [expected_endo, endorsement.min_cents].max if endorsement.min_cents
    puts "Expected: $#{expected_endo / 100.0} (based on basic rate of $#{basic_rate / 100.0})"
    puts "Match: #{endorsement_premium == expected_endo ? 'YES' : 'NO'}"
  end
else
  puts "ERROR: Endorsement 0885 (T-19 Res) not found"
end

# Test 4: List all TX endorsements
puts "\n=== Test 4: TX Endorsements Summary ==="
all_endorsements = RateNode::Models::Endorsement.all(state: state, underwriter: underwriter)
puts "Total TX endorsements: #{all_endorsements.length}"

pricing_breakdown = all_endorsements.group_by(&:pricing_type).transform_values(&:count)
pricing_breakdown.each do |type, count|
  puts "  #{type}: #{count}"
end

# Test 5: Test a policy > $100k using formula
puts "\n=== Test 5: $500,000 TX Policy (Formula-based) ==="
large_liability = 50_000_000  # $500,000

large_calc = RateNode::Calculators::OwnersPolicy.new(
  liability_cents: large_liability,
  policy_type: :standard,
  state: state,
  underwriter: underwriter
)

large_premium = large_calc.calculate
puts "Liability: $#{large_liability / 100}"
puts "Premium: $#{large_premium / 100.0} (#{large_premium} cents)"

# Formula for $100,001 - $1,000,000: (liability - 100,000) * 0.0054775 + $749
# For $500,000: ($500,000 - $100,000) * 0.0054775 + $749 = $400,000 * 0.0054775 + $749 = $2,191 + $749 = $2,940
expected_large_dollars = ((500_000 - 100_000) * 0.0054775).round + 749
expected_large = expected_large_dollars * 100
puts "Expected: $#{expected_large / 100.0} (#{expected_large} cents)"
puts "Match: #{large_premium == expected_large ? 'YES' : 'NO'}"

puts "\n=== All Tests Complete ==="
