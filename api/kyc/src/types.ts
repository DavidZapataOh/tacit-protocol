/**
 * KYC verification levels.
 * In production these would map to actual accreditation tiers.
 */
export type KYCLevel = "none" | "basic" | "accredited" | "institutional";

/**
 * Request body for POST /kyc/verify
 * Sent by the CRE workflow via Confidential HTTP
 */
export interface KYCVerifyRequest {
  /** Array of Ethereum addresses to verify */
  addresses: string[];
  /** Minimum required verification level. Default: "basic" */
  requiredLevel?: KYCLevel;
}

/**
 * Individual address verification result
 */
export interface AddressKYCResult {
  /** The Ethereum address that was verified */
  address: string;
  /** Whether this address meets the required KYC level */
  verified: boolean;
  /** Current KYC verification level */
  level: KYCLevel;
  /** When the KYC was last verified (ISO 8601) */
  verifiedAt?: string;
  /** Expiration date of the verification (ISO 8601) */
  expiresAt?: string;
}

/**
 * Response body for POST /kyc/verify
 * Only the `allVerified` boolean should cross the TEE boundary
 */
export interface KYCVerifyResponse {
  /** True if ALL addresses meet the required KYC level */
  allVerified: boolean;
  /** Per-address verification results */
  results: AddressKYCResult[];
  /** ISO 8601 timestamp of the verification check */
  timestamp: string;
  /** The required level that was checked against */
  requiredLevel: KYCLevel;
}

/**
 * Error response
 */
export interface ErrorResponse {
  error: string;
  code: string;
}

/**
 * KYC record stored in KV
 */
export interface KYCRecord {
  level: KYCLevel;
  verifiedAt: string;
  expiresAt: string;
  entity?: string;
}

/**
 * Cloudflare Worker environment bindings
 */
export interface Env {
  KYC_KV: KVNamespace;
  KYC_API_KEY: string;
  ENVIRONMENT: string;
}
