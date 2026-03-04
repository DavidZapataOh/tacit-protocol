import { Env, AddressResult } from "./types";

/**
 * Known sanctioned Ethereum addresses.
 * This is the fallback list used when KV store is empty.
 * Plan 2.3 will populate KV with parsed OFAC SDN data.
 *
 * Sources:
 * - Tornado Cash addresses sanctioned by OFAC (Aug 2022)
 * - Other OFAC-designated crypto addresses from SDN list
 */
const HARDCODED_SANCTIONED_ADDRESSES: Set<string> = new Set([
  // Tornado Cash contract addresses (sanctioned Aug 8, 2022)
  "0x8589427373d6d84e98730d7795d8f6f8731fda16",
  "0x722122df12d4e14e13ac3b6895a86e84145b6967",
  "0xdd4c48c0b24039969fc16d1cdf626eab821d3384",
  "0xd90e2f925da726b50c4ed8d0fb90ad053324f31b",
  "0xd96f2b1ef156b3eb18e563b07d81e07e6b4c3c58",
  "0x4736dcf1b7a3d580672cce6e7c65cd5cc9cfbfb9",
  "0xd4b88df4d29f5cedd6857912842cff3b20c8cfa3",
  "0x910cbd523d972eb0a6f4cae4618ad62622b39dbf",
  "0xa160cdab225685da1d56aa342ad8841c3b53f291",
  "0xfd8610d20aa15b7b2e3be39b396a1bc3516c7144",
  "0xf60dd140cff0706bae9cd734ac3683f59265edd",
  "0x22aaa7720ddd5388a3c0a3333430953c68f1849b",
  "0xba214c1c1928a32bffe790263e38b4af9bfcd659",
  "0xb1c8094b234dce6e03f10a5b673c1d8c69739a00",
  "0x527653ea119f3e6a1f5bd18fbf4714081d7b31ce",
  "0x58e8dcc13be9780fc42e8723d8ead4cf46943df2",
  // Lazarus Group / North Korea attributed addresses
  "0x098b716b8aaf21512996dc57eb0615e2383e2f96",
  "0xa0e1c89ef1a489c9c7de96311ed5ce5d32c20e4b",
  // Demo: always-sanctioned test address for hackathon demo
  "0x0000000000000000000000000000000000000bad",
]);

/**
 * Normalize an Ethereum address to lowercase for consistent comparison
 */
function normalizeAddress(address: string): string {
  return address.toLowerCase().trim();
}

/**
 * Validate that a string looks like an Ethereum address
 */
function isValidEthAddress(address: string): boolean {
  return /^0x[0-9a-fA-F]{40}$/.test(address);
}

/**
 * Check a single address against the sanctions list.
 * First checks KV store (populated by Plan 2.3), then falls back to hardcoded list.
 */
export async function checkAddress(
  address: string,
  env: Env
): Promise<AddressResult> {
  const normalized = normalizeAddress(address);

  // First: check KV store (populated with real OFAC data by Plan 2.3)
  try {
    const kvResult = await env.SANCTIONS_KV.get(`addr:${normalized}`);
    if (kvResult !== null) {
      const data = JSON.parse(kvResult);
      return {
        address: normalized,
        sanctioned: true,
        source: data.source || "OFAC_SDN",
      };
    }
  } catch {
    // KV not available (e.g., local dev without KV binding) — fall through to hardcoded
  }

  // Fallback: check hardcoded list
  if (HARDCODED_SANCTIONED_ADDRESSES.has(normalized)) {
    return {
      address: normalized,
      sanctioned: true,
      source: "OFAC_SDN",
    };
  }

  return {
    address: normalized,
    sanctioned: false,
  };
}

/**
 * Check multiple addresses against the sanctions list.
 * Returns per-address results and an aggregate allClear boolean.
 */
export async function checkAddresses(
  addresses: string[],
  env: Env
): Promise<{ allClear: boolean; results: AddressResult[] }> {
  for (const addr of addresses) {
    if (!isValidEthAddress(addr)) {
      throw new Error(`Invalid Ethereum address: ${addr}`);
    }
  }

  const results = await Promise.all(
    addresses.map((addr) => checkAddress(addr, env))
  );

  const allClear = results.every((r) => !r.sanctioned);

  return { allClear, results };
}
