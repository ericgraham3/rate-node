# frozen_string_literal: true

require_relative "title_round/database"
require_relative "title_round/models/rate_tier"
require_relative "title_round/models/refinance_rate"
require_relative "title_round/models/endorsement"
require_relative "title_round/models/policy_type"
require_relative "title_round/models/cpl_rate"
require_relative "title_round/calculators/base_rate"
require_relative "title_round/calculators/owners_policy"
require_relative "title_round/calculators/lenders_policy"
require_relative "title_round/calculators/refinance"
require_relative "title_round/calculators/endorsement_calculator"
require_relative "title_round/calculators/cpl_calculator"
require_relative "title_round/calculator"
require_relative "title_round/output/closing_disclosure"
require_relative "title_round/cli"

module TitleRound
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
      TitleRound::Seeds::Rates.seed_all
    end
  end
end
