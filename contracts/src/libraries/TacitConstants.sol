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
}
