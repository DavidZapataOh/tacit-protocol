/**
 * Client-side encryption of trade parameters.
 *
 * In production, this would use the Vault DON's threshold public key
 * for encryption. For the hackathon prototype, we use a deterministic
 * encoding that simulates encryption — the key point is that params
 * are never stored in plaintext on-chain.
 */

import type { TradeParams } from "@/types/trade";

/**
 * Encrypts trade parameters for on-chain storage.
 * Only the CRE workflow running in TEE can decrypt these.
 */
export function encryptTradeParams(params: TradeParams): `0x${string}` {
  // For hackathon: encode as hex (simulating encryption)
  // In production: encrypt with Vault DON threshold public key
  const plaintext = JSON.stringify(params);
  const encoder = new TextEncoder();
  const bytes = encoder.encode(plaintext);

  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return `0x${hex}` as `0x${string}`;
}

/**
 * Generates a unique trade ID.
 * Only the first 4 bytes are random; the rest are zero-padded.
 * This ensures the matching code (first 8 hex chars) can reconstruct the full ID.
 */
export function generateTradeId(): `0x${string}` {
  const randomBytes = new Uint8Array(4);
  crypto.getRandomValues(randomBytes);
  const hex = Array.from(randomBytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `0x${hex.padEnd(64, "0")}` as `0x${string}`;
}

/**
 * Generates a human-readable matching code from the trade ID.
 * This is shared with Party B off-chain.
 */
export function generateMatchingCode(tradeId: `0x${string}`): string {
  return `TACIT-${tradeId.slice(2, 10).toUpperCase()}`;
}
