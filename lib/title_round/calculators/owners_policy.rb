# frozen_string_literal: true

require "date"

module TitleRound
  module Calculators
    class OwnersPolicy
      attr_reader :liability_cents, :policy_type, :state, :underwriter, :as_of_date

      def initialize(liability_cents:, policy_type: :standard, state:, underwriter:, as_of_date: Date.today)
        @liability_cents = liability_cents
        @policy_type = policy_type.to_sym
        @state = state
        @underwriter = underwriter
        @as_of_date = as_of_date
      end

      def calculate
        base_rate = BaseRate.new(liability_cents, state: state, underwriter: underwriter, as_of_date: as_of_date).calculate
        multiplier = Models::PolicyType.multiplier_for(policy_type, state: state, underwriter: underwriter, as_of_date: as_of_date)
        (base_rate * multiplier).round
      end

      def policy_type_label
        case policy_type
        when :standard then "Standard"
        when :homeowner then "Homeowner's"
        when :extended then "Extended"
        else policy_type.to_s.capitalize
        end
      end

      def line_item
        "Owner's Title Insurance (#{policy_type_label})"
      end
    end
  end
end
