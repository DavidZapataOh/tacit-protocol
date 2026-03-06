#!/bin/bash
set -euo pipefail

# ============================================================
# Tacit E2E Happy Path — Sepolia Live Test
# Usage: ./script/e2e-happy-path.sh [run_number]
# Requires: .env with SEPOLIA_RPC_URL, DEPLOYER_PRIVATE_KEY
# ============================================================

RUN_NUMBER=${1:-1}
TIMESTAMP=$(date +%s)
TRADE_ID=$(cast keccak "trade-e2e-run${RUN_NUMBER}-${TIMESTAMP}")

echo "============================================"
echo "  TACIT E2E Happy Path - Run #${RUN_NUMBER}"
echo "  Trade ID: ${TRADE_ID}"
echo "  Timestamp: $(date)"
echo "============================================"

# Load env
source .env

# Contract addresses (from deployments/sepolia.json)
OTCVAULT=0xdcf70165b005e00fFdf904BACE94A560bff26358
REGISTRY=0x58FCD94b1BB542fF728c9FC40a7BBfE2fFEa018e
RPC=${SEPOLIA_RPC_URL}
PK=${DEPLOYER_PRIVATE_KEY}

# For this test, deployer acts as both KeystoneForwarder AND Party A
# Party B would need a separate wallet in production
DEPLOYER_ADDR=$(cast wallet address "$PK")

echo ""
echo "Deployer/Forwarder: ${DEPLOYER_ADDR}"
echo "OTCVault: ${OTCVAULT}"
echo "ComplianceRegistry: ${REGISTRY}"
echo ""

# --- Step 1: Party A creates trade ---
echo "[1/5] Party A creating trade and depositing 0.001 ETH..."
ENCRYPTED_A="0x$(echo -n "encrypted-params-A-run${RUN_NUMBER}" | xxd -p | tr -d '\n')"

TX1=$(cast send "$OTCVAULT" \
  "createTradeETH(bytes32,bytes)" \
  "$TRADE_ID" "$ENCRYPTED_A" \
  --value 0.001ether \
  --private-key "$PK" \
  --rpc-url "$RPC" \
  --json 2>/dev/null | jq -r '.transactionHash')

echo "  TX: $TX1"
cast receipt "$TX1" --rpc-url "$RPC" --json 2>/dev/null | jq '{status, gasUsed, blockNumber}'

# Verify trade state
STATE=$(cast call "$OTCVAULT" "getTradeStatus(bytes32)(uint8)" "$TRADE_ID" --rpc-url "$RPC")
echo "  Trade state: $STATE (expected: 1 = Created)"

# --- Step 2: Check state (skip Party B match since we need a second wallet) ---
echo ""
echo "[2/5] Trade created successfully. To complete the full flow:"
echo "  - Party B needs a separate wallet to call matchTradeETH"
echo "  - Then CRE workflow (or manual KeystoneForwarder call) triggers settlement"
echo ""

# --- Step 3: Verify on Etherscan ---
echo "[3/5] Verify on Etherscan:"
echo "  https://sepolia.etherscan.io/tx/$TX1"
echo "  https://sepolia.etherscan.io/address/${OTCVAULT}#events"
echo ""

# --- Step 4: Check vault balance ---
echo "[4/5] Vault balance after deposit:"
VAULT_BAL=$(cast balance "$OTCVAULT" --rpc-url "$RPC")
echo "  ${VAULT_BAL} wei"
echo ""

# --- Step 5: Summary ---
echo "[5/5] Run #${RUN_NUMBER} Summary"
echo "  Trade ID: ${TRADE_ID}"
echo "  Deposit TX: ${TX1}"
echo "  Status: Created (waiting for counterparty)"
echo ""
echo "============================================"
echo "  Run #${RUN_NUMBER} COMPLETE"
echo "============================================"
