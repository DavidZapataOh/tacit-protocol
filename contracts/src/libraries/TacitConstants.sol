// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title TacitConstants
/// @author Tacit Protocol
/// @notice Shared constants used across Tacit contracts
library TacitConstants {
    /// @notice Default trade expiration duration (24 hours)
    /// @dev Party A can claim refund after this period if Party B hasn't deposited
    uint256 constant DEFAULT_TRADE_EXPIRY = 24 hours;

    /// @notice Minimum trade expiration duration (1 hour)
    uint256 constant MIN_TRADE_EXPIRY = 1 hours;

    /// @notice Maximum trade expiration duration (7 days)
    uint256 constant MAX_TRADE_EXPIRY = 7 days;

    /// @notice Report type identifier for settlement reports
    bytes32 constant REPORT_TYPE_SETTLEMENT = keccak256("SETTLEMENT");

    /// @notice Report type identifier for refund reports
    bytes32 constant REPORT_TYPE_REFUND = keccak256("REFUND");

    /// @notice Report type identifier for attestation reports
    bytes32 constant REPORT_TYPE_ATTESTATION = keccak256("ATTESTATION");

    /// @notice Timeout for cross-chain settlement via CCIP (24 hours)
    /// @dev After this period, a CrossChainPending trade can be refunded.
    ///      Set to 24h to prevent double-spend from premature timeout during CCIP congestion.
    uint256 constant CROSS_CHAIN_TIMEOUT = 24 hours;

    /// @notice Default gas limit for CCIP messages (data-only, no token transfer)
    uint256 constant CCIP_GAS_LIMIT = 200_000;

    /// @notice Gas limit for CCIP messages with token transfers
    uint256 constant CCIP_GAS_LIMIT_WITH_TOKENS = 300_000;
}
