/**
 * Frontend type definitions for Tacit.
 * Mirrors the Solidity structs from contracts/src/interfaces/IOTCVault.sol
 */

/** Trade status — mirrors IOTCVault.TradeStatus */
export enum TradeStatus {
  None = 0,
  Created = 1,
  BothDeposited = 2,
  Settled = 3,
  Refunded = 4,
  Expired = 5,
  CrossChainPending = 6,
}

/** Trade parameters to encrypt client-side before deposit */
export interface TradeParams {
  asset: string;            // Token symbol or "ETH"
  amount: string;           // Amount in token units
  wantAsset: string;        // Desired asset
  wantAmount: string;       // Desired amount
  destinationChain: number; // Chain ID for settlement destination
}

/** Deposit info (on-chain, partially encrypted) */
export interface Deposit {
  depositor: `0x${string}`;
  token: `0x${string}`;
  amount: bigint;
  encryptedParams: `0x${string}`;
  exists: boolean;
}

/** Trade info (on-chain) */
export interface Trade {
  tradeId: `0x${string}`;
  partyA: Deposit;
  partyB: Deposit;
  status: TradeStatus;
  createdAt: bigint;
  expiresAt: bigint;
}

/** Compliance attestation (on-chain, public) */
export interface Attestation {
  verified: boolean;
  exists: boolean;
  timestamp: bigint;
}
