// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SettlementEncoder
/// @author Tacit Protocol
/// @notice Shared encoding/decoding for cross-chain settlement instructions.
///         Used by OTCVault (sender) and OTCVaultReceiver (receiver) to ensure
///         consistent ABI encoding across chains.
library SettlementEncoder {
    /// @notice Cross-chain settlement instruction sent via CCIP
    /// @param tradeId The unique trade identifier (bytes32, same as OTCVault)
    /// @param recipient The address to receive assets on the destination chain
    /// @param token The token to transfer (address(0) for native ETH)
    /// @param amount The amount to transfer
    struct SettlementInstruction {
        bytes32 tradeId;
        address recipient;
        address token;
        uint256 amount;
    }

    /// @notice Encode settlement instruction for CCIP message data
    /// @param instruction The settlement instruction to encode
    /// @return The ABI-encoded bytes
    function encode(SettlementInstruction memory instruction) internal pure returns (bytes memory) {
        return abi.encode(instruction.tradeId, instruction.recipient, instruction.token, instruction.amount);
    }

    /// @notice Decode settlement instruction from CCIP message data
    /// @param data The ABI-encoded bytes from a CCIP message
    /// @return instruction The decoded settlement instruction
    function decode(bytes memory data) internal pure returns (SettlementInstruction memory instruction) {
        (instruction.tradeId, instruction.recipient, instruction.token, instruction.amount) =
            abi.decode(data, (bytes32, address, address, uint256));
    }
}
