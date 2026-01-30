# frozen_string_literal: true

require_relative "ratenode/state_rules"
require_relative "ratenode/database"
require_relative "ratenode/models/rate_tier"
require_relative "ratenode/models/refinance_rate"
require_relative "ratenode/models/endorsement"
require_relative "ratenode/models/policy_type"
require_relative "ratenode/models/cpl_rate"
require_relative "ratenode/calculators/base_rate"
require_relative "ratenode/calculators/owners_policy"
require_relative "ratenode/calculators/lenders_policy"
require_relative "ratenode/calculators/refinance"
require_relative "ratenode/calculators/endorsement_calculator"
require_relative "ratenode/calculators/cpl_calculator"
require_relative "ratenode/calculators/az_calculator"
require_relative "ratenode/calculator"
require_relative "ratenode/output/closing_disclosure"
require_relative "ratenode/cli"

module RateNode
  class Error < StandardError; end

  class << self
    def calculate(params)
      Calculator.new(params).calculate
    rescue ArgumentError => e
      raise Error, e.message
    end

    def db
      Database.instance
    end

    def setup_database(path = nil)
      Database.setup(path)
      seed_database
    end

    def seed_database
      require_relative "../db/seeds/rates"
      RateNode::Seeds::Rates.seed_all
    end
  end
end
