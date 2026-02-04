# frozen_string_literal: true

# Contract: StateCalculatorFactory
#
# This file defines the factory interface for obtaining state calculators.
# It is a DESIGN ARTIFACT - the actual implementation will be placed in:
#   lib/ratenode/calculators/state_calculator_factory.rb
#
# Branch: 001-extract-state-calculators
# Date: 2026-02-03

module RateNode
  # Error raised when requesting a calculator for an unsupported state.
  class UnsupportedStateError < StandardError; end

  # Factory for obtaining state-specific rate calculators.
  #
  # Returns cached singleton instances per state code. Calculators are stateless,
  # so the same instance can be reused across all calculations for that state.
  #
  # @example Basic usage
  #   calculator = StateCalculatorFactory.for("AZ")
  #   premium = calculator.calculate_owners_premium(params)
  #
  # @example Case-insensitive lookup
  #   StateCalculatorFactory.for("az")  # Returns same instance as "AZ"
  #
  class StateCalculatorFactory
    # Supported state codes
    SUPPORTED_STATES = %w[AZ FL CA TX NC].freeze

    class << self
      # Get the calculator instance for a given state.
      #
      # @param state_code [String] Two-letter state code (case-insensitive)
      # @return [BaseStateCalculator] The state-specific calculator instance
      # @raise [UnsupportedStateError] If state code is not supported
      #
      # @example
      #   StateCalculatorFactory.for("AZ")  # => #<RateNode::States::AZ:0x...>
      #   StateCalculatorFactory.for("XX")  # => raises UnsupportedStateError
      #
      def for(state_code)
        normalized = normalize_state_code(state_code)
        calculators[normalized] ||= build_calculator(normalized)
      end

      # Clear the calculator cache.
      # Primarily used for testing to ensure fresh instances.
      #
      # @return [void]
      #
      def reset!
        @calculators = {}
      end

      # Check if a state code is supported.
      #
      # @param state_code [String] Two-letter state code
      # @return [Boolean] True if state has a calculator
      #
      def supported?(state_code)
        SUPPORTED_STATES.include?(normalize_state_code(state_code))
      end

      private

      def calculators
        @calculators ||= {}
      end

      def normalize_state_code(code)
        code.to_s.strip.upcase
      end

      def build_calculator(state)
        case state
        when "AZ" then States::AZ.new
        when "FL" then States::FL.new
        when "CA" then States::CA.new
        when "TX" then States::TX.new
        when "NC" then States::NC.new
        else
          raise UnsupportedStateError, "No calculator registered for state: #{state}"
        end
      end
    end
  end
end
