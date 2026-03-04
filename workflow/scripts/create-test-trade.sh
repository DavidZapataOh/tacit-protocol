#!/bin/bash
# ============================================================
# Create Test Trade on Sepolia
# ============================================================
#
# Creates a test trade on Sepolia using the Foundry script,
# generating a BothPartiesDeposited event for CRE workflow.
#
# Usage:
#   ./scripts/create-test-trade.sh happy       # Settlement path
#   ./scripts/create-test-trade.sh mismatch    # Match failure → refund
#   ./scripts/create-test-trade.sh sanctions   # Sanctions failure → refund
#
# Prerequisites:
#   - Foundry installed
#   - contracts/.env with DEPLOYER_PRIVATE_KEY and PARTY_B_PRIVATE_KEY
#   - Both accounts have Sepolia ETH (>0.01 ETH each)
#   - OTCVault deployed on Sepolia
#
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/../../contracts" && pwd)"
SCENARIO="${1:-happy}"

# Map scenario name to Foundry function
case "$SCENARIO" in
    happy)
        FUNC="happyPath()"
        DESC="Happy path (settlement)"
        ;;
    mismatch)
        FUNC="mismatchPath()"
        DESC="Parameter mismatch (refund)"
        ;;
    sanctions)
        FUNC="sanctionsPath()"
        DESC="Sanctions failure (refund)"
        ;;
    crosschain)
        FUNC="crossChainPath()"
        DESC="Cross-chain DvP (CCIP to Arb Sepolia)"
        ;;
    *)
        echo "Unknown scenario: $SCENARIO"
        echo "Available: happy, mismatch, sanctions, crosschain"
        exit 1
        ;;
esac

echo "============================================================"
echo "  CREATE TEST TRADE — ${DESC}"
echo "  Scenario: ${SCENARIO}"
echo "============================================================"
echo ""

cd "$CONTRACTS_DIR"

# Load contracts .env
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

echo "Running: forge script script/CreateTestTrade.s.sol --sig \"${FUNC}\" --rpc-url sepolia --broadcast"
echo ""

forge script "script/CreateTestTrade.s.sol" \
    --sig "${FUNC}" \
    --rpc-url sepolia \
    --broadcast \
    -vvv

echo ""
echo "============================================================"
echo "  Trade created! BothPartiesDeposited event emitted."
echo "  Now run: cd workflow && npm run simulate"
echo "============================================================"
