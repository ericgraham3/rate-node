# frozen_string_literal: true

require "date"

module TitleRound
  module Calculators
    class EndorsementCalculator
      attr_reader :endorsement_codes, :liability_cents, :concurrent, :state, :underwriter, :as_of_date

      def initialize(endorsement_codes:, liability_cents:, concurrent: false, state:, underwriter:, as_of_date: Date.today)
        @endorsement_codes = Array(endorsement_codes)
        @liability_cents = liability_cents
        @concurrent = concurrent
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
      end

      def calculate
        endorsement_codes.map do |code|
          endorsement = Models::Endorsement.find_by_code(code, state: state, underwriter: underwriter, as_of_date: as_of_date)
          next nil unless endorsement

          {
            code: endorsement.code,
            name: endorsement.name,
            amount_cents: endorsement.calculate_premium(liability_cents, concurrent: concurrent, state: state, underwriter: underwriter, as_of_date: as_of_date)
          }
        end.compact
      end

      def total_cents
        calculate.sum { |e| e[:amount_cents] }
      end
    end
  end
end
