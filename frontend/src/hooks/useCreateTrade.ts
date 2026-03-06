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
import {
  encryptTradeParams,
  generateTradeId,
  generateMatchingCode,
} from "@/lib/encryption";
import type { TradeParams } from "@/types/trade";

type CreateStep = "idle" | "approving" | "approved" | "depositing";

function resolveToken(asset: string): { address: Address; decimals: number } | null {
  if (asset === "ETH") return null;
  const token = TOKENS[asset];
  if (!token) return null;
  return { address: token.address, decimals: token.decimals };
}

export function useCreateTrade() {
  const [tradeId, setTradeId] = useState<`0x${string}` | null>(null);
  const [matchingCode, setMatchingCode] = useState<string | null>(null);
  const [step, setStep] = useState<CreateStep>("idle");
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

  const createTrade = useCallback((params: TradeParams) => {
    const newTradeId = generateTradeId();
    const code = generateMatchingCode(newTradeId);

    setTradeId(newTradeId);
    setMatchingCode(code);

    if (params.asset === "ETH") {
      const encryptedParams = encryptTradeParams(params);
      setStep("depositing");
      writeContract({
        address: vaultAddress,
        abi: otcVaultAbi,
        functionName: "createTradeETH",
        args: [newTradeId, encryptedParams],
        value: parseUnits(params.amount, 18),
      });
      return;
    }

    // ERC-20 token flow: approve first
    const token = resolveToken(params.asset);
    if (!token) return;

    const amount = parseUnits(params.amount, token.decimals);

    setSavedParams(params);
    setStep("approving");

    writeContract({
      address: token.address,
      abi: erc20Abi,
      functionName: "approve",
      args: [vaultAddress, amount],
    });
  }, [vaultAddress, writeContract]);

  const confirmDeposit = useCallback(() => {
    if (!savedParams || !tradeId) return;

    const token = resolveToken(savedParams.asset);
    if (!token) return;

    const encryptedParams = encryptTradeParams(savedParams);
    const amount = parseUnits(savedParams.amount, token.decimals);

    reset();
    setStep("depositing");

    writeContract({
      address: vaultAddress,
      abi: otcVaultAbi,
      functionName: "createTradeToken",
      args: [tradeId, token.address, amount, encryptedParams],
    });
  }, [savedParams, tradeId, vaultAddress, writeContract, reset]);

  function resetTrade() {
    setTradeId(null);
    setMatchingCode(null);
    setStep("idle");
    setSavedParams(null);
    reset();
  }

  // Derive state
  const isApproving = step === "approving" && (isPending || isConfirming);
  const isApproved = step === "approving" && isSuccess;
  const isDepositing = step === "depositing" && (isPending || isConfirming);
  const isDone = step === "depositing" && isSuccess;

  return {
    createTrade,
    confirmDeposit,
    resetTrade,
    tradeId,
    matchingCode,
    hash,
    isPending: isPending || isConfirming,
    isApproving,
    isApproved,
    isDepositing,
    isSuccess: isDone,
    error,
  };
}
