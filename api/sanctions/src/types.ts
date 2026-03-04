/**
 * Request body for POST /sanctions/check
 * Sent by the CRE workflow via Confidential HTTP
 */
export interface SanctionsCheckRequest {
  /** Array of Ethereum addresses to screen (checksummed or lowercase) */
  addresses: string[];
  /** Which sanctions list to check against. Default: OFAC_SDN */
  list?: "OFAC_SDN" | "OFAC_SDN_EXTENDED";
}

/**
 * Individual address screening result
 */
export interface AddressResult {
  /** The Ethereum address that was screened */
  address: string;
  /** Whether this address appears on the sanctions list */
  sanctioned: boolean;
  /** Source of the match (e.g., "OFAC_SDN", "TORNADO_CASH") */
  source?: string;
}

/**
 * Response body for POST /sanctions/check
 * Only the `allClear` boolean should cross the TEE boundary
 */
export interface SanctionsCheckResponse {
  /** True if ALL addresses are clear (not sanctioned) */
  allClear: boolean;
  /** Per-address results */
  results: AddressResult[];
  /** ISO 8601 timestamp of the check */
  timestamp: string;
  /** Which list was checked */
  list: string;
}

/**
 * Error response
 */
export interface ErrorResponse {
  error: string;
  code: string;
}

/**
 * Cloudflare Worker environment bindings
 */
export interface Env {
  SANCTIONS_KV: KVNamespace;
  SANCTIONS_API_KEY: string;
  ENVIRONMENT: string;
}
