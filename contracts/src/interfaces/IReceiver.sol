// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IReceiver
/// @author Chainlink
/// @notice Interface for contracts that receive CRE workflow reports via KeystoneForwarder
/// @dev The KeystoneForwarder calls onReport() after verifying DON signatures.
///      See: https://docs.chain.link/cre/reference/sdk/evm-client-ts
interface IReceiver {
    /// @notice Called by the KeystoneForwarder when a CRE workflow report is delivered
    /// @param metadata Metadata about the report (workflow ID, DON ID, etc.)
    /// @param report The ABI-encoded report data from the CRE workflow
    function onReport(bytes calldata metadata, bytes calldata report) external;
}
