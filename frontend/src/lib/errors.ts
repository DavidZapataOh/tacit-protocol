/**
 * Parses wagmi/viem contract errors into user-friendly messages.
 */
export function parseContractError(error: Error): string {
  const message = error.message;

  // User rejected transaction
  if (
    message.includes("User rejected") ||
    message.includes("user rejected") ||
    message.includes("ACTION_REJECTED")
  ) {
    return "Transaction rejected. You cancelled the transaction in your wallet.";
  }

  // Insufficient funds
  if (
    message.includes("insufficient funds") ||
    message.includes("InsufficientBalance")
  ) {
    return "Insufficient balance. You need more ETH for the deposit and gas fees.";
  }

  // Trade not found
  if (message.includes("TradeNotFound")) {
    return "Trade not found. The matching code may be incorrect.";
  }

  // Cannot match own trade
  if (message.includes("CannotMatchOwnTrade")) {
    return "You cannot match your own trade. Use a different wallet.";
  }

  // Trade already matched
  if (message.includes("TradeAlreadyMatched")) {
    return "This trade has already been matched by another party.";
  }

  // Invalid trade status
  if (message.includes("InvalidTradeStatus")) {
    return "This trade is not in a valid state for this action.";
  }

  // Zero amount
  if (message.includes("ZeroAmount")) {
    return "Deposit amount must be greater than zero.";
  }

  // Unauthorized
  if (message.includes("Unauthorized") || message.includes("OnlyForwarder")) {
    return "Unauthorized. This action can only be performed by the system.";
  }

  // Network error
  if (message.includes("network") || message.includes("timeout")) {
    return "Network error. Please check your connection and try again.";
  }

  // Generic fallback — truncate long messages
  return `Transaction failed: ${message.slice(0, 150)}`;
}
