# frozen_string_literal: true

module RateNode
  # Abstract base class defining the contract for state-specific rate calculators.
  #
  # All state calculators (States::AZ, States::FL, etc.) MUST inherit from this class
  # and implement the required methods. Calculators are stateless singletons - all
  # calculation state is passed via the params hash.
  #
  # @example Usage via factory
  #   calculator = StateCalculatorFactory.for("AZ")
  #   premium = calculator.calculate_owners_premium(
  #     liability_cents: 50_000_000,
  #     policy_type: "standard",
  #     underwriter: "TRG",
  #     # ... other params
  #   )
  #
  class BaseStateCalculator
    # Calculate owner's title insurance premium.
    #
    # @param params [Hash] Calculation inputs
    # @option params [Integer] :liability_cents Policy liability amount in cents (required)
    # @option params [String] :policy_type "standard", "homeowners", or "extended" (required)
    # @option params [String] :underwriter Underwriter code, e.g., "TRG", "ORT" (required)
    # @option params [String] :transaction_type "purchase" or "refinance" (required)
    # @option params [Date] :as_of_date Effective date for rate lookup (required)
    # @option params [Integer] :prior_policy_amount_cents Prior policy amount for reissue (optional)
    # @option params [Date] :prior_policy_date Prior policy date for eligibility check (optional)
    # @option params [String] :county County name for geographic lookups (optional, AZ)
    # @option params [Boolean] :is_hold_open Whether this is a hold-open transaction (optional, AZ)
    # @option params [String] :hold_open_phase "initial" or "final" for hold-open (optional, AZ)
    #
    # @return [Integer] Premium amount in cents
    # @raise [NotImplementedError] If called on base class directly
    #
    def calculate_owners_premium(params)
      raise NotImplementedError, "#{self.class.name} must implement #calculate_owners_premium"
    end

    # Calculate lender's title insurance premium.
    #
    # @param params [Hash] Calculation inputs
    # @option params [Integer] :loan_amount_cents Loan amount in cents (required)
    # @option params [Integer] :owner_liability_cents Owner's policy liability for concurrent (optional)
    # @option params [String] :underwriter Underwriter code (required)
    # @option params [Date] :as_of_date Effective date for rate lookup (required)
    # @option params [Boolean] :concurrent Whether issued concurrently with owner's policy (optional)
    #
    # @return [Integer] Premium amount in cents
    # @raise [NotImplementedError] If called on base class directly
    #
    def calculate_lenders_premium(params)
      raise NotImplementedError, "#{self.class.name} must implement #calculate_lenders_premium"
    end

    protected

    # Access to shared rounding utilities.
    # State calculators should use these rather than implementing their own rounding.
    #
    # @return [Module] Utilities::Rounding module
    #
    def rounding
      Utilities::Rounding
    end

    # Access to shared tier lookup utilities.
    # State calculators should use these for tiered rate traversal.
    #
    # @return [Module] Utilities::TierLookup module
    #
    def tier_lookup
      Utilities::TierLookup
    end

    # Access to state-specific rules configuration.
    #
    # @param state [String] Two-letter state code
    # @param underwriter [String] Underwriter code (optional)
    # @return [Hash] State rules from STATE_RULES constant
    #
    def rules_for(state, underwriter: nil)
      RateNode.rules_for(state, underwriter: underwriter)
    end
  end
end
