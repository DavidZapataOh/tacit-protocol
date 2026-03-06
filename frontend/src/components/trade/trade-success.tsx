"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";

interface TradeSuccessProps {
  matchingCode: string;
  tradeId: `0x${string}`;
  onCreateAnother: () => void;
}

export function TradeSuccess({ matchingCode, tradeId, onCreateAnother }: TradeSuccessProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(matchingCode);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="flex flex-col items-center gap-6 py-8">
      {/* Success indicator */}
      <div className="flex h-14 w-14 items-center justify-center rounded-full bg-brand-50">
        <svg
          className="h-7 w-7 text-brand-600"
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

      <div className="text-center">
        <h2 className="text-subheading font-semibold text-gray-900">
          Trade Created
        </h2>
        <p className="mt-2 max-w-sm text-body text-gray-500">
          Your deposit is locked in the OTCVault. Share the matching code with
          your counterparty.
        </p>
      </div>

      {/* Matching Code */}
      <div className="w-full max-w-sm border-y border-surface-border py-6 text-center">
        <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
          Matching Code
        </p>
        <p className="mt-2 font-mono text-display font-bold tracking-wider text-gray-900">
          {matchingCode}
        </p>
        <Button
          onClick={handleCopy}
          variant="outline"
          className="mt-4 w-full"
        >
          {copied ? "Copied!" : "Copy Code"}
        </Button>
      </div>

      {/* Trade ID */}
      <div className="flex items-center gap-2 text-small text-gray-400">
        <span>Trade ID:</span>
        <code className="font-mono text-gray-500">
          {tradeId.slice(0, 10)}...{tradeId.slice(-8)}
        </code>
      </div>

      {/* Privacy notice */}
      <p className="max-w-sm text-center text-small text-gray-400">
        Your trade parameters are encrypted on-chain. Only the TEE can decrypt them.
      </p>

      {/* Actions */}
      <div className="flex gap-3">
        <Button variant="outline" asChild>
          <Link href={`/status/${tradeId}`}>Track Status</Link>
        </Button>
        <Button
          onClick={onCreateAnother}
          className="bg-brand-600 text-white hover:bg-brand-700"
        >
          Create Another
        </Button>
      </div>
    </div>
  );
}
