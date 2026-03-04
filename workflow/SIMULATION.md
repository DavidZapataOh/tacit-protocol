# Tacit CRE Workflow — Simulation Guide

## Quick Start

```bash
cd workflow/tacit-settlement

# 1. Install dependencies (downloads Javy WASM compiler)
bun install

# 2. Type-check
bun run typecheck

# 3. Run CRE simulation (interactive — CRE prompts for trigger event)
bun run simulate
```

## How CRE Simulation Works

The CRE CLI compiles TypeScript → WASM, then runs the workflow against **real on-chain state**.

```
cre workflow simulate ./tacit-settlement -T local-simulation -e .env
│
├── 1. Compiles main.ts → WASM (via Javy/Bun)
├── 2. Reads config from config/config.local.json
├── 3. Loads secrets from secrets.yaml + .env
├── 4. Prompts for trigger event (or uses --evm-tx-hash)
└── 5. Executes workflow in sandbox against Sepolia RPC
```

**Important**: CRE CLI must be run from the `workflow/` directory (where `project.yaml` lives).

## Architecture

```
                                    ┌─── Confidential Compute (TEE) ───┐
BothPartiesDeposited ──► CRE CLI ──►│  Step 1: EVM Read (OTCVault)     │
    (EVM Log Trigger)               │  Step 2: Decrypt (Vault DON key) │
                                    │  Step 3: Bilateral Match         │
                                    │  Step 4: Sanctions (Conf. HTTP)  │
                                    │  Step 5: KYC (Conf. HTTP)        │
                                    │  Step 6: Settlement Report Write │
                                    └──────────────────────────────────┘
                                              │                │
                                    OTCVault.onReport()  ComplianceRegistry.onReport()
                                    (Settle or Refund)   (PASS/FAIL attestation)
```

## Simulation Commands

All commands run from `workflow/tacit-settlement/`:

| Command | Description |
|---------|-------------|
| `bun run simulate` | Interactive simulation (CRE prompts for trigger) |
| `bun run simulate:testnet` | Same, with testnet target |
| `bun run simulate:tx -- 0xabc...` | Non-interactive with specific tx hash |
| `bun run simulate:run` | Runner script with output capture |

### Non-Interactive Mode

If you have a transaction hash that emitted `BothPartiesDeposited`:

```bash
# Pass the tx hash directly — no TTY prompts needed
bun run simulate:tx -- 0xabc123...

# Or directly with CRE CLI:
cd workflow
cre workflow simulate ./tacit-settlement \
  -T local-simulation \
  -e .env \
  --non-interactive \
  --trigger-index 0 \
  --evm-event-index 0 \
  --evm-tx-hash 0xabc123...
```

### CRE CLI Flags Reference

```
--non-interactive       Run without prompts (requires --trigger-index + --evm-tx-hash)
--trigger-index 0       Index of the trigger (our workflow has 1 trigger at index 0)
--evm-tx-hash 0x...     Transaction hash containing the BothPartiesDeposited event
--evm-event-index 0     Log index within the tx (default: auto-detect)
--broadcast             Actually send write transactions to chain (default: false)
-e .env                 Path to .env file with secrets
-T local-simulation     Target from workflow.yaml
-v                      Verbose output
-g                      Engine debug logs
```

## Creating Test Trades

The CRE workflow triggers on `BothPartiesDeposited(bytes32)` from OTCVault. Create test trades on Sepolia:

```bash
# Prerequisites:
#   - contracts/.env with DEPLOYER_PRIVATE_KEY and PARTY_B_PRIVATE_KEY
#   - Both accounts need Sepolia ETH (>0.01 each)

# From workflow/tacit-settlement/:
bun run trade:happy       # Settlement path
bun run trade:mismatch    # Match failure → refund
bun run trade:sanctions   # Sanctions failure → refund

# Or directly with Foundry:
cd contracts
forge script script/CreateTestTrade.s.sol --sig "happyPath()" --rpc-url sepolia --broadcast -vvv
```

**Save the transaction hash** from the Foundry output — you'll need it for `simulate:tx`.

### Full E2E Flow

```bash
# 1. Create a test trade (note the tx hash from output)
cd workflow/tacit-settlement
bun run trade:happy
# Output: ...tx hash: 0xabc123...

# 2. Run simulation with that tx hash
bun run simulate:tx -- 0xabc123...

# Or interactively:
bun run simulate
# CRE CLI will prompt for the tx hash
```

## Test Scenarios

### 1. Happy Path → Settlement

- Party A: Sells 0.001 ETH, wants 2.5 USDC
- Party B: Sells 2.5 USDC, wants 0.001 ETH
- **Expected**: Match ✓ → Sanctions ✓ → KYC ✓ → **SETTLE**
- OTCVault executes DvP (Party A deposit → B, Party B deposit → A)
- ComplianceRegistry records: Trade X | Compliance: **PASS**

### 2. Parameter Mismatch → Refund

- Party A: Wants 2.5 USDC
- Party B: Offers only 2.0 USDC
- **Expected**: Match ✗ → **REFUND** (match-failed: amounts differ)
- OTCVault refunds both parties
- ComplianceRegistry records: Trade X | Compliance: **FAIL**

### 3. Sanctions Failure → Refund

- Both parties agree on terms (match passes)
- Party A's address is on OFAC SDN list
- **Expected**: Match ✓ → Sanctions ✗ → **REFUND** (compliance-failed)
- OTCVault refunds both parties
- ComplianceRegistry records: Trade X | Compliance: **FAIL**

## Chainlink Services Demonstrated

| # | Service | Where in Workflow | What It Does |
|---|---------|-------------------|--------------|
| 1 | **CRE** | Entire workflow | Orchestrates the 6-step flow |
| 2 | **Confidential Compute** | Steps 1-6 | All processing inside TEE — data never exposed |
| 3 | **Confidential HTTP** | Steps 4-5 | API calls to sanctions/KYC with injected secrets |
| 4 | **Vault DON / DKG** | Steps 2, 4-5 | Encryption key + API keys from threshold storage |
| 5 | **EVM Read** | Step 1 | `evmClient.callContract()` reads Trade struct |
| 6 | **EVM Write** | Step 6 | `runtime.report()` + `evmClient.writeReport()` on-chain |

## Privacy Guarantees

What is **visible on-chain**:
- Trade ID (bytes32)
- Compliance result: PASS or FAIL
- Timestamp of verification

What is **NEVER visible on-chain**:
- Trade amounts
- Asset types
- Counterparty identities
- Sanctions/KYC details
- Decrypted trade parameters

## Output Files

Simulation logs are saved to `workflow/simulation-output/` with timestamped filenames:
```
simulation-output/
  simulation_local-simulation_20260304_143022.log
  simulation_testnet_20260304_143155.log
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `cre: command not found` | Install CRE CLI from github.com/smartcontractkit/cre-cli/releases |
| `bun: command not found` | Install Bun: `curl -fsSL https://bun.sh/install \| bash` |
| `no project settings file found` | Run from `workflow/` dir (where `project.yaml` is) |
| `open /dev/tty: no such device` | Use `--non-interactive --evm-tx-hash 0x...` mode |
| WASM compilation fails | Run `bun install` (triggers `cre-setup` postinstall for Javy) |
| `.env` errors | Ensure `workflow/.env` exists with secret values |
| No trigger event | Create a test trade first: `bun run trade:happy` |
| TypeScript errors | Run `bun run typecheck` to see specific errors |
