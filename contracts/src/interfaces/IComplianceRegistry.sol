// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IComplianceRegistry
/// @author Tacit Protocol
/// @notice Interface for the compliance attestation registry
/// @dev Stores ONLY attestations (trade ID, pass/fail, timestamp). NEVER stores PII, amounts, or asset types.
interface IComplianceRegistry {
    // ============ Structs ============

    /// @notice A compliance attestation for a trade
    /// @dev Packed into 1 slot: verified (1 byte) + exists (1 byte) + timestamp (6 bytes) = 8 bytes
    struct Attestation {
        bool verified; // Whether compliance verification passed (1 byte)
        bool exists; // Whether an attestation exists for this trade (1 byte)
        uint48 timestamp; // When the compliance check was performed (6 bytes, good until year 8.9M)
    }

    // ============ Events ============

    /// @notice Emitted when a compliance attestation is recorded
    /// @param tradeId The unique trade identifier
    /// @param result Whether compliance passed (true) or failed (false)
    /// @param timestamp When the check was performed
    event ComplianceVerified(bytes32 indexed tradeId, bool result, uint256 timestamp);

    // ============ Errors ============

    /// @notice Thrown when caller is not the KeystoneForwarder
    error OnlyForwarder();

    /// @notice Thrown when an attestation already exists for this trade
    error AttestationAlreadyExists(bytes32 tradeId);

    /// @notice Thrown when querying an attestation that does not exist
    error AttestationNotFound(bytes32 tradeId);

    // ============ External Functions ============

    /// @notice Get the compliance attestation for a trade
    /// @param tradeId The trade ID to query
    /// @return attestation The attestation struct
    function getAttestation(bytes32 tradeId) external view returns (Attestation memory attestation);

    /// @notice Check if a trade has a compliance attestation
    /// @param tradeId The trade ID to check
    /// @return exists Whether an attestation exists
    function hasAttestation(bytes32 tradeId) external view returns (bool exists);

    /// @notice Get the total number of attestations recorded
    /// @return count The number of attestations
    function attestationCount() external view returns (uint256 count);
}
