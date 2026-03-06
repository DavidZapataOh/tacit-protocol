import { type Address } from "viem";
import { sepolia, arbitrumSepolia } from "wagmi/chains";

// Deployed contract addresses (Sprint 4.3 — v2 with CCIP support)
export const CONTRACT_ADDRESSES = {
  [sepolia.id]: {
    otcVault: "0xdcf70165b005e00fFdf904BACE94A560bff26358" as Address,
    complianceRegistry: "0x58FCD94b1BB542fF728c9FC40a7BBfE2fFEa018e" as Address,
  },
  [arbitrumSepolia.id]: {
    otcVaultReceiver: "0xDBB75Cbdf99C03D585c2879BCbedF99eeD270aC7" as Address,
  },
} as const;

// CCIP chain selectors
export const CHAIN_SELECTORS = {
  [sepolia.id]: BigInt("16015286601757825753"),
  [arbitrumSepolia.id]: BigInt("3478487238524512106"),
} as const;

// Supported tokens on Sepolia
export interface TokenInfo {
  symbol: string;
  address: Address;
  decimals: number;
}

export const TOKENS: Record<string, TokenInfo> = {
  USDC: {
    symbol: "USDC",
    address: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238" as Address,
    decimals: 6,
  },
  LINK: {
    symbol: "LINK",
    address: "0x779877A7B0D9E8603169DdbD7836e478b4624789" as Address,
    decimals: 18,
  },
};

// Minimal ERC-20 ABI for approve + allowance
export const erc20Abi = [
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "allowance",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
] as const;
