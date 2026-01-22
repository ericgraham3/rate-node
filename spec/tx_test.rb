#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for TX title insurance calculations
# Tests 2019 TX rates (Commissioner's Order 2019-5980, Docket No. 2812)
# Effective September 1, 2019

require_relative "../lib/ratenode"

# Setup database in memory
RateNode.setup_database(":memory:")

# Seed all data (CA, NC, TX)
puts "Seeding database..."
RateNode::Seeds::Rates.seed_all

state = "TX"
underwriter = "DEFAULT"

puts "\n" + "=" * 60
puts "TX 2019 Rate Validation Tests"
puts "Commissioner's Order 2019-5980, Docket No. 2812"
puts "Effective September 1, 2019"
puts "=" * 60

# Test direct lookup table values
puts "\n=== Direct Lookup Table Tests (≤$100,000) ==="

lookup_tests = [
  { amount: 25_000, expected: 328 },
  { amount: 50_000, expected: 496 },
  { amount: 75_000, expected: 665 },
  { amount: 100_000, expected: 832 }
]

lookup_tests.each do |test|
  liability_cents = test[:amount] * 100
  expected_cents = test[:expected] * 100

  calc = RateNode::Calculators::OwnersPolicy.new(
    liability_cents: liability_cents,
    policy_type: :standard,
    state: state,
    underwriter: underwriter
  )

  premium_cents = calc.calculate
  status = premium_cents == expected_cents ? "PASS" : "FAIL"

  puts "#{status}: $#{test[:amount].to_s.gsub(/(\d)(?=(\d{3})+$)/, '\\1,')} → " \
       "$#{premium_cents / 100} (expected: $#{test[:expected]})"
end

# Test all 7 formula validation examples from PDF
puts "\n=== Formula-Based Tests (>$100,000) ==="
puts "Testing all 7 examples from the 2019 PDF:"

formula_tests = [
  { amount: 268_500, expected: 1_720, example: 1 },
  { amount: 4_826_600, expected: 22_144, example: 2 },
  { amount: 10_902_800, expected: 43_968, example: 3 },
  { amount: 17_295_100, expected: 64_425, example: 4 },
  { amount: 39_351_800, expected: 105_810, example: 5 },
  { amount: 75_300_200, expected: 156_909, example: 6 },
  { amount: 151_250_300, expected: 254_545, example: 7 }
]

all_pass = true
formula_tests.each do |test|
  liability_cents = test[:amount] * 100
  expected_cents = test[:expected] * 100

  calc = RateNode::Calculators::OwnersPolicy.new(
    liability_cents: liability_cents,
    policy_type: :standard,
    state: state,
    underwriter: underwriter
  )

  premium_cents = calc.calculate
  status = premium_cents == expected_cents ? "PASS" : "FAIL"
  all_pass = false if premium_cents != expected_cents

  amount_formatted = test[:amount].to_s.gsub(/(\d)(?=(\d{3})+$)/, '\\1,')
  expected_formatted = test[:expected].to_s.gsub(/(\d)(?=(\d{3})+$)/, '\\1,')
  actual_formatted = (premium_cents / 100).to_s.gsub(/(\d)(?=(\d{3})+$)/, '\\1,')

  puts "Example #{test[:example]}: #{status}"
  puts "  Policy: $#{amount_formatted} → Premium: $#{actual_formatted} (expected: $#{expected_formatted})"

  if premium_cents != expected_cents
    puts "  ERROR: Difference of $#{(premium_cents - expected_cents) / 100}"
  end
end

# Test CPL for TX (should be $0)
puts "\n=== CPL for TX (Should be $0) ==="
cpl_calc = RateNode::Calculators::CPLCalculator.new(
  liability_cents: 30_000_000,
  state: state,
  underwriter: underwriter
)

cpl_cents = cpl_calc.calculate
cpl_status = cpl_cents == 0 ? "PASS" : "FAIL"
puts "#{cpl_status}: CPL = $#{cpl_cents / 100.0} (expected: $0)"

# Test concurrent lender policy (should be $100 flat)
puts "\n=== Concurrent Lender Policy (Should be $100) ==="
lender_calc = RateNode::Calculators::LendersPolicy.new(
  loan_amount_cents: 30_000_000,
  owner_liability_cents: 35_000_000,
  concurrent: true,
  state: state,
  underwriter: underwriter
)

lender_premium = lender_calc.calculate
lender_status = lender_premium == 10_000 ? "PASS" : "FAIL"
puts "#{lender_status}: Concurrent Lender = $#{lender_premium / 100.0} (expected: $100)"

# Summary
puts "\n" + "=" * 60
puts "Test Summary"
puts "=" * 60

if all_pass
  puts "ALL FORMULA TESTS PASSED!"
  puts "2019 TX rates are correctly implemented."
else
  puts "SOME TESTS FAILED - Review the output above"
end

puts "\n=== Test Complete ==="
