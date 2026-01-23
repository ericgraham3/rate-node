# frozen_string_literal: true

require_relative "../lib/ratenode"

RSpec.configure do |config|
  # Better error output
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Focus on tagged examples when debugging
  config.filter_run_when_matching :focus

  # Track test results
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Cleaner output
  config.disable_monkey_patching!

  # Randomize test order
  config.order = :random
  Kernel.srand config.seed

  # Setup in-memory database with all seeds before running tests
  config.before(:suite) do
    RateNode.setup_database(":memory:")
  end

  # Better failure output formatting
  config.formatter = :documentation if config.files_to_run.one?
end
