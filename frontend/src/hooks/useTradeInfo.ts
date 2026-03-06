"use client";

import { useReadContract } from "wagmi";
import { sepolia } from "wagmi/chains";
import { otcVaultAbi } from "@/config/abis";
import { CONTRACT_ADDRESSES } from "@/config/contracts";
import { TradeStatus } from "@/types/trade";
import type { Trade } from "@/types/trade";

export function useTradeInfo(tradeId: `0x${string}` | null) {
  const vaultAddress = CONTRACT_ADDRESSES[sepolia.id].otcVault;

  const { data, isLoading, error, refetch } = useReadContract({
    address: vaultAddress,
    abi: otcVaultAbi,
    functionName: "getTrade",
    args: tradeId ? [tradeId] : undefined,
    query: {
      enabled: !!tradeId,
    },
  });

  const trade: Trade | null = data
    ? (data as unknown as Trade)
    : null;

  const status = trade ? (trade.status as TradeStatus) : TradeStatus.None;

  return {
    trade,
    status,
    isLoading,
    error,
    refetch,
  };
}
