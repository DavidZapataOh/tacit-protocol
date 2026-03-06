"use client";

import { useState, useEffect, useRef } from "react";
import { TradeStatus } from "@/types/trade";

interface UseAutoSettleOptions {
  tradeId: `0x${string}`;
  onChainStatus: TradeStatus | undefined;
  hasAttestation: boolean;
}

interface SettleResult {
  isSettling: boolean;
  settleError: string | null;
  settleTx: string | null;
  attestTx: string | null;
}

/**
 * Automatically triggers settlement when a trade reaches BothDeposited.
 * Calls the /api/settle endpoint which executes the same on-chain writes
 * that the CRE Workflow DON would perform.
 *
 * Disabled when NEXT_PUBLIC_CRE_LIVE=true (real DON handles settlement).
 */
export function useAutoSettle({
  tradeId,
  onChainStatus,
  hasAttestation,
}: UseAutoSettleOptions): SettleResult {
  const [isSettling, setIsSettling] = useState(false);
  const [settleError, setSettleError] = useState<string | null>(null);
  const [settleTx, setSettleTx] = useState<string | null>(null);
  const [attestTx, setAttestTx] = useState<string | null>(null);
  const attemptedRef = useRef(false);

  useEffect(() => {
    // Don't settle if CRE DON is active
    if (process.env.NEXT_PUBLIC_CRE_LIVE === "true") return;

    // Only trigger when BothDeposited
    if (onChainStatus !== TradeStatus.BothDeposited) return;

    // Don't retry if already attempted
    if (attemptedRef.current) return;

    attemptedRef.current = true;
    setIsSettling(true);
    setSettleError(null);

    fetch("/api/settle", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tradeId }),
    })
      .then(async (res) => {
        const data = await res.json();
        if (!res.ok) {
          // If already settled, not an error
          if (data.settled) {
            setIsSettling(false);
            return;
          }
          throw new Error(data.error || "Settlement failed");
        }
        setSettleTx(data.settleTx);
        setAttestTx(data.attestTx);
        setIsSettling(false);
      })
      .catch((err) => {
        setSettleError(err.message);
        setIsSettling(false);
      });
  }, [tradeId, onChainStatus, hasAttestation]);

  return { isSettling, settleError, settleTx, attestTx };
}
