/**
 * Shared type definitions for the Tacit CRE workflow.
 * These types mirror the Solidity structs and enums in contracts/src/interfaces/.
 */

/** Trade status enum — mirrors IOTCVault.TradeStatus */
export enum TradeStatus {
  None = 0,
  Created = 1,
  BothDeposited = 2,
  Settled = 3,
  Refunded = 4,
  Expired = 5,
}

/** Decrypted trade parameters (only visible inside TEE) */
export interface DecryptedTradeParams {
  asset: string;            // Token symbol or "ETH"
  amount: string;           // Amount in token units (e.g., "10.0")
  wantAsset: string;        // Desired asset symbol
  wantAmount: string;       // Desired amount
  destinationChain: number; // Chain ID for settlement destination
}

/** Compliance check result */
export interface ComplianceResult {
  sanctionsPass: boolean;   // OFAC SDN screening passed
  kycPass: boolean;         // KYC/accreditation verified
  timestamp: number;        // Unix timestamp of verification
}

/** Settlement instruction computed by TEE */
export interface SettlementInstruction {
  tradeId: string;          // bytes32 hex
  partyA: string;           // address hex
  partyB: string;           // address hex
  settle: boolean;          // true = settle, false = refund
  compliancePassed: boolean;
}

/** Attestation data to write on-chain */
export interface AttestationData {
  tradeId: string;          // bytes32 hex
  result: boolean;          // compliance pass/fail
  timestamp: number;        // Unix timestamp
}

/** Report types — mirrors TacitConstants.REPORT_TYPE_* */
export const REPORT_TYPES = {
  SETTLEMENT: "SETTLEMENT",
  REFUND: "REFUND",
  ATTESTATION: "ATTESTATION",
} as const;

/** Chain configuration */
export const CHAIN_CONFIG = {
  sepolia: {
    chainId: 11155111,
    chainSelectorName: "ethereum-testnet-sepolia",
  },
  arbitrumSepolia: {
    chainId: 421614,
    chainSelectorName: "ethereum-testnet-sepolia-arbitrum-1",
  },
} as const;
