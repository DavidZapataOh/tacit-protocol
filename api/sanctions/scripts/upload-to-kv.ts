import * as fs from "fs";
import * as path from "path";
import { execSync } from "child_process";
import { SanctionedAddress } from "./known-crypto-addresses";

const DATA_DIR = path.join(__dirname, "..", "data");
const KV_NAMESPACE_BINDING = "SANCTIONS_KV";

/**
 * Upload sanctioned addresses to Cloudflare KV store.
 * Each address is stored as: key = "addr:<lowercase_address>", value = JSON metadata
 */
async function main() {
  const dataPath = path.join(DATA_DIR, "sanctioned-addresses.json");

  if (!fs.existsSync(dataPath)) {
    console.error("Error: sanctioned-addresses.json not found. Run fetch-sdn.ts first.");
    process.exit(1);
  }

  const addresses: SanctionedAddress[] = JSON.parse(
    fs.readFileSync(dataPath, "utf-8")
  );

  console.log(`Uploading ${addresses.length} sanctioned addresses to KV...`);

  // Batch upload using wrangler kv:bulk put
  const kvEntries = addresses.map((entry) => ({
    key: `addr:${entry.address.toLowerCase()}`,
    value: JSON.stringify({
      source: entry.source,
      entity: entry.entity,
      dateAdded: entry.dateAdded,
    }),
  }));

  // Write batch file for wrangler
  const batchPath = path.join(DATA_DIR, "kv-batch.json");
  fs.writeFileSync(batchPath, JSON.stringify(kvEntries, null, 2), "utf-8");

  // Upload via wrangler CLI
  try {
    const cmd = `npx wrangler kv:bulk put --binding=${KV_NAMESPACE_BINDING} --preview false "${batchPath}"`;
    console.log(`Running: ${cmd}`);
    execSync(cmd, { stdio: "inherit", cwd: path.join(__dirname, "..") });
    console.log(`\nSuccessfully uploaded ${addresses.length} entries to KV`);
  } catch {
    console.error("Error uploading to KV. Make sure wrangler is authenticated and the namespace exists.");
    console.error("Create namespace: npx wrangler kv namespace create SANCTIONS_KV");
    console.error("Then update wrangler.toml with the namespace ID and retry.");
    process.exit(1);
  }

  // Print summary statistics
  const bySource = new Map<string, number>();
  for (const entry of addresses) {
    bySource.set(entry.source, (bySource.get(entry.source) || 0) + 1);
  }
  console.log("\nBreakdown by source:");
  for (const [source, count] of bySource) {
    console.log(`  ${source}: ${count}`);
  }
}

main().catch(console.error);
