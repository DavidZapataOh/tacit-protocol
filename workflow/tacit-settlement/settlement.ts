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
