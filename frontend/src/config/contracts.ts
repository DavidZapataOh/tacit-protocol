import { type Address } from "viem";
import { sepolia, arbitrumSepolia } from "wagmi/chains";

// Deployed contract addresses (Sprint 1.6 — Sepolia deploy 2026-03-03)
export const CONTRACT_ADDRESSES = {
  [sepolia.id]: {
    otcVault: "0xEC3ad86Ce60c09997Dfb2a644E32F1F3f5B9aD9c" as Address,
    complianceRegistry: "0xfc95bF700bb50B0E92F73b34E2fe52A027CC2147" as Address,
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
