// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IReceiver} from "../../src/interfaces/IReceiver.sol";

/// @title MockKeystoneForwarder
/// @notice Simulates the KeystoneForwarder for testing CRE report delivery
contract MockKeystoneForwarder {
    /// @notice Deliver a report to a receiver contract (simulates KeystoneForwarder behavior)
    /// @param receiver The IReceiver contract to deliver to
    /// @param metadata Report metadata (workflow ID, DON ID, etc.)
    /// @param report ABI-encoded report data
    function deliverReport(address receiver, bytes calldata metadata, bytes calldata report) external {
        IReceiver(receiver).onReport(metadata, report);
    }
}
