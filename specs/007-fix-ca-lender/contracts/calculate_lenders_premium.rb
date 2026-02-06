# Contract: calculate_lenders_premium method signature
#
# This contract documents the expected method signature for the
# CA state calculator's lender policy premium calculation.
#
# No changes to the method signature are required - only the internal
# implementation logic changes to fix calculation bugs.

module RateNode
  module States
    class CA < BaseStateCalculator
      # Calculate lender's title insurance premium for California.
      #
      # CHANGES IN 007-fix-ca-lender:
      # - Bug Fix 1: Apply underwriter-specific multipliers to standalone policies
      #   (80% TRG / 75% ORT for Standard, 90% TRG / 85% ORT for Extended)
      # - Bug Fix 2: Use rate difference formula for concurrent Standard excess
      #   ($150 + percent × [rate(loan) - rate(owner)], not ELC lookup)
      # - Bug Fix 3: Support Extended concurrent via lender_policy_type param
      # - Bug Fix 4: Skip lender policy when is_binder_acquisition: true
      #
      # @param params [Hash] Calculation inputs
      #
      # @option params [Integer] :loan_amount_cents
      #   Loan amount in cents (required)
      #   Must be >= 0 (raises ArgumentError if negative)
      #   Returns 0 if loan_amount_cents == 0
      #
      # @option params [Integer] :owner_liability_cents
      #   Owner's policy liability for concurrent calculations (optional)
      #   Required when concurrent == true and loan > owner
      #
      # @option params [String] :underwriter
      #   Underwriter code (required)
      #   Valid values: "TRG", "ORT", "DEFAULT"
      #   Used to fetch underwriter-specific multipliers and percentages
      #
      # @option params [Date] :as_of_date
      #   Effective date for rate lookup (optional, defaults to Date.today)
      #
      # @option params [Boolean] :concurrent
      #   Whether issued concurrently with owner's policy (optional, defaults to false)
      #   When true, uses concurrent rates ($150 base for Standard, ELC for Extended)
      #   When false, uses standalone rates with underwriter multipliers
      #
      # @option params [Symbol] :lender_policy_type
      #   Coverage type (optional, defaults to :standard)
      #   Valid values: :standard, :extended
      #   Routes to different calculation logic:
      #     - Standalone Standard: 80% TRG / 75% ORT of base rate
      #     - Standalone Extended: 90% TRG / 85% ORT of base rate
      #     - Concurrent Standard: $150 flat or $150 + excess formula
      #     - Concurrent Extended: Full ELC rate lookup
      #
      # @option params [Boolean] :is_binder_acquisition
      #   Whether this is a cash acquisition (optional, defaults to false)
      #   When true, returns 0 (no lender policy on cash purchases)
      #   Takes precedence over include_lenders_policy flag
      #
      # @option params [Boolean] :include_lenders_policy
      #   Whether to include lender policy in quote (optional, defaults to true)
      #   When false, returns 0 (no lender policy requested)
      #
      # @return [Integer] Premium amount in cents
      #
      # @raise [ArgumentError] If loan_amount_cents is negative
      # @raise [ArgumentError] If underwriter is missing
      # @raise [ArgumentError] If lender_policy_type is invalid
      # @raise [ArgumentError] If concurrent && loan > owner but owner_liability_cents missing
      # @raise [StandardError] If rate lookup fails (database error, rate not found)
      #
      # @example Standalone Standard lender policy (TRG)
      #   calculate_lenders_premium(
      #     loan_amount_cents: 50_000_000,     # $500,000
      #     underwriter: "TRG",
      #     lender_policy_type: :standard
      #   )
      #   # => 125_680 (80% of $1,571 base rate = $1,256.80)
      #
      # @example Concurrent Standard with excess (TRG)
      #   calculate_lenders_premium(
      #     loan_amount_cents: 50_000_000,      # $500,000
      #     owner_liability_cents: 40_000_000,  # $400,000
      #     underwriter: "TRG",
      #     concurrent: true,
      #     lender_policy_type: :standard
      #   )
      #   # => 30_920 ($150 + 80% × ($1,571 - $1,372) = $309.20)
      #
      # @example Concurrent Extended (TRG)
      #   calculate_lenders_premium(
      #     loan_amount_cents: 50_000_000,      # $500,000
      #     owner_liability_cents: 40_000_000,  # $400,000
      #     underwriter: "TRG",
      #     concurrent: true,
      #     lender_policy_type: :extended
      #   )
      #   # => [Full ELC rate from table]
      #
      # @example Cash acquisition (no lender policy)
      #   calculate_lenders_premium(
      #     loan_amount_cents: 50_000_000,
      #     underwriter: "TRG",
      #     is_binder_acquisition: true
      #   )
      #   # => 0 (cash purchase, no lender policy)
      #
      # @example Zero loan amount
      #   calculate_lenders_premium(
      #     loan_amount_cents: 0,
      #     underwriter: "TRG"
      #   )
      #   # => 0 (no loan, no lender policy)
      #
      def calculate_lenders_premium(params)
        # Implementation in lib/ratenode/calculators/states/ca.rb
      end
    end
  end
end
