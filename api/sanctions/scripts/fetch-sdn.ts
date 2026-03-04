import * as fs from "fs";
import * as path from "path";
import { KNOWN_SANCTIONED_ADDRESSES, SanctionedAddress } from "./known-crypto-addresses";

const SDN_CSV_URL = "https://www.treasury.gov/ofac/downloads/sdn.csv";
const SDN_ADD_URL = "https://www.treasury.gov/ofac/downloads/add.csv";
const DATA_DIR = path.join(__dirname, "..", "data");

/**
 * Download a file from a URL and save to disk
 */
async function downloadFile(url: string, filename: string): Promise<string> {
  console.log(`Downloading ${url}...`);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download ${url}: ${response.status}`);
  }
  const text = await response.text();
  const filepath = path.join(DATA_DIR, filename);
  fs.writeFileSync(filepath, text, "utf-8");
  console.log(`Saved to ${filepath} (${text.length} bytes)`);
  return text;
}

/**
 * Parse the SDN CSV for cryptocurrency addresses.
 * Crypto addresses appear in the remarks column (last field) of sdn.csv
 * with format: "Digital Currency Address - ETH 0x..."
 */
function parseSdnCsvForCryptoAddresses(csvContent: string): SanctionedAddress[] {
  const results: SanctionedAddress[] = [];
  const lines = csvContent.split("\n");

  for (const line of lines) {
    if (!line.toLowerCase().includes("digital currency address")) continue;

    // Extract entity name from second CSV field
    const nameMatch = line.match(/^\d+,"([^"]+)"/);
    const entityName = nameMatch ? nameMatch[1] : "OFAC SDN Listed Entity";

    // Extract Ethereum-like addresses (0x followed by 40 hex chars)
    const ethMatches = line.match(/0x[0-9a-fA-F]{40}/g);
    if (ethMatches) {
      for (const addr of ethMatches) {
        results.push({
          address: addr.toLowerCase(),
          source: "OFAC_SDN_CSV",
          entity: entityName,
          dateAdded: new Date().toISOString().split("T")[0],
        });
      }
    }
  }

  console.log(`Parsed ${results.length} ETH addresses from SDN CSV`);
  return results;
}

/**
 * Main: download OFAC data, parse it, merge with known addresses, and output JSON
 */
async function main() {
  // Ensure data directory exists
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }

  // Download SDN files
  const sdnCsv = await downloadFile(SDN_CSV_URL, "sdn.csv");
  await downloadFile(SDN_ADD_URL, "add.csv");

  // Parse crypto addresses from the main SDN file (remarks column)
  const parsedAddresses = parseSdnCsvForCryptoAddresses(sdnCsv);

  // Merge: curated known addresses + parsed addresses (deduplicated)
  const allAddresses = new Map<string, SanctionedAddress>();

  // Add curated addresses first (higher quality metadata)
  for (const entry of KNOWN_SANCTIONED_ADDRESSES) {
    allAddresses.set(entry.address.toLowerCase(), entry);
  }

  // Add parsed addresses (won't overwrite curated ones)
  for (const entry of parsedAddresses) {
    const key = entry.address.toLowerCase();
    if (!allAddresses.has(key)) {
      allAddresses.set(key, entry);
    }
  }

  const merged = Array.from(allAddresses.values());
  console.log(`\nTotal unique sanctioned addresses: ${merged.length}`);
  console.log(`  - Curated (known-crypto-addresses.ts): ${KNOWN_SANCTIONED_ADDRESSES.length}`);
  console.log(`  - Parsed from SDN CSV: ${parsedAddresses.length}`);
  console.log(`  - After deduplication: ${merged.length}`);

  // Write merged output for upload
  const outputPath = path.join(DATA_DIR, "sanctioned-addresses.json");
  fs.writeFileSync(outputPath, JSON.stringify(merged, null, 2), "utf-8");
  console.log(`\nWrote merged data to ${outputPath}`);

  return merged;
}

main().catch(console.error);
