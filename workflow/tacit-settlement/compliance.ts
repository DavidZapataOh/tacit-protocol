/**
 * Tacit Settlement Workflow — Compliance Check Types & Decision Logic
 *
 * Types matching the Sanctions API and KYC API response schemas.
 * Decision aggregator for determining settle vs refund.
 *
 * Privacy boundary:
 * - API responses are parsed INSIDE the TEE
 * - Only boolean pass/fail results cross the TEE boundary
 * - API keys are injected by Vault DON via {{.SECRET}} templates
 *
 * See: Tacit Paper, Section 5.3.2 (Confidential HTTP)
 */

import type { ComplianceResult } from "./types";

// ---------------------------------------------------------------------------
// Sanctions API response types (matches api/sanctions/src/types.ts)
// ---------------------------------------------------------------------------

export interface SanctionsApiResponse {
	allClear: boolean;
	results: {
		address: string;
		sanctioned: boolean;
		source: string | null;
	}[];
	timestamp: string;
	list: string;
}

// ---------------------------------------------------------------------------
// KYC API response types (matches api/kyc/src/types.ts)
// ---------------------------------------------------------------------------

export interface KycApiResponse {
	allVerified: boolean;
	results: {
		address: string;
		verified: boolean;
		level: string;
		meetsRequired: boolean;
	}[];
	timestamp: string;
	requiredLevel: string;
}

// ---------------------------------------------------------------------------
// Response parsing (body is Uint8Array from ConfidentialHTTPClient)
// ---------------------------------------------------------------------------

/** Parse Uint8Array response body to JSON */
export function parseResponseBody<T>(body: Uint8Array): T {
	const text = new TextDecoder().decode(body);
	return JSON.parse(text) as T;
}

// ---------------------------------------------------------------------------
// Compliance decision aggregator
// ---------------------------------------------------------------------------

/**
 * Aggregate sanctions and KYC results into a single compliance decision.
 *
 * Both checks must pass for settlement to proceed.
 * Any failure triggers a refund for all parties.
 */
export function makeComplianceDecision(
	sanctionsAllClear: boolean,
	kycAllVerified: boolean,
): ComplianceResult {
	return {
		sanctionsPass: sanctionsAllClear,
		kycPass: kycAllVerified,
		timestamp: Math.floor(Date.now() / 1000),
	};
}
