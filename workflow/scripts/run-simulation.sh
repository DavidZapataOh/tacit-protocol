#!/bin/bash
# ============================================================
# Tacit Settlement Workflow — CRE Simulation Runner
# ============================================================
#
# Orchestrates the full CRE workflow simulation:
#   1. Type-check TypeScript sources
#   2. Compile WASM via CRE CLI
#   3. Run simulation and capture output
#
# Usage:
#   ./scripts/run-simulation.sh                              # Interactive mode (CRE prompts for trigger)
#   ./scripts/run-simulation.sh --tx 0xabc...123             # Non-interactive with specific tx hash
#   ./scripts/run-simulation.sh --tx 0xabc...123 testnet     # Non-interactive with testnet target
#
# Prerequisites:
#   - CRE CLI installed (`cre` in PATH)
#   - Bun installed (for WASM compilation)
#   - `bun install` run in tacit-settlement/
#   - `.env` file with secrets in workflow/
#   - Must run from workflow/ directory (where project.yaml lives)
#
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_DIR="$(cd "$SCRIPT_DIR/../tacit-settlement" && pwd)"
WORKFLOW_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
TX_HASH=""
TARGET="local-simulation"

while [[ $# -gt 0 ]]; do
    case $1 in
        --tx)
            TX_HASH="$2"
            shift 2
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="$WORKFLOW_ROOT/simulation-output"
OUTPUT_FILE="${OUTPUT_DIR}/simulation_${TARGET}_${TIMESTAMP}.log"

echo "============================================================"
echo "  TACIT SETTLEMENT WORKFLOW — CRE SIMULATION"
echo "  Target:    ${TARGET}"
echo "  Workflow:  ${WORKFLOW_DIR}"
if [ -n "$TX_HASH" ]; then
echo "  Tx Hash:   ${TX_HASH}"
echo "  Mode:      non-interactive"
else
echo "  Mode:      interactive (CRE will prompt for trigger)"
fi
echo "  Timestamp: $(date -Iseconds)"
echo "============================================================"
echo ""

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Type check
echo "[1/2] Running TypeScript type check..."
cd "$WORKFLOW_DIR"
bun x tsc --noEmit
echo "      Type check passed."
echo ""

# Build CRE simulate command
CRE_CMD="cre workflow simulate ./tacit-settlement -T ${TARGET} -e .env"
if [ -n "$TX_HASH" ]; then
    CRE_CMD="${CRE_CMD} --non-interactive --trigger-index 0 --evm-event-index 0 --evm-tx-hash ${TX_HASH}"
fi

# Run CRE simulation
echo "[2/2] Starting CRE workflow simulation..."
echo "      Command: ${CRE_CMD}"
echo "============================================================"
echo ""

cd "$WORKFLOW_ROOT"
eval "${CRE_CMD}" 2>&1 | tee "${OUTPUT_FILE}"

EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "============================================================"
if [ ${EXIT_CODE} -eq 0 ]; then
    echo "  SIMULATION COMPLETED SUCCESSFULLY"
else
    echo "  SIMULATION FAILED (exit code: ${EXIT_CODE})"
fi
echo "  Output saved to: ${OUTPUT_FILE}"
echo "============================================================"

exit ${EXIT_CODE}
