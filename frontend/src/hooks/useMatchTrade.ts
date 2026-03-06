"use client";

import { useState, useCallback } from "react";
import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useAccount,
  useReadContract,
} from "wagmi";
import { parseUnits, type Address } from "viem";
import { sepolia } from "wagmi/chains";
import { otcVaultAbi } from "@/config/abis";
import { CONTRACT_ADDRESSES, TOKENS, erc20Abi } from "@/config/contracts";
import { encryptTradeParams } from "@/lib/encryption";
import type { TradeParams } from "@/types/trade";

type MatchStep = "idle" | "approving" | "approved" | "depositing";

function resolveToken(asset: string): { address: Address; decimals: number } | null {
  if (asset === "ETH") return null;
  const token = TOKENS[asset];
  if (!token) return null;
  return { address: token.address, decimals: token.decimals };
}

export function useMatchTrade() {
  const [step, setStep] = useState<MatchStep>("idle");
  const [savedTradeId, setSavedTradeId] = useState<`0x${string}` | null>(null);
  const [savedParams, setSavedParams] = useState<TradeParams | null>(null);

  const { address } = useAccount();
  const { writeContract, data: hash, isPending, error, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  const vaultAddress = CONTRACT_ADDRESSES[sepolia.id].otcVault;

  // Read allowance for current saved token
  const tokenForAllowance = savedParams ? resolveToken(savedParams.asset) : null;
  useReadContract({
    address: tokenForAllowance?.address,
    abi: erc20Abi,
    functionName: "allowance",
    args: address && tokenForAllowance ? [address, vaultAddress] : undefined,
    query: {
      enabled: !!tokenForAllowance && !!address,
      refetchInterval: step === "approved" ? 2000 : false,
    },
  });

  const matchTrade = useCallback((tradeId: `0x${string}`, params: TradeParams) => {
    const encryptedParams = encryptTradeParams(params);

    if (params.asset === "ETH") {
      setStep("depositing");
      writeContract({
        address: vaultAddress,
        abi: otcVaultAbi,
        functionName: "matchTradeETH",
        args: [tradeId, encryptedParams],
        value: parseUnits(params.amount, 18),
      });
      return;
    }

    // ERC-20 token flow
    const token = resolveToken(params.asset);
    if (!token) return;

    const amount = parseUnits(params.amount, token.decimals);

    // Save for after approval
    setSavedTradeId(tradeId);
    setSavedParams(params);

    // Always approve first for ERC-20
    setStep("approving");
    writeContract({
      address: token.address,
      abi: erc20Abi,
      functionName: "approve",
      args: [vaultAddress, amount],
    });
  }, [vaultAddress, writeContract]);

  const confirmDeposit = useCallback(() => {
    if (!savedParams || !savedTradeId) return;

    const token = resolveToken(savedParams.asset);
    if (!token) return;

    const encryptedParams = encryptTradeParams(savedParams);
    const amount = parseUnits(savedParams.amount, token.decimals);

    reset();
    setStep("depositing");

    writeContract({
      address: vaultAddress,
      abi: otcVaultAbi,
      functionName: "matchTradeToken",
      args: [savedTradeId, token.address, amount, encryptedParams],
    });
  }, [savedParams, savedTradeId, vaultAddress, writeContract, reset]);

  // Derive state
  const isApproving = step === "approving" && (isPending || isConfirming);
  const isApproved = step === "approving" && isSuccess;
  const isDepositing = step === "depositing" && (isPending || isConfirming);
  const isDone = step === "depositing" && isSuccess;

  return {
    matchTrade,
    confirmDeposit,
    hash,
    isPending: isPending || isConfirming,
    isApproving,
    isApproved,
    isDepositing,
    isSuccess: isDone,
    error,
    reset,
  };
}
