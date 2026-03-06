import { Env, KYCLevel, KYCRecord, AddressKYCResult } from "./types";

/**
 * KYC level hierarchy for comparison.
 * Higher number = higher verification tier.
 */
const KYC_LEVEL_ORDER: Record<KYCLevel, number> = {
  none: 0,
  basic: 1,
  accredited: 2,
  institutional: 3,
};

/**
 * Mock database of pre-verified wallets for the hackathon demo.
 * In production, this would be replaced by a real KYC provider API.
 *
 * These addresses are used in the demo flow:
 * - Party A and Party B have "accredited" status -> trade succeeds
 * - The "unverified" address causes the trade to fail -> refund demo
 */
const MOCK_VERIFIED_WALLETS: Map<string, KYCRecord> = new Map([
  // Demo Party A — always verified (accredited investor)
  [
    "0x70997970c51812dc3a010c7d01b50e0d17dc79c8",
    {
      level: "accredited",
      verifiedAt: "2026-01-15T00:00:00Z",
      expiresAt: "2027-01-15T00:00:00Z",
      entity: "entity-demo-party-a",
    },
  ],
  // Demo Party B — always verified (accredited investor)
  [
    "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc",
    {
      level: "accredited",
      verifiedAt: "2026-01-20T00:00:00Z",
      expiresAt: "2027-01-20T00:00:00Z",
      entity: "entity-demo-party-b",
    },
  ],
  // Institutional-level verified address
  [
    "0x90f79bf6eb2c4f870365e785982e1f101e93b906",
    {
      level: "institutional",
      verifiedAt: "2026-02-01T00:00:00Z",
      expiresAt: "2027-02-01T00:00:00Z",
      entity: "entity-institutional-demo",
    },
  ],
  // Basic-level verified address (will fail accredited check)
  [
    "0x15d34aaf54267db7d7c367839aaf71a00a2c6a65",
    {
      level: "basic",
      verifiedAt: "2026-02-10T00:00:00Z",
      expiresAt: "2027-02-10T00:00:00Z",
      entity: "entity-basic-demo",
    },
  ],
  // Deployer/Owner wallet (Party A in Sepolia tests) — accredited
  [
    "0x68905da737e5a11e3a93ab6cec2ea8b145fce961",
    {
      level: "accredited",
      verifiedAt: "2026-03-01T00:00:00Z",
      expiresAt: "2027-03-01T00:00:00Z",
      entity: "entity-deployer",
    },
  ],
  // Party B wallet (Sepolia tests) — accredited
  [
    "0xfa8b848a0e0b5868d34357bf77a055782c69aaf1",
    {
      level: "accredited",
      verifiedAt: "2026-03-01T00:00:00Z",
      expiresAt: "2027-03-01T00:00:00Z",
      entity: "entity-party-b-sepolia",
    },
  ],
  // Party B wallet 2 (Sepolia live tests) — accredited
  [
    "0xd53ad32ae97ce7e5636d65c9db8517c1cbce7a2d",
    {
      level: "accredited",
      verifiedAt: "2026-03-01T00:00:00Z",
      expiresAt: "2027-03-01T00:00:00Z",
      entity: "entity-party-b-sepolia-2",
    },
  ],
  // Demo fail address — explicitly unverified
  [
    "0x0000000000000000000000000000000000000bad",
    {
      level: "none",
      verifiedAt: "",
      expiresAt: "",
    },
  ],
]);

/**
 * Normalize address to lowercase for consistent comparison
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
 * Check whether a given KYC level meets the required minimum
 */
function meetsLevel(actual: KYCLevel, required: KYCLevel): boolean {
  return KYC_LEVEL_ORDER[actual] >= KYC_LEVEL_ORDER[required];
}

/**
 * Check if a KYC record has expired
 */
function isExpired(record: KYCRecord): boolean {
  if (!record.expiresAt) return true;
  return new Date(record.expiresAt) < new Date();
}

/**
 * Verify a single address against the KYC database.
 * First checks KV store (for dynamically added wallets), then falls back to mock database.
 */
export async function verifyAddress(
  address: string,
  requiredLevel: KYCLevel,
  env: Env
): Promise<AddressKYCResult> {
  const normalized = normalizeAddress(address);

  // First: check KV store for dynamically added wallets
  try {
    const kvResult = await env.KYC_KV.get(`kyc:${normalized}`);
    if (kvResult !== null) {
      const record: KYCRecord = JSON.parse(kvResult);
      const expired = isExpired(record);
      const levelMet = meetsLevel(record.level, requiredLevel);
      return {
        address: normalized,
        verified: levelMet && !expired,
        level: record.level,
        verifiedAt: record.verifiedAt || undefined,
        expiresAt: record.expiresAt || undefined,
      };
    }
  } catch {
    // KV not available (local dev without KV binding) — fall through to mock
  }

  // Fallback: check mock database
  const mockRecord = MOCK_VERIFIED_WALLETS.get(normalized);
  if (mockRecord) {
    const expired = isExpired(mockRecord);
    const levelMet = meetsLevel(mockRecord.level, requiredLevel);
    return {
      address: normalized,
      verified: levelMet && !expired,
      level: mockRecord.level,
      verifiedAt: mockRecord.verifiedAt || undefined,
      expiresAt: mockRecord.expiresAt || undefined,
    };
  }

  // Address not found — not verified
  return {
    address: normalized,
    verified: false,
    level: "none",
  };
}

/**
 * Verify multiple addresses. Returns per-address results and aggregate allVerified.
 */
export async function verifyAddresses(
  addresses: string[],
  requiredLevel: KYCLevel,
  env: Env
): Promise<{ allVerified: boolean; results: AddressKYCResult[] }> {
  for (const addr of addresses) {
    if (!isValidEthAddress(addr)) {
      throw new Error(`Invalid Ethereum address: ${addr}`);
    }
  }

  const results = await Promise.all(
    addresses.map((addr) => verifyAddress(addr, requiredLevel, env))
  );

  const allVerified = results.every((r) => r.verified);

  return { allVerified, results };
}

/**
 * Seed the KV store with demo wallets (admin endpoint).
 * Allows adding wallets dynamically for the demo without redeploying.
 */
export async function seedWallet(
  address: string,
  record: KYCRecord,
  env: Env
): Promise<void> {
  const normalized = normalizeAddress(address);
  await env.KYC_KV.put(`kyc:${normalized}`, JSON.stringify(record));
}
