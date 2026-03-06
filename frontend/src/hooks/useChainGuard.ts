"use client";

import { useAccount, useSwitchChain } from "wagmi";
import { sepolia, arbitrumSepolia } from "wagmi/chains";

const SUPPORTED_CHAIN_IDS = [sepolia.id, arbitrumSepolia.id] as const;

export function useChainGuard() {
  const { chainId, isConnected } = useAccount();
  const { switchChain, isPending: isSwitching } = useSwitchChain();

  const isSupported =
    !isConnected || (chainId !== undefined && SUPPORTED_CHAIN_IDS.includes(chainId as typeof SUPPORTED_CHAIN_IDS[number]));

  const switchToSepolia = () => switchChain({ chainId: sepolia.id });

  return {
    chainId,
    isConnected,
    isSupported,
    isSwitching,
    switchToSepolia,
  };
}
