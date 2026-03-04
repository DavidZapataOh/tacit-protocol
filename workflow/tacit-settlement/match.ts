/**
 * Tacit Settlement Workflow — Bilateral Parameter Matching
 *
 * Verifies that Party A and Party B trade parameters form a valid bilateral match:
 * - A offers X amount of asset Y and wants W amount of asset Z
 * - B offers W amount of asset Z and wants X amount of asset Y
 *
 * This verification happens INSIDE the TEE. Only the boolean result
 * (match/no-match) leaves the secure enclave boundary.
 *
 * See: Tacit Paper, Section 6 (Phase 4)
 */

import type { DecryptedTradeParams } from "./types";

export interface MatchResult {
	isMatch: boolean;
	reason?: string;
}

/**
 * Verify that two parties' trade parameters form a valid bilateral match.
 *
 * A valid match requires all four conditions:
 * 1. Party A's offered asset = Party B's wanted asset
 * 2. Party A's offered amount = Party B's wanted amount
 * 3. Party B's offered asset = Party A's wanted asset
 * 4. Party B's offered amount = Party A's wanted amount
 *
 * Asset comparison is case-insensitive (e.g., "ETH" == "eth").
 * Amount comparison is exact string equality (avoids floating-point issues).
 */
export function verifyBilateralMatch(
	paramsA: DecryptedTradeParams,
	paramsB: DecryptedTradeParams,
): MatchResult {
	// Check 1: A's offer matches B's want (asset)
	if (paramsA.asset.toUpperCase() !== paramsB.wantAsset.toUpperCase()) {
		return {
			isMatch: false,
			reason: `Asset mismatch: A offers ${paramsA.asset}, B wants ${paramsB.wantAsset}`,
		};
	}

	// Check 2: A's amount matches B's wantAmount
	if (paramsA.amount !== paramsB.wantAmount) {
		return {
			isMatch: false,
			reason: `Amount mismatch: A offers ${paramsA.amount}, B wants ${paramsB.wantAmount}`,
		};
	}

	// Check 3: B's offer matches A's want (asset)
	if (paramsB.asset.toUpperCase() !== paramsA.wantAsset.toUpperCase()) {
		return {
			isMatch: false,
			reason: `Asset mismatch: B offers ${paramsB.asset}, A wants ${paramsA.wantAsset}`,
		};
	}

	// Check 4: B's amount matches A's wantAmount
	if (paramsB.amount !== paramsA.wantAmount) {
		return {
			isMatch: false,
			reason: `Amount mismatch: B offers ${paramsB.amount}, A wants ${paramsA.wantAmount}`,
		};
	}

	// All checks passed
	return { isMatch: true };
}
