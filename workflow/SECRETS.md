# Tacit CRE Workflow — Secrets Management

## Overview

Tacit uses the **Vault DON** (Distributed Oracle Network) to manage sensitive credentials. Secrets are threshold-encrypted using **Distributed Key Generation (DKG)** — no single node operator can access a complete secret. Decryption only occurs inside the TEE during authorized workflow execution.

See: Tacit Paper, Section 5.3.3 (Vault DON and DKG)

## Secrets

| Secret | Step | Usage Pattern | Source |
|--------|------|---------------|--------|
| `OFAC_API_KEY` | Step 4 (Sanctions) | `{{.OFAC_API_KEY}}` in HTTP headers (Vault DON injection) | Cloudflare Worker `api/sanctions/` |
| `KYC_API_KEY` | Step 5 (KYC) | `{{.KYC_API_KEY}}` in HTTP headers (Vault DON injection) | Cloudflare Worker `api/kyc/` |
| `ENCRYPTION_KEY` | Step 2 (Decrypt) | `runtime.getSecret({ id: "ENCRYPTION_KEY" })` | Generated for trade encryption |

## How Secrets Are Protected

1. **At rest**: Threshold-encrypted in Vault DON (K-of-N DKG shares)
2. **In transit**: Decrypted only inside TEE during workflow execution
3. **HTTP calls**: API keys injected by Vault DON via `{{.SECRET}}` templates in headers — never in workflow memory
4. **After use**: Immediately discarded from enclave memory
5. **On-chain**: NEVER appear on-chain in any form

## File Structure

```
workflow/
├── secrets.yaml    # Maps secret IDs to env var names (secretsNames format)
├── .env            # Actual secret values (GITIGNORED — never committed)
└── .gitignore      # Includes .env
```

## Simulation (Local Development)

```bash
cd workflow
source .env                    # Export env vars
cre workflow simulate ./tacit-settlement -T local-simulation
```

The CRE CLI reads `secrets.yaml`, finds the `secretsNames` mappings, and resolves each env var from your shell environment. No Vault DON interaction occurs in simulation mode.

## Testnet Deployment

```bash
cd workflow
source .env                    # Export env vars with production values
cre secrets upload             # Threshold-encrypt and upload to Vault DON
cre secrets list               # Verify uploaded secrets
```

## Rotation Process

1. Update the API key in the Cloudflare Worker:
   ```bash
   cd api/sanctions && wrangler secret put API_KEY
   ```
2. Update `workflow/.env` with the new value
3. Re-upload to Vault DON:
   ```bash
   cd workflow && source .env && cre secrets upload
   ```
4. Verify: `cre secrets list`

## Key Matching

The API keys in `.env` **must match** the keys configured in the Cloudflare Workers:

| Secret | Worker | Set via |
|--------|--------|---------|
| `TACIT_OFAC_API_KEY` | `api/sanctions/` | `wrangler secret put API_KEY` |
| `TACIT_KYC_API_KEY` | `api/kyc/` | `wrangler secret put API_KEY` |

A mismatch will cause HTTP 401 errors during compliance checks (Steps 4-5).

## Hackathon Note

The `ENCRYPTION_KEY` is a **simplification for the hackathon**. In production, trade parameters would be encrypted directly with the Vault DON's threshold public key, and decryption would use the DKG threshold protocol (not a symmetric key). The symmetric key approach demonstrates the same privacy properties for the demo.
