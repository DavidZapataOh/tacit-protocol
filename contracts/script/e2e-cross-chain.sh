#!/bin/bash
set -euo pipefail

# ============================================
#  TACIT Cross-Chain E2E Test Script
#  Chains: Sepolia <-> Arbitrum Sepolia
# ============================================
#
# Prerequisites:
#   - .env.e2e with PARTY_A_PRIVATE_KEY, PARTY_B_PRIVATE_KEY
#   - Deployed contracts (see deployments/*.json)
#   - Funded wallets on both chains (>0.1 ETH each)
#
# Usage:
#   ./script/e2e-cross-chain.sh [run_number]

RUN_NUMBER=${1:-1}
TIMESTAMP=$(date +%s)

echo "============================================"
echo "  TACIT Cross-Chain E2E - Run #${RUN_NUMBER}"
echo "  Chains: Sepolia <-> Arbitrum Sepolia"
echo "  Timestamp: $(date)"
echo "============================================"

cd /mnt/d/chainlink/contracts
source .env.e2e

# Load deployment addresses
OTCVAULT_SEPOLIA=$(jq -r '.OTCVault' deployments/sepolia.json)
COMPLIANCE_SEPOLIA=$(jq -r '.ComplianceRegistry' deployments/sepolia.json)
RECEIVER_ARB=$(jq -r '.OTCVaultReceiver' deployments/arbitrum-sepolia.json)

echo ""
echo "Contracts:"
echo "  OTCVault (Sepolia):      $OTCVAULT_SEPOLIA"
echo "  ComplianceReg (Sepolia): $COMPLIANCE_SEPOLIA"
echo "  Receiver (Arb Sepolia):  $RECEIVER_ARB"

TRADE_ID=$(cast keccak "xchain-run${RUN_NUMBER}-${TIMESTAMP}")
echo ""
echo "Trade ID: $TRADE_ID"

# === Step 1: Party A deposits on Sepolia ===
echo ""
echo "[1/5] Party A depositing 0.005 ETH on Sepolia..."
TX_A=$(cast send "$OTCVAULT_SEPOLIA" \
  "createTradeETH(bytes32,bytes)" \
  "$TRADE_ID" "0x$(echo -n "xchain-A-run${RUN_NUMBER}" | xxd -p)" \
  --value 0.005ether \
  --private-key "$PARTY_A_PRIVATE_KEY" \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --json | jq -r '.transactionHash')
echo "  TX: $TX_A"
echo "  Etherscan: https://sepolia.etherscan.io/tx/$TX_A"

# Check trade was created
STATE=$(cast call "$OTCVAULT_SEPOLIA" "getTradeStatus(bytes32)(uint8)" "$TRADE_ID" --rpc-url "$SEPOLIA_RPC_URL")
echo "  Trade status: $STATE (1=Created)"

# === Step 2: Party B matches on Sepolia ===
echo ""
echo "[2/5] Party B matching with 0.003 ETH on Sepolia..."
TX_B=$(cast send "$OTCVAULT_SEPOLIA" \
  "matchTradeETH(bytes32,bytes)" \
  "$TRADE_ID" "0x$(echo -n "xchain-B-run${RUN_NUMBER}" | xxd -p)" \
  --value 0.003ether \
  --private-key "$PARTY_B_PRIVATE_KEY" \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --json | jq -r '.transactionHash')
echo "  TX: $TX_B"
echo "  Etherscan: https://sepolia.etherscan.io/tx/$TX_B"

STATE=$(cast call "$OTCVAULT_SEPOLIA" "getTradeStatus(bytes32)(uint8)" "$TRADE_ID" --rpc-url "$SEPOLIA_RPC_URL")
echo "  Trade status: $STATE (2=BothDeposited)"

# === Step 3: CRE Workflow (simulated) ===
echo ""
echo "[3/5] CRE Workflow processing..."
echo "  Workflow detects BothPartiesDeposited event"
echo "  TEE: decrypt params, match, sanctions PASS, KYC PASS"
echo "  (In production: cre workflow simulate ./tacit-settlement -T local-simulation)"

# === Step 4: Verify balances ===
echo ""
echo "[4/5] Checking balances..."
echo "  Party A balance (Sepolia):"
cast balance "$(cast wallet address --private-key "$PARTY_A_PRIVATE_KEY")" --rpc-url "$SEPOLIA_RPC_URL"
echo "  Party B balance (Sepolia):"
cast balance "$(cast wallet address --private-key "$PARTY_B_PRIVATE_KEY")" --rpc-url "$SEPOLIA_RPC_URL"

# === Step 5: Summary ===
echo ""
echo "[5/5] Waiting for CRE + CCIP processing..."
echo "  CCIP Explorer: https://ccip.chain.link"
echo "  Expected latency: 5-20 minutes for cross-chain settlement"

echo ""
echo "============================================"
echo "  Run #${RUN_NUMBER} INITIATED"
echo "  Trade ID:    $TRADE_ID"
echo "  Deposit TX:  $TX_A"
echo "  Match TX:    $TX_B"
echo "  Monitor:     https://ccip.chain.link"
echo "============================================"
