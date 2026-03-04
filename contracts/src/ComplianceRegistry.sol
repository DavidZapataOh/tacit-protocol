// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IComplianceRegistry} from "./interfaces/IComplianceRegistry.sol";
import {IReceiver} from "./interfaces/IReceiver.sol";

/// @title ComplianceRegistry
/// @author Tacit Protocol
/// @notice Stores compliance attestations for OTC trades.
///         Each attestation records ONLY: trade ID, pass/fail result, and timestamp.
///         NEVER stores PII, amounts, asset types, or counterparty addresses.
/// @dev Receives attestation reports from the CRE workflow via KeystoneForwarder.
///      Attestations are immutable once recorded — they cannot be modified or deleted.
///      This is the public verifiability layer: anyone can confirm a trade was compliance-checked.
contract ComplianceRegistry is IComplianceRegistry, IReceiver, Ownable2Step {
    // ============ State Variables ============

    /// @notice The KeystoneForwarder address authorized to deliver CRE reports
    address public immutable KEYSTONE_FORWARDER;

    /// @notice Mapping from trade ID to compliance attestation
    mapping(bytes32 => Attestation) private _attestations;

    /// @notice Array of all trade IDs with attestations (for enumeration)
    bytes32[] private _attestedTradeIds;

    /// @notice Total count of attestations recorded
    uint256 private _attestationCount;

    // ============ Constructor ============

    /// @notice Initialize the ComplianceRegistry
    /// @param keystoneForwarder Address of the KeystoneForwarder contract
    /// @param initialOwner Address of the contract owner
    constructor(address keystoneForwarder, address initialOwner) Ownable(initialOwner) {
        if (keystoneForwarder == address(0)) revert OnlyForwarder();
        KEYSTONE_FORWARDER = keystoneForwarder;
    }

    // ============ External Functions — IReceiver ============

    /// @inheritdoc IReceiver
    /// @notice Record a compliance attestation from the CRE workflow
    /// @dev Called by KeystoneForwarder after verifying DON signatures.
    ///      Decodes report as (bytes32 tradeId, bool result, uint256 timestamp).
    ///      Each trade can only have ONE attestation (immutable).
    function onReport(bytes calldata metadata, bytes calldata report) external override {
        // CHECKS
        if (msg.sender != KEYSTONE_FORWARDER) revert OnlyForwarder();
        (metadata); // metadata contains workflow/DON IDs — not validated for hackathon scope

        // Decode the attestation report
        (bytes32 tradeId, bool result, uint256 timestamp) = abi.decode(report, (bytes32, bool, uint256));

        // Check if attestation already exists
        if (_attestations[tradeId].exists) revert AttestationAlreadyExists(tradeId);

        // EFFECTS
        _attestations[tradeId] = Attestation({verified: result, exists: true, timestamp: timestamp});

        _attestedTradeIds.push(tradeId);

        unchecked {
            ++_attestationCount;
        }

        emit ComplianceVerified(tradeId, result, timestamp);

        // INTERACTIONS: none
    }

    // ============ External Functions — View ============

    /// @inheritdoc IComplianceRegistry
    function getAttestation(bytes32 tradeId) external view returns (Attestation memory attestation) {
        attestation = _attestations[tradeId];
        if (!attestation.exists) revert AttestationNotFound(tradeId);
    }

    /// @inheritdoc IComplianceRegistry
    function hasAttestation(bytes32 tradeId) external view returns (bool exists) {
        exists = _attestations[tradeId].exists;
    }

    /// @inheritdoc IComplianceRegistry
    function attestationCount() external view returns (uint256 count) {
        count = _attestationCount;
    }

    /// @notice Get a paginated list of attested trade IDs
    /// @dev Used by the Attestation Explorer frontend page to list all attestations
    /// @param offset Starting index
    /// @param limit Maximum number of IDs to return
    /// @return tradeIds Array of trade IDs
    function getAttestedTradeIds(uint256 offset, uint256 limit) external view returns (bytes32[] memory tradeIds) {
        uint256 total = _attestedTradeIds.length;
        if (offset >= total) {
            return new bytes32[](0);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        uint256 length = end - offset;
        tradeIds = new bytes32[](length);
        for (uint256 i = 0; i < length;) {
            tradeIds[i] = _attestedTradeIds[offset + i];
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Get multiple attestations in a single call
    /// @dev Batch query for the Attestation Explorer frontend
    /// @param tradeIds Array of trade IDs to query
    /// @return attestations Array of attestation structs
    function getAttestationsBatch(bytes32[] calldata tradeIds)
        external
        view
        returns (Attestation[] memory attestations)
    {
        attestations = new Attestation[](tradeIds.length);
        uint256 length = tradeIds.length;
        for (uint256 i = 0; i < length;) {
            attestations[i] = _attestations[tradeIds[i]];
            unchecked {
                ++i;
            }
        }
    }
}
