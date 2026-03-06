"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Button } from "@/components/ui/button";
import { useCreateTrade } from "@/hooks/useCreateTrade";
import { useChainGuard } from "@/hooks/useChainGuard";
import { TradeSuccess } from "@/components/trade/trade-success";
import { parseContractError } from "@/lib/errors";
import type { TradeParams } from "@/types/trade";

const SUPPORTED_ASSETS = [
  { value: "ETH", label: "ETH", isNative: true },
  { value: "USDC", label: "USDC", isNative: false },
];

const SUPPORTED_CHAINS = [
  { value: 11155111, label: "Sepolia" },
  { value: 421614, label: "Arbitrum Sepolia" },
];

function getButtonState(params: {
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
    return { label: "Enter offer amount", disabled: true };
  if (!params.wantAmount || params.wantAmount === "0")
    return { label: "Enter want amount", disabled: true };
  if (params.isApproving)
    return { label: "Approving token...", disabled: true };
  if (params.isApproved)
    return { label: "Now deposit", disabled: false };
  if (params.isDepositing)
    return { label: "Creating trade...", disabled: true };
  if (params.isPending)
    return { label: "Confirm in wallet...", disabled: true };
  return { label: "Create Trade", disabled: false };
}

const inputClasses =
  "h-10 w-full rounded-input border border-surface-border bg-white px-3 text-body text-gray-900 placeholder:text-gray-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500";

const selectClasses =
  "h-10 rounded-input border border-surface-border bg-white px-3 text-body text-gray-900 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500";

export function TradeForm() {
  const { isConnected } = useAccount();
  const { isSupported } = useChainGuard();
  const {
    createTrade,
    confirmDeposit,
    resetTrade,
    tradeId,
    matchingCode,
    isPending,
    isSuccess,
    isApproving,
    isApproved,
    isDepositing,
    error,
  } = useCreateTrade();

  const [formData, setFormData] = useState<TradeParams>({
    asset: "ETH",
    amount: "",
    wantAsset: "USDC",
    wantAmount: "",
    destinationChain: 11155111,
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!isConnected || !formData.amount) return;

    if (isApproved) {
      confirmDeposit();
    } else {
      createTrade(formData);
    }
  };

  const handleCreateAnother = () => {
    resetTrade();
    setFormData({
      asset: "ETH",
      amount: "",
      wantAsset: "USDC",
      wantAmount: "",
      destinationChain: 11155111,
    });
  };

  if (isSuccess && matchingCode && tradeId) {
    return (
      <TradeSuccess
        matchingCode={matchingCode}
        tradeId={tradeId}
        onCreateAnother={handleCreateAnother}
      />
    );
  }

  const buttonState = getButtonState({
    isConnected,
    isSupported,
    offerAmount: formData.amount,
    wantAmount: formData.wantAmount,
    isPending,
    isApproving,
    isApproved,
    isDepositing,
  });

  // Prevent same asset on both sides
  const wantAssets = SUPPORTED_ASSETS.filter((a) => a.value !== formData.asset);
  if (formData.wantAsset === formData.asset) {
    const newWant = wantAssets[0]?.value ?? "ETH";
    if (formData.wantAsset !== newWant) {
      setFormData((prev) => ({ ...prev, wantAsset: newWant }));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      {/* You Offer — this is what gets deposited into the vault */}
      <fieldset className="flex flex-col gap-3">
        <legend className="text-tiny font-medium uppercase tracking-wider text-gray-400">
          You Deposit
        </legend>
        <p className="text-tiny text-gray-400">
          This amount will be locked in the OTCVault escrow.
        </p>
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
              inputMode="decimal"
              placeholder="0.001"
              value={formData.amount}
              onChange={(e) =>
                setFormData((prev) => ({ ...prev, amount: e.target.value }))
              }
              className={inputClasses}
            />
          </div>
        </div>
      </fieldset>

      {/* Divider with swap icon */}
      <div className="flex items-center gap-3">
        <div className="h-px flex-1 bg-surface-border" />
        <span className="text-tiny text-gray-300">in exchange for</span>
        <div className="h-px flex-1 bg-surface-border" />
      </div>

      {/* You Want — encrypted, only visible to TEE */}
      <fieldset className="flex flex-col gap-3">
        <legend className="text-tiny font-medium uppercase tracking-wider text-gray-400">
          You Receive
        </legend>
        <p className="text-tiny text-gray-400">
          Encrypted on-chain. Only the TEE verifies these terms match.
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
              inputMode="decimal"
              placeholder="10.00"
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
      </fieldset>

      {/* Divider */}
      <div className="h-px bg-surface-border" />

      {/* Settlement Chain */}
      <div className="flex flex-col gap-1.5">
        <label className="text-small font-medium text-gray-600">
          Settlement Chain
        </label>
        <select
          value={formData.destinationChain}
          onChange={(e) =>
            setFormData((prev) => ({
              ...prev,
              destinationChain: Number(e.target.value),
            }))
          }
          className={selectClasses}
        >
          {SUPPORTED_CHAINS.map((c) => (
            <option key={c.value} value={c.value}>
              {c.label}
            </option>
          ))}
        </select>
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
          Token approved. Click &quot;Now deposit&quot; to create the trade.
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
