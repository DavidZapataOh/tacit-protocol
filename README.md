<p align="center">
  <img src="img/tacit.svg" alt="Tacit Protocol" width="20%" />
</p>

<h1 align="center">Tacit</h1>

<p align="center">
  <strong>Private OTC Settlement with Automated Compliance</strong>
</p>

<p align="center">
  Trade privately. Settle compliantly.
</p>

<p align="center">
  <a href="#demo-video">Video</a> · <a href="#how-it-works">How It Works</a> · <a href="#chainlink-services">Chainlink Services</a> · <a href="#getting-started">Run Locally</a> · <a href="#deployed-contracts">Contracts</a>
</p>

---

## The Problem

Crypto OTC trading moves **$39 billion daily** and grew **109% in 2025**. Yet there is no way to settle these trades privately, compliantly, and without intermediaries — all at the same time.

| Existing Solution | Privacy | Compliance | Decentralized | Atomic DvP |
|---|:---:|:---:|:---:|:---:|
| Copper ClearLoop | Yes | Yes | No | No |
| Fireblocks Off Exchange | Yes | Yes | No | No |
| Renegade (MPC Dark Pool) | Yes | No | Yes | No |
| AirSwap | No | No | Yes | No |
| **Tacit** | **Yes** | **Yes** | **Yes** | **Yes** |

In May 2025, Chainlink + J.P. Morgan (Kinexys) + Ondo Finance completed **one single bespoke DvP test transaction** after 2+ years of planning. Tacit democratizes this — making private, compliant OTC settlement accessible to any pair of counterparties in minutes.

---

## How It Works

Two counterparties negotiate a trade off-chain (chat, phone, email), then use Tacit to settle it privately on-chain.

```
┌──────────────────────────────────────────────────────────────────────┐
│                        TACIT PROTOCOL                                │
│                                                                      │
│  ┌───────────┐    ┌───────────┐    ┌──────────────────────────────┐  │
│  │  Party A  │    │  Party B  │    │   CRE Workflow (TEE)         │  │
│  │           │    │           │    │                              │  │
│  │ 1. Create │    │ 2. Match  │    │ 3. Decrypt parameters        │  │
│  │    trade  │    │    trade  │    │ 4. Bilateral match           │  │
│  │           │    │           │    │ 5. Sanctions check (OFAC)    │  │
│  │ Deposit   │    │ Deposit   │    │ 6. KYC verification          │  │
│  │ encrypted │    │ encrypted │    │ 7. Settlement (DvP)          │  │
│  │ params    │    │ params    │    │ 8. Compliance attestation    │  │
│  └─────┬─────┘    └─────┬─────┘    └──────────────┬───────────────┘  │
│        │                │                          │                 │
│        ▼                ▼                          ▼                 │
│   ┌─────────────────────────────────────────────────────────────┐    │
│   │                    OTCVault (Sepolia)                       │    │
│   │  Encrypted escrow — only TEE can read trade parameters      │    │
│   └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  On-chain output: Trade ID • Compliance: PASS • Timestamp            │
│  Nothing else. No amounts. No identities. No assets.                 │
└──────────────────────────────────────────────────────────────────────┘
```

**What the public sees:** A compliance attestation — trade ID, pass/fail, timestamp. That's it.

**What stays private:** Identities, amounts, assets, trade terms, compliance API responses — all processed inside the TEE and never written on-chain.

---

## Demo Video

> **[Watch the 4-minute demo →](#)** *(link pending)*

The demo shows the full flow: Party A creates a trade → Party B matches → CRE Workflow verifies compliance → atomic settlement → attestation recorded — all from the frontend, fully automated.

---

## Chainlink Services

Tacit integrates **6 Chainlink services** in a coherent 6-step workflow:

| # | Service | What It Does | File |
|---|---------|-------------|------|
| 1 | **CRE Workflow** | Orchestrates the entire settlement pipeline | [`workflow/tacit-settlement/main.ts`](workflow/tacit-settlement/main.ts) |
| 2 | **Confidential Compute (TEE)** | Decrypts trade parameters, verifies bilateral match inside enclave | [`workflow/tacit-settlement/crypto.ts`](workflow/tacit-settlement/crypto.ts) |
| 3 | **Confidential HTTP** | Calls sanctions + KYC APIs without exposing credentials or responses on-chain | [`workflow/tacit-settlement/compliance.ts`](workflow/tacit-settlement/compliance.ts) |
| 4 | **Vault DON / DKG** | Stores API keys and encryption secrets — never exposed to blockchain | [`workflow/secrets.yaml`](workflow/secrets.yaml) |
| 5 | **CCIP** | Cross-chain atomic DvP settlement (Sepolia ↔ Arbitrum Sepolia) | [`contracts/src/OTCVaultReceiver.sol`](contracts/src/OTCVaultReceiver.sol) |
| 6 | **EVM Read/Write** | Reads trade state, writes settlement + compliance attestation on-chain | [`contracts/src/OTCVault.sol`](contracts/src/OTCVault.sol) |

### Workflow Definition

| File | Description |
|------|-------------|
| [`workflow/tacit-settlement/workflow.yaml`](workflow/tacit-settlement/workflow.yaml) | CRE workflow triggers and targets |
| [`workflow/tacit-settlement/main.ts`](workflow/tacit-settlement/main.ts) | 690-line entry point — 6-step settlement |
| [`workflow/tacit-settlement/match.ts`](workflow/tacit-settlement/match.ts) | Bilateral parameter matching |
| [`workflow/tacit-settlement/compliance.ts`](workflow/tacit-settlement/compliance.ts) | Sanctions + KYC via Confidential HTTP |
| [`workflow/tacit-settlement/settlement.ts`](workflow/tacit-settlement/settlement.ts) | DvP settlement logic |
| [`workflow/tacit-settlement/crypto.ts`](workflow/tacit-settlement/crypto.ts) | Vault DON threshold decryption |
| [`workflow/tacit-settlement/types.ts`](workflow/tacit-settlement/types.ts) | TypeScript types |
| [`workflow/project.yaml`](workflow/project.yaml) | CRE project config (RPC URLs, chains) |
| [`workflow/secrets.yaml`](workflow/secrets.yaml) | Vault DON secret mappings |

---

## Architecture

```
                          ┌───────────────────────────┐
                          │     Frontend (Next.js)    │
                          │   Wallet · Create · Match │
                          │   Status · Explorer       │
                          └────────────┬──────────────┘
                                       │
                          ┌────────────▼──────────────┐
                          │   OTCVault (Sepolia)      │
                          │   Encrypted escrow        │
                          │   createTradeETH()        │
                          │   matchTradeToken()       │
                          │   onReport() ← CRE        │
                          └────────────┬──────────────┘
                                       │
              ┌────────────────────────▼─────────────────────────┐
              │           CRE Workflow (TEE Enclave)             │
              │                                                  │
              │  Step 1: EVM Read → get trade data               │
              │  Step 2: Confidential Compute → decrypt + match  │
              │  Step 3: Confidential HTTP → OFAC sanctions API  │
              │  Step 4: Confidential HTTP → KYC API             │
              │  Step 5: EVM Write → settle (DvP)                │
              │  Step 6: EVM Write → compliance attestation      │
              │                                                  │
              │  Vault DON: API keys for sanctions/KYC           │
              └───────┬───────────────────────────┬──────────────┘
                      │                           │
         ┌────────────▼──────────┐   ┌────────────▼───────────────┐
         │ ComplianceRegistry    │   │ OTCVaultReceiver           │
         │ (Sepolia)             │   │ (Arbitrum Sepolia)         │
         │                       │   │                            │
         │ Attestation:          │   │ Cross-chain DvP via CCIP   │
         │ tradeId + PASS + time │   │ Receives settlement msg    │
         └───────────────────────┘   └────────────────────────────┘
```

---

## Smart Contracts

| Contract | Chain | Address | Verified |
|----------|-------|---------|:--------:|
| OTCVault | Sepolia | [`0xdcf70165b005e00fFdf904BACE94A560bff26358`](https://sepolia.etherscan.io/address/0xdcf70165b005e00fFdf904BACE94A560bff26358) | Yes |
| ComplianceRegistry | Sepolia | [`0x58FCD94b1BB542fF728c9FC40a7BBfE2fFEa018e`](https://sepolia.etherscan.io/address/0x58FCD94b1BB542fF728c9FC40a7BBfE2fFEa018e) | Yes |
| OTCVaultReceiver | Arbitrum Sepolia | [`0xDBB75Cbdf99C03D585c2879BCbedF99eeD270aC7`](https://sepolia.arbiscan.io/address/0xDBB75Cbdf99C03D585c2879BCbedF99eeD270aC7) | Yes |

### Contract Source Files

| File | Lines | Description |
|------|:-----:|-------------|
| [`contracts/src/OTCVault.sol`](contracts/src/OTCVault.sol) | ~400 | Non-custodial escrow with encrypted parameters, ETH + ERC-20 support, CRE report receiver, CCIP sender |
| [`contracts/src/ComplianceRegistry.sol`](contracts/src/ComplianceRegistry.sol) | ~120 | Immutable compliance attestations — only stores tradeId, pass/fail, timestamp |
| [`contracts/src/OTCVaultReceiver.sol`](contracts/src/OTCVaultReceiver.sol) | ~180 | CCIP receiver for cross-chain settlement on destination chain |
| [`contracts/src/libraries/SettlementEncoder.sol`](contracts/src/libraries/SettlementEncoder.sol) | ~80 | Encode/decode cross-chain settlement instructions |
| [`contracts/src/libraries/TacitConstants.sol`](contracts/src/libraries/TacitConstants.sol) | ~30 | Shared protocol constants |

### Tests — 175 passing, 0 failing

| Test Suite | Tests | File |
|------------|:-----:|------|
| OTCVault | 59 | [`contracts/test/OTCVault.t.sol`](contracts/test/OTCVault.t.sol) |
| E2E Failure Paths | 33 | [`contracts/test/E2EFailurePaths.t.sol`](contracts/test/E2EFailurePaths.t.sol) |
| ComplianceRegistry | 25 | [`contracts/test/ComplianceRegistry.t.sol`](contracts/test/ComplianceRegistry.t.sol) |
| OTCVaultReceiver | 23 | [`contracts/test/OTCVaultReceiver.t.sol`](contracts/test/OTCVaultReceiver.t.sol) |
| CCIP | 18 | [`contracts/test/CCIP.t.sol`](contracts/test/CCIP.t.sol) |
| E2E Cross-Chain | 9 | [`contracts/test/E2ECrossChain.t.sol`](contracts/test/E2ECrossChain.t.sol) |
| E2E Happy Path | 8 | [`contracts/test/E2EHappyPath.t.sol`](contracts/test/E2EHappyPath.t.sol) |

---

## Compliance APIs

Privacy-preserving compliance verification via Cloudflare Workers, called exclusively through **Confidential HTTP** (credentials and responses never touch the blockchain):

| API | Source | What It Checks |
|-----|--------|---------------|
| Sanctions | [`api/sanctions/src/`](api/sanctions/) | OFAC SDN list — real sanctioned addresses from the U.S. Treasury |
| KYC | [`api/kyc/src/`](api/kyc/) | Accredited investor verification (KYC level: none / basic / accredited / institutional) |

---

## Frontend

Built with Next.js 14, wagmi v2, viem, RainbowKit, TailwindCSS, and shadcn/ui.

| Page | Route | Description |
|------|-------|-------------|
| Create Trade | `/` | Deposit assets + encrypt trade parameters |
| Match Trade | `/match` | Counterparty enters matching code + deposits |
| Trade Status | `/status/[tradeId]` | Real-time 6-step workflow progress |
| Explorer | `/explorer` | Public compliance attestation viewer |

### Key Frontend Files

| File | Description |
|------|-------------|
| [`frontend/src/hooks/useCreateTrade.ts`](frontend/src/hooks/useCreateTrade.ts) | Trade creation with ETH/ERC-20 approve flow |
| [`frontend/src/hooks/useMatchTrade.ts`](frontend/src/hooks/useMatchTrade.ts) | Counterparty matching logic |
| [`frontend/src/hooks/useAutoSettle.ts`](frontend/src/hooks/useAutoSettle.ts) | Automatic settlement trigger |
| [`frontend/src/hooks/useTradeStatus.ts`](frontend/src/hooks/useTradeStatus.ts) | On-chain status polling |
| [`frontend/src/lib/encryption.ts`](frontend/src/lib/encryption.ts) | Client-side encryption with DON public key |
| [`frontend/src/components/trade/workflow-stepper.tsx`](frontend/src/components/trade/workflow-stepper.tsx) | Settlement progress visualization |
| [`frontend/src/app/api/settle/route.ts`](frontend/src/app/api/settle/route.ts) | Settlement API (demo mode — disabled when CRE DON is live) |

---

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (Solidity)
- [Bun](https://bun.sh/) (CRE workflow)
- [Node.js](https://nodejs.org/) 18+ (Frontend)
- [CRE CLI](https://docs.chain.link/cre) (Workflow simulation)

### 1. Clone and install

```bash
git clone https://github.com/YOUR_USERNAME/tacit.git
cd tacit
```

### 2. Build and test contracts

```bash
cd contracts
forge build
forge test -vvv    # 175 tests, all passing
```

### 3. Simulate the CRE workflow

```bash
cd workflow
cp .env.example .env    # Add your secrets
cre login
cre workflow simulate ./tacit-settlement -T testnet
```

Expected output: `settlement-complete` with all 6 steps passing.

### 4. Run the frontend

```bash
cd frontend
cp .env.local.example .env.local    # Add WalletConnect ID + deployer key
npm install
npm run dev
```

Open `http://localhost:3000`, connect wallet, and create a trade.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Smart Contracts | Solidity 0.8.24, Foundry, OpenZeppelin v5.1 |
| CRE Workflow | TypeScript, CRE SDK v1.1.3, Bun |
| Cross-Chain | Chainlink CCIP v1.6.4 |
| Frontend | Next.js 14, wagmi v2, viem, RainbowKit, TailwindCSS, shadcn/ui |
| Compliance APIs | Cloudflare Workers, OFAC SDN list |
| Chains | Sepolia (primary), Arbitrum Sepolia (cross-chain DvP) |

---

## Project Structure

```
tacit/
├── contracts/              Foundry project
│   ├── src/                Solidity contracts (OTCVault, ComplianceRegistry, OTCVaultReceiver)
│   ├── test/               175 Foundry tests (unit, E2E, cross-chain)
│   └── script/             Deploy and config scripts
├── workflow/               CRE workflow
│   └── tacit-settlement/   6-step settlement workflow (main.ts, workflow.yaml)
├── frontend/               Next.js 14 app
│   └── src/                Pages, components, hooks, encryption
├── api/                    Compliance APIs (Cloudflare Workers)
│   ├── sanctions/          OFAC SDN sanctions screening
│   └── kyc/                KYC/accreditation verification
└── docs/                   Architecture paper, security audit, gas reports
```

---

## Privacy Model

Tacit's privacy comes from **Chainlink Confidential Compute (TEE)**, not ZK proofs:

| Data | Visibility |
|------|-----------|
| Trade parameters (amounts, assets, terms) | Encrypted on-chain — only TEE can read |
| Compliance API calls (sanctions, KYC) | Confidential HTTP — credentials + responses never on-chain |
| API keys | Vault DON — threshold-encrypted, never exposed |
| Settlement logic | Executes inside TEE enclave |
| **Compliance attestation** | **Public** — trade ID, pass/fail, timestamp only |

> In production, [CCIP Private Transactions](https://blog.chain.link/chainlink-confidential-compute/) would add transport-layer privacy for token movements. Currently enterprise-only — Tacit is designed to integrate it when available.

---

## Why This Matters

- **$39B+ daily** OTC crypto volume with no private settlement infrastructure
- **109% YoY growth** — institutions are coming, they need privacy + compliance
- **$72.9M/year** average compliance spend per firm — Tacit automates this
- **Zero projects** in the OTC/DvP category across all prior Chainlink hackathons
- **Democratizes** what J.P. Morgan demonstrated as a single bespoke test

---

<p align="center">
  <em>Trade privately. Settle compliantly.</em>
</p>

<p align="center">
  Built for <a href="https://chain.link/hackathon">Convergence: A Chainlink Hackathon</a> — Privacy Track
</p>
