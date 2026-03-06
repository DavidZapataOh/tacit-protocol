"use client";

import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { useMatchTrade } from "@/hooks/useMatchTrade";
import { useChainGuard } from "@/hooks/useChainGuard";
import { parseContractError } from "@/lib/errors";
import { TradeStatus } from "@/types/trade";
import type { Trade, TradeParams } from "@/types/trade";

const SUPPORTED_ASSETS = [
  { value: "ETH", label: "ETH" },
  { value: "USDC", label: "USDC" },
];

const STATUS_LABELS: Record<number, { label: string; className: string }> = {
  [TradeStatus.Created]: {
    label: "Waiting for Match",
    className: "border-brand-200 bg-brand-50 text-brand-700",
  },
  [TradeStatus.BothDeposited]: {
    label: "Both Deposited",
    className: "border-blue-200 bg-blue-50 text-blue-700",
  },
  [TradeStatus.Settled]: {
    label: "Settled",
    className: "border-green-200 bg-green-50 text-green-700",
  },
  [TradeStatus.Refunded]: {
    label: "Refunded",
    className: "border-orange-200 bg-orange-50 text-orange-700",
  },
  [TradeStatus.CrossChainPending]: {
    label: "Cross-Chain Pending",
    className: "border-brand-200 bg-brand-50 text-brand-700",
  },
};

function truncateAddress(addr: string): string {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function formatTimestamp(timestamp: bigint): string {
  return new Date(Number(timestamp) * 1000).toLocaleString();
}

function getMatchButtonState(params: {
  isConnected: boolean;
  isSupported: boolean;
  offerAmount: string;
  wantAmount: string;
  isPending: boolean;
  isApproving: boolean;
  isApproved: boolean;
  isDepositing: boolean;
}): { label: string; disabled: boolean } {
  if (!params.isConnected) return { label: "Connect Wallet", disabled: true };
  if (!params.isSupported) return { label: "Switch to Sepolia", disabled: true };
  if (!params.offerAmount || params.offerAmount === "0")
    return { label: "Enter your deposit amount", disabled: true };
  if (!params.wantAmount || params.wantAmount === "0")
    return { label: "Enter what you receive", disabled: true };
  if (params.isApproving)
    return { label: "Approving USDC...", disabled: true };
  if (params.isApproved)
    return { label: "Now deposit", disabled: false };
  if (params.isDepositing)
    return { label: "Matching trade...", disabled: true };
  if (params.isPending)
    return { label: "Confirm in wallet...", disabled: true };
  return { label: "Match Trade", disabled: false };
}

const inputClasses =
  "h-10 w-full rounded-input border border-surface-border bg-white px-3 text-body text-gray-900 placeholder:text-gray-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500";

const selectClasses =
  "h-10 rounded-input border border-surface-border bg-white px-3 text-body text-gray-900 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500";

interface MatchTradeCardProps {
  tradeId: `0x${string}`;
  trade: Trade;
  onBack: () => void;
  onSuccess: () => void;
}

export function MatchTradeCard({
  tradeId,
  trade,
  onBack,
  onSuccess,
}: MatchTradeCardProps) {
  const { isConnected } = useAccount();
  const { isSupported } = useChainGuard();
  const {
    matchTrade,
    confirmDeposit,
    isPending,
    isSuccess,
    isApproving,
    isApproved,
    isDepositing,
    error,
  } = useMatchTrade();

  const [formData, setFormData] = useState<TradeParams>({
    asset: "USDC",
    amount: "",
    wantAsset: "ETH",
    wantAmount: "",
    destinationChain: 11155111,
  });

  useEffect(() => {
    if (isSuccess) onSuccess();
  }, [isSuccess, onSuccess]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!isConnected || !formData.amount) return;

    if (isApproved) {
      confirmDeposit();
    } else {
      matchTrade(tradeId, formData);
    }
  };

  const statusInfo = STATUS_LABELS[trade.status] ?? {
    label: "Unknown",
    className: "border-gray-200 bg-gray-50 text-gray-600",
  };

  // Prevent same asset on both sides
  const wantAssets = SUPPORTED_ASSETS.filter((a) => a.value !== formData.asset);
  if (formData.wantAsset === formData.asset) {
    const newWant = wantAssets[0]?.value ?? "ETH";
    if (formData.wantAsset !== newWant) {
      setFormData((prev) => ({ ...prev, wantAsset: newWant }));
    }
  }

  const buttonState = getMatchButtonState({
    isConnected,
    isSupported,
    offerAmount: formData.amount,
    wantAmount: formData.wantAmount,
    isPending,
    isApproving,
    isApproved,
    isDepositing,
  });

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      {/* Header with back button */}
      <div className="flex items-center justify-between">
        <button
          type="button"
          onClick={onBack}
          className="flex items-center gap-1 text-small text-gray-500 hover:text-gray-900"
        >
          <svg
            className="h-3.5 w-3.5"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={2}
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18"
            />
          </svg>
          Different trade
        </button>
        <Badge variant="outline" className={statusInfo.className}>
          {statusInfo.label}
        </Badge>
      </div>

      {/* Trade info */}
      <div className="grid grid-cols-2 gap-3 rounded-input border border-surface-border bg-surface px-4 py-3">
        <div>
          <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
            Created by
          </p>
          <p className="mt-0.5 font-mono text-small text-gray-700">
            {truncateAddress(trade.partyA.depositor)}
          </p>
        </div>
        <div>
          <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
            Created
          </p>
          <p className="mt-0.5 text-small text-gray-700">
            {formatTimestamp(trade.createdAt)}
          </p>
        </div>
      </div>

      {/* Divider */}
      <div className="h-px bg-surface-border" />

      {/* Your Side label */}
      <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
        Your deposit (locked in escrow)
      </p>

      {/* You Deposit */}
      <div className="flex gap-3">
        <div className="flex flex-col gap-1.5">
          <label className="text-small font-medium text-gray-600">
            Asset
          </label>
          <select
            value={formData.asset}
            onChange={(e) =>
              setFormData((prev) => ({ ...prev, asset: e.target.value }))
            }
            className={selectClasses}
          >
            {SUPPORTED_ASSETS.map((a) => (
              <option key={a.value} value={a.value}>
                {a.label}
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-1 flex-col gap-1.5">
          <label className="text-small font-medium text-gray-600">
            Amount
          </label>
          <input
            type="number"
            step="any"
            min="0"
            placeholder="10.00"
            value={formData.amount}
            onChange={(e) =>
              setFormData((prev) => ({ ...prev, amount: e.target.value }))
            }
            className={inputClasses}
          />
        </div>
      </div>

      <div className="flex items-center gap-3">
        <div className="h-px flex-1 bg-surface-border" />
        <span className="text-tiny text-gray-300">in exchange for</span>
        <div className="h-px flex-1 bg-surface-border" />
      </div>

      {/* You Receive (encrypted) */}
      <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
        You receive (encrypted, verified by TEE)
      </p>
      <div className="flex gap-3">
        <div className="flex flex-col gap-1.5">
          <label className="text-small font-medium text-gray-600">
            Asset
          </label>
          <select
            value={formData.wantAsset}
            onChange={(e) =>
              setFormData((prev) => ({
                ...prev,
                wantAsset: e.target.value,
              }))
            }
            className={selectClasses}
          >
            {wantAssets.map((a) => (
              <option key={a.value} value={a.value}>
                {a.label}
              </option>
            ))}
          </select>
        </div>
        <div className="flex flex-1 flex-col gap-1.5">
          <label className="text-small font-medium text-gray-600">
            Amount
          </label>
          <input
            type="number"
            step="any"
            min="0"
            placeholder="0.001"
            value={formData.wantAmount}
            onChange={(e) =>
              setFormData((prev) => ({
                ...prev,
                wantAmount: e.target.value,
              }))
            }
            className={inputClasses}
          />
        </div>
      </div>

      {/* CTA Button */}
      <Button
        type="submit"
        disabled={buttonState.disabled}
        className="h-11 rounded-button bg-brand-600 text-body font-medium text-white hover:bg-brand-700 disabled:bg-brand-50 disabled:text-brand-300"
      >
        {buttonState.label}
      </Button>

      {/* Approval notice */}
      {isApproved && (
        <p className="text-center text-small text-brand-600">
          Token approved. Click &quot;Now deposit&quot; to match the trade.
        </p>
      )}

      {/* Error display */}
      {error && (
        <p className="text-small text-status-error">
          {parseContractError(error)}
        </p>
      )}
    </form>
  );
}
