/**
 * Tacit Settlement Workflow — Report Encoding for On-Chain Writes
 *
 * Encodes ABI parameters for the report-based write pattern:
 *   workflow encodes data → runtime.report() signs → evmClient.writeReport()
 *   → KeystoneForwarder verifies → contract.onReport(metadata, rawReport)
 *
 * OTCVault.onReport() decodes: (bytes32 tradeId, uint8 action, string reason)
 * ComplianceRegistry.onReport() decodes: (bytes32 tradeId, bool result, uint256 timestamp)
 *
 * See: Tacit Paper, Section 6 (Phases 6-8)
 */

import { encodeAbiParameters } from "viem";

// ---------------------------------------------------------------------------
// Report action enum — mirrors OTCVault.ReportAction in Solidity
// ---------------------------------------------------------------------------

export enum ReportAction {
	Settle = 0,
	Refund = 1,
	CrossChainSettle = 2,
}

// ---------------------------------------------------------------------------
// IReceiver ABI — shared by OTCVault and ComplianceRegistry
// ---------------------------------------------------------------------------

export const IRECEIVER_ABI = [
	{
		type: "function" as const,
		name: "onReport" as const,
		inputs: [
			{ name: "metadata", type: "bytes" as const },
			{ name: "rawReport", type: "bytes" as const },
		],
		outputs: [],
		stateMutability: "nonpayable" as const,
	},
] as const;

// ---------------------------------------------------------------------------
// OTCVault report encoding
// ---------------------------------------------------------------------------

/**
 * Encode settlement/refund report payload for OTCVault.onReport().
 *
 * The OTCVault contract decodes this as:
 *   abi.decode(report, (bytes32, uint8, string))
 *
 * @param tradeId - bytes32 trade identifier
 * @param action - Settle (0) or Refund (1)
 * @param reason - Refund reason (empty string for settlement)
 */
export function encodeSettlementReport(
	tradeId: `0x${string}`,
	action: ReportAction,
	reason: string,
): `0x${string}` {
	return encodeAbiParameters(
		[{ type: "bytes32" }, { type: "uint8" }, { type: "string" }],
		[tradeId, action, reason],
	);
}

// ---------------------------------------------------------------------------
// ComplianceRegistry report encoding
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Cross-chain settlement encoding
// ---------------------------------------------------------------------------

/**
 * Encode settlement instruction for the CCIP receiver.
 * Matches SettlementEncoder.SettlementInstruction in Solidity:
 *   abi.encode(bytes32 tradeId, address recipient, address token, uint256 amount)
 *
 * @param tradeId - bytes32 trade identifier
 * @param recipient - address to receive assets on destination chain
 * @param token - token address (0x0 for native ETH)
 * @param amount - amount to transfer (in wei)
 */
export function encodeSettlementInstruction(
	tradeId: `0x${string}`,
	recipient: `0x${string}`,
	token: `0x${string}`,
	amount: bigint,
): `0x${string}` {
	return encodeAbiParameters(
		[{ type: "bytes32" }, { type: "address" }, { type: "address" }, { type: "uint256" }],
		[tradeId, recipient, token, amount],
	);
}

/**
 * Encode cross-chain settlement report for OTCVault.onReport().
 *
 * The OTCVault decodes this as:
 *   abi.decode(report, (bytes32, uint8, bytes))
 * For action=2 (CrossChainSettle), the bytes data is:
 *   abi.decode(data, (uint64, bytes))  → (destChainSelector, settlementPayload)
 *
 * @param tradeId - bytes32 trade identifier
 * @param destChainSelector - CCIP chain selector for destination chain
 * @param settlementPayload - ABI-encoded SettlementInstruction for the receiver
 */
export function encodeCrossChainReport(
	tradeId: `0x${string}`,
	destChainSelector: bigint,
	settlementPayload: `0x${string}`,
): `0x${string}` {
	// Inner encoding: (uint64 destChainSelector, bytes settlementData)
	const crossChainData = encodeAbiParameters(
		[{ type: "uint64" }, { type: "bytes" }],
		[destChainSelector, settlementPayload],
	);

	// Outer encoding: (bytes32 tradeId, uint8 action=2, bytes crossChainData)
	return encodeAbiParameters(
		[{ type: "bytes32" }, { type: "uint8" }, { type: "bytes" }],
		[tradeId, ReportAction.CrossChainSettle, crossChainData],
	);
}

// ---------------------------------------------------------------------------
// ComplianceRegistry report encoding
// ---------------------------------------------------------------------------

/**
 * Encode compliance attestation payload for ComplianceRegistry.onReport().
 *
 * The ComplianceRegistry contract decodes this as:
 *   abi.decode(report, (bytes32, bool, uint256))
 *
 * Privacy: attestation contains ONLY tradeId + pass/fail + timestamp.
 * NEVER includes amounts, assets, or counterparty addresses.
 *
 * @param tradeId - bytes32 trade identifier
 * @param result - true = compliance passed, false = failed
 * @param timestamp - Unix timestamp of verification
 */
export function encodeAttestationReport(
	tradeId: `0x${string}`,
	result: boolean,
	timestamp: number,
): `0x${string}` {
	return encodeAbiParameters(
		[{ type: "bytes32" }, { type: "bool" }, { type: "uint256" }],
		[tradeId, result, BigInt(timestamp)],
	);
}
