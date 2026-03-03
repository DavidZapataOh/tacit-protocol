import { type Address } from "viem";
import { sepolia, arbitrumSepolia } from "wagmi/chains";

// Placeholder addresses — will be updated after Sprint 1.6 deploy
export const CONTRACT_ADDRESSES = {
  [sepolia.id]: {
    otcVault: "0x0000000000000000000000000000000000000000" as Address,
    complianceRegistry: "0x0000000000000000000000000000000000000000" as Address,
  },
  [arbitrumSepolia.id]: {
    otcVault: "0x0000000000000000000000000000000000000000" as Address,
    complianceRegistry: "0x0000000000000000000000000000000000000000" as Address,
  },
} as const;

// CCIP chain selectors
export const CHAIN_SELECTORS = {
  [sepolia.id]: BigInt("16015286601757825753"),
  [arbitrumSepolia.id]: BigInt("3478487238524512106"),
} as const;
