"use client";

import { useReadContract } from "wagmi";
import { sepolia } from "wagmi/chains";
import { complianceRegistryAbi } from "@/config/abis";
import { CONTRACT_ADDRESSES } from "@/config/contracts";

export interface AttestationEntry {
  tradeId: `0x${string}`;
  verified: boolean;
  timestamp: bigint;
}

const POLL_INTERVAL = 10000;
const PAGE_SIZE = 20;

export function useAttestations() {
  const registryAddress = CONTRACT_ADDRESSES[sepolia.id].complianceRegistry;

  // Step 1: Read total attestation count
  const { data: countRaw } = useReadContract({
    address: registryAddress,
    abi: complianceRegistryAbi,
    functionName: "attestationCount",
    query: {
      refetchInterval: POLL_INTERVAL,
    },
  });

  const totalCount = countRaw ? Number(countRaw as bigint) : 0;

  // Step 2: Read trade IDs (most recent PAGE_SIZE)
  const offset = totalCount > PAGE_SIZE ? totalCount - PAGE_SIZE : 0;
  const limit = Math.min(totalCount, PAGE_SIZE);

  const { data: tradeIdsRaw } = useReadContract({
    address: registryAddress,
    abi: complianceRegistryAbi,
    functionName: "getAttestedTradeIds",
    args: [BigInt(offset), BigInt(limit)],
    query: {
      enabled: totalCount > 0,
      refetchInterval: POLL_INTERVAL,
    },
  });

  const tradeIds = (tradeIdsRaw as `0x${string}`[] | undefined) ?? [];

  // Step 3: Read attestation data for those trade IDs
  const { data: attestationsRaw, isLoading, error } = useReadContract({
    address: registryAddress,
    abi: complianceRegistryAbi,
    functionName: "getAttestationsBatch",
    args: [tradeIds],
    query: {
      enabled: tradeIds.length > 0,
      refetchInterval: POLL_INTERVAL,
    },
  });

  // Combine trade IDs with attestation data
  const attestations: AttestationEntry[] = [];
  if (attestationsRaw && tradeIds.length > 0) {
    const raw = attestationsRaw as Array<{
      verified: boolean;
      exists: boolean;
      timestamp: bigint;
    }>;
    for (let i = 0; i < tradeIds.length; i++) {
      if (raw[i] && raw[i].exists) {
        attestations.push({
          tradeId: tradeIds[i],
          verified: raw[i].verified,
          timestamp: raw[i].timestamp,
        });
      }
    }
    // Show newest first
    attestations.reverse();
  }

  return {
    attestations,
    totalCount,
    isLoading: isLoading || (totalCount > 0 && tradeIds.length === 0),
    error,
  };
}
