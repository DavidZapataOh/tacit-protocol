"use client";

import { useState, useCallback } from "react";
import Link from "next/link";
import { MatchCodeCard } from "@/components/trade/match-code-input";
import { MatchTradeCard } from "@/components/trade/match-form";
import { useTradeInfo } from "@/hooks/useTradeInfo";
import { TradeStatus } from "@/types/trade";
import { Badge } from "@/components/ui/badge";
import { ChainWarning } from "@/components/wallet/chain-warning";

export default function MatchTradePage() {
  const [tradeId, setTradeId] = useState<`0x${string}` | null>(null);
  const [matched, setMatched] = useState(false);
  const { trade, status, isLoading, error } = useTradeInfo(tradeId);

  const handleTradeFound = (id: `0x${string}`) => {
    setTradeId(id);
    setMatched(false);
  };

  const handleBack = () => {
    setTradeId(null);
    setMatched(false);
  };

  const handleMatchSuccess = useCallback(() => {
    setMatched(true);
  }, []);

  // Error message for Phase 1
  const codeError =
    tradeId && !isLoading && error
      ? "Trade not found. Check the code and try again."
      : tradeId && !isLoading && trade && status === TradeStatus.None
        ? "No trade exists with this code."
        : null;

  // Success screen
  if (matched && tradeId) {
    return (
      <div className="flex flex-col gap-0">
        <div className="flex items-center gap-0 border-b border-surface-border pb-6">
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-brand-50">
            <svg
              className="h-6 w-6 text-gray-500"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth={2}
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M4.5 12.75l6 6 9-13.5"
              />
            </svg>
          </div>
          <div className="ml-5 flex items-center divide-x divide-surface-border">
            <div className="pr-6">
              <p className="text-2xl font-bold text-gray-900">Trade Matched</p>
              <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
                Status
              </p>
            </div>
            <div className="px-6 text-center">
              <Badge className="border-brand-200 bg-brand-50 text-brand-700">
                BothPartiesDeposited
              </Badge>
              <p className="mt-1 text-tiny font-medium uppercase tracking-wider text-gray-400">
                On-Chain
              </p>
            </div>
          </div>
        </div>

        <div className="pt-6">
          <p className="text-body text-gray-500">
            Both parties have deposited. The CRE workflow will now verify
            compliance and settle inside a TEE.
          </p>
          <div className="mt-4">
            <Link
              href="/explorer"
              className="rounded-button border border-surface-border px-4 py-2 text-small font-medium text-gray-600 transition-colors hover:border-brand-500 hover:text-brand-600"
            >
              View in Explorer
            </Link>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-0">
      <ChainWarning />

      {/* Stats bar */}
      <div className="flex items-center gap-0 border-b border-surface-border pb-6">
        <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-overlay">
          <svg
            className="h-6 w-6 text-gray-500"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={1.5}
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M7.5 21 3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5"
            />
          </svg>
        </div>
        <div className="ml-5">
          <p className="text-2xl font-bold text-gray-900">Match Trade</p>
          <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
            Enter the matching code from your counterparty
          </p>
        </div>
      </div>

      {/* Content */}
      <div className="grid grid-cols-1 gap-10 pt-6 lg:grid-cols-2">
        {/* Left: Form */}
        <div>
          <div className="mb-6 border-b border-surface-border pb-3">
            <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
              {!tradeId || !trade || status !== TradeStatus.Created
                ? "Find Trade"
                : "Deposit"}
            </h2>
          </div>

          {!tradeId || !trade || status !== TradeStatus.Created ? (
            <MatchCodeCard
              onTradeFound={handleTradeFound}
              isLoading={isLoading}
              error={codeError}
            />
          ) : (
            <MatchTradeCard
              tradeId={tradeId}
              trade={trade}
              onBack={handleBack}
              onSuccess={handleMatchSuccess}
            />
          )}

          {/* Already matched info */}
          {trade && !matched && status >= TradeStatus.BothDeposited && (
            <div className="mt-4 rounded-input border border-blue-200 bg-blue-50 px-4 py-3">
              <p className="text-small text-blue-700">
                This trade has already been matched.
              </p>
              <Link
                href="/explorer"
                className="mt-1 inline-block text-small font-medium text-brand-600 hover:text-brand-700"
              >
                View in Explorer
              </Link>
            </div>
          )}
        </div>

        {/* Right: Info */}
        <div>
          <div className="mb-6 border-b border-surface-border pb-3">
            <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
              Process
            </h2>
          </div>
          <div className="flex flex-col gap-0">
            {[
              {
                step: "1",
                title: "Enter Code",
                desc: "Paste the TACIT-XXXXXXXX code your counterparty shared with you.",
              },
              {
                step: "2",
                title: "Review Trade",
                desc: "Verify the trade details — creator address and timestamp.",
              },
              {
                step: "3",
                title: "Set Your Terms",
                desc: "Enter your offer and what you want. Parameters are encrypted before deposit.",
              },
              {
                step: "4",
                title: "Deposit",
                desc: "Confirm the transaction. Your funds are locked in the OTCVault.",
              },
            ].map((item, i) => (
              <div
                key={item.step}
                className={`flex gap-4 py-4 ${i < 3 ? "border-b border-surface-border" : ""}`}
              >
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-surface-overlay text-tiny font-bold text-gray-500">
                  {item.step}
                </span>
                <div>
                  <p className="text-body font-medium text-gray-900">
                    {item.title}
                  </p>
                  <p className="mt-0.5 text-small text-gray-500">
                    {item.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
