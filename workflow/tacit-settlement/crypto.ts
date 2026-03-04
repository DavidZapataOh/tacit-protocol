/**
 * Tacit Settlement Workflow — Cryptographic Utilities (WASM-safe)
 *
 * Decrypts trade parameters inside the TEE.
 *
 * WASM constraints: No Buffer, no Node.js crypto module.
 * Uses Uint8Array + TextDecoder only.
 *
 * Two decryption modes:
 * 1. Hex-encoded JSON — simplest, for simulation/demo
 *    Frontend does: toHex(JSON.stringify(params))
 *    TEE does:      JSON.parse(hexToString(bytes))
 *
 * 2. XOR cipher with Vault DON key — lightweight "encryption" for demo
 *    Frontend does: toHex(xor(JSON.stringify(params), key))
 *    TEE does:      JSON.parse(xor(hexToBytes(bytes), key))
 *
 * In production: this would use threshold decryption via DKG protocol,
 * where the TEE requests K-of-N key shares from Vault DON nodes.
 */

import type { DecryptedTradeParams } from "./types";

// ---------------------------------------------------------------------------
// Hex utilities (WASM-safe — no Buffer)
// ---------------------------------------------------------------------------

/** Convert a hex string (with or without 0x prefix) to Uint8Array */
function hexToBytes(hex: string): Uint8Array {
	const h = hex.startsWith("0x") ? hex.slice(2) : hex;
	const bytes = new Uint8Array(h.length / 2);
	for (let i = 0; i < bytes.length; i++) {
		bytes[i] = parseInt(h.substring(i * 2, i * 2 + 2), 16);
	}
	return bytes;
}

/** Convert Uint8Array to UTF-8 string */
function bytesToString(bytes: Uint8Array): string {
	return new TextDecoder().decode(bytes);
}

/** Convert UTF-8 string to Uint8Array */
function stringToBytes(str: string): Uint8Array {
	return new TextEncoder().encode(str);
}

// ---------------------------------------------------------------------------
// XOR cipher (WASM-safe, lightweight "encryption" for demo)
// ---------------------------------------------------------------------------

/** XOR data with a repeating key */
function xorBytes(data: Uint8Array, key: Uint8Array): Uint8Array {
	const result = new Uint8Array(data.length);
	for (let i = 0; i < data.length; i++) {
		result[i] = data[i] ^ key[i % key.length];
	}
	return result;
}

// ---------------------------------------------------------------------------
// Decryption
// ---------------------------------------------------------------------------

/**
 * Decrypt encrypted trade parameters.
 *
 * Tries two approaches:
 * 1. Direct hex-decode → JSON parse (plaintext simulation mode)
 * 2. XOR with encryption key → JSON parse (demo encryption mode)
 *
 * @param encryptedHex - Hex bytes from on-chain (encryptedParams field)
 * @param encryptionKey - Key from Vault DON (used for XOR mode)
 * @returns Decrypted and validated trade parameters
 */
export function decryptTradeParams(
	encryptedHex: string,
	encryptionKey: string,
): DecryptedTradeParams {
	const bytes = hexToBytes(encryptedHex);

	// Mode 1: Try direct hex → JSON (plaintext simulation)
	try {
		const jsonStr = bytesToString(bytes);
		const params = JSON.parse(jsonStr) as DecryptedTradeParams;
		validateTradeParams(params);
		return params;
	} catch {
		// Not plaintext JSON — try XOR decryption
	}

	// Mode 2: XOR cipher with encryption key
	try {
		const keyBytes = stringToBytes(encryptionKey);
		const decrypted = xorBytes(bytes, keyBytes);
		const jsonStr = bytesToString(decrypted);
		const params = JSON.parse(jsonStr) as DecryptedTradeParams;
		validateTradeParams(params);
		return params;
	} catch {
		// XOR decryption also failed
	}

	throw new Error(
		"Failed to decrypt trade parameters: neither plaintext nor XOR decryption produced valid JSON",
	);
}

/**
 * Validate that decrypted trade parameters have all required fields.
 */
function validateTradeParams(params: DecryptedTradeParams): void {
	if (!params.asset || typeof params.asset !== "string") {
		throw new Error("Missing or invalid field: asset");
	}
	if (!params.amount || typeof params.amount !== "string") {
		throw new Error("Missing or invalid field: amount");
	}
	if (!params.wantAsset || typeof params.wantAsset !== "string") {
		throw new Error("Missing or invalid field: wantAsset");
	}
	if (!params.wantAmount || typeof params.wantAmount !== "string") {
		throw new Error("Missing or invalid field: wantAmount");
	}
	if (params.destinationChain === undefined || params.destinationChain === null) {
		throw new Error("Missing field: destinationChain");
	}

	// Validate amounts are positive numbers
	const amount = Number(params.amount);
	if (Number.isNaN(amount) || amount <= 0) {
		throw new Error(`Invalid amount: ${params.amount}`);
	}
	const wantAmount = Number(params.wantAmount);
	if (Number.isNaN(wantAmount) || wantAmount <= 0) {
		throw new Error(`Invalid wantAmount: ${params.wantAmount}`);
	}
}
