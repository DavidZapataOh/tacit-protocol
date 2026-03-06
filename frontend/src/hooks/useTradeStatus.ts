"use client";

import { useReadContract } from "wagmi";
import { sepolia } from "wagmi/chains";
import { otcVaultAbi, complianceRegistryAbi } from "@/config/abis";
import { CONTRACT_ADDRESSES } from "@/config/contracts";
import { TradeStatus } from "@/types/trade";
import type { Trade, Attestation } from "@/types/trade";

export enum WorkflowStep {
  Deposited = 0,
  ParameterMatch = 1,
  SanctionsCheck = 2,
  KYCCheck = 3,
  Settlement = 4,
  Attestation = 5,
}

export type StepStatus = "pending" | "active" | "done" | "failed";

export interface StepInfo {
  step: WorkflowStep;
  label: string;
  description: string;
  status: StepStatus;
  service: string;
}

export interface TradeStatusData {
  tradeId: `0x${string}`;
  onChainStatus: TradeStatus;
  complianceVerified: boolean | null;
  complianceTimestamp: bigint | null;
  currentStep: WorkflowStep;
  steps: StepInfo[];
  isSettled: boolean;
  isRefunded: boolean;
  isCrossChainPending: boolean;
}

const POLL_INTERVAL = 5000;

export function useTradeStatus(tradeId: `0x${string}`) {
  const vaultAddress = CONTRACT_ADDRESSES[sepolia.id].otcVault;
  const registryAddress = CONTRACT_ADDRESSES[sepolia.id].complianceRegistry;

  const { data: tradeData, isLoading: tradeLoading } = useReadContract({
    address: vaultAddress,
    abi: otcVaultAbi,
    functionName: "getTrade",
    args: [tradeId],
    query: {
      refetchInterval: POLL_INTERVAL,
    },
  });

  const { data: attestationData, isLoading: attestationLoading } =
    useReadContract({
      address: registryAddress,
      abi: complianceRegistryAbi,
      functionName: "getAttestation",
      args: [tradeId],
      query: {
        refetchInterval: POLL_INTERVAL,
      },
    });

  const statusData = deriveTradeStatus(
    tradeId,
    tradeData as unknown as Trade | undefined,
    attestationData as unknown as Attestation | undefined
  );

  return {
    statusData,
    isLoading: tradeLoading || attestationLoading,
  };
}

function deriveTradeStatus(
  tradeId: `0x${string}`,
  trade: Trade | undefined,
  attestation: Attestation | undefined
): TradeStatusData | null {
  if (!trade) return null;

  const onChainStatus = trade.status as TradeStatus;
  const hasAttestation = attestation?.exists ?? false;
  const complianceVerified = hasAttestation ? attestation!.verified : null;
  const complianceTimestamp = hasAttestation ? attestation!.timestamp : null;

  const isSettled = onChainStatus === TradeStatus.Settled;
  const isRefunded = onChainStatus === TradeStatus.Refunded;
  const isCrossChainPending = onChainStatus === TradeStatus.CrossChainPending;
  const isBothDeposited = onChainStatus >= TradeStatus.BothDeposited;
  const isFinalState = isSettled || isRefunded;

  // Determine current active step from on-chain state
  let currentStep: WorkflowStep;
  if (!isBothDeposited) {
    currentStep = WorkflowStep.Deposited;
  } else if (isFinalState && hasAttestation) {
    // Everything done
    currentStep = WorkflowStep.Attestation;
  } else if (isFinalState || isCrossChainPending) {
    // Settled/refunded but attestation may still be recording
    currentStep = WorkflowStep.Attestation;
  } else if (hasAttestation) {
    // Compliance done, settlement in progress
    currentStep = WorkflowStep.Settlement;
  } else {
    // BothDeposited, CRE workflow processing
    // Show sanctions check as active (most visual for demo)
    currentStep = WorkflowStep.SanctionsCheck;
  }

  const complianceDone = hasAttestation;
  const complianceFailed = hasAttestation && !complianceVerified;

  const steps: StepInfo[] = [
    {
      step: WorkflowStep.Deposited,
      label: "Both Deposited",
      description:
        "Both parties have deposited encrypted assets into the OTCVault",
      status: isBothDeposited ? "done" : onChainStatus === TradeStatus.Created ? "active" : "pending",
      service: "EVM Write",
    },
    {
      step: WorkflowStep.ParameterMatch,
      label: "Parameter Match",
      description:
        "TEE is decrypting and verifying that trade terms match bilaterally",
      status: stepStatus(WorkflowStep.ParameterMatch, currentStep, isBothDeposited, complianceFailed),
      service: "Confidential Compute",
    },
    {
      step: WorkflowStep.SanctionsCheck,
      label: "Sanctions Check",
      description:
        "Confidential HTTP call to OFAC SDN sanctions screening API",
      status: complianceFailed && currentStep <= WorkflowStep.SanctionsCheck
        ? "failed"
        : stepStatus(WorkflowStep.SanctionsCheck, currentStep, complianceDone || isFinalState, false),
      service: "Confidential HTTP",
    },
    {
      step: WorkflowStep.KYCCheck,
      label: "KYC Verification",
      description:
        "Confidential HTTP call to KYC/accreditation verification API",
      status: complianceFailed && currentStep <= WorkflowStep.KYCCheck
        ? "failed"
        : stepStatus(WorkflowStep.KYCCheck, currentStep, complianceDone || isFinalState, false),
      service: "Vault DON",
    },
    {
      step: WorkflowStep.Settlement,
      label: "Settlement",
      description: isSettled
        ? "Atomic DvP settlement executed successfully"
        : isCrossChainPending
          ? "Cross-chain settlement via CCIP in progress"
          : isRefunded
            ? "Both parties refunded to original addresses"
            : "Executing atomic Delivery vs. Payment settlement",
      status: isSettled || isCrossChainPending
        ? "done"
        : isRefunded
          ? "failed"
          : currentStep === WorkflowStep.Settlement
            ? "active"
            : "pending",
      service: "CCIP",
    },
    {
      step: WorkflowStep.Attestation,
      label: "Attestation",
      description: hasAttestation
        ? `Compliance attestation recorded: ${complianceVerified ? "PASS" : "FAIL"}`
        : "Recording compliance attestation on-chain",
      status: hasAttestation ? "done" : isFinalState ? "active" : "pending",
      service: "EVM Write",
    },
  ];

  return {
    tradeId,
    onChainStatus,
    complianceVerified,
    complianceTimestamp,
    currentStep,
    steps,
    isSettled,
    isRefunded,
    isCrossChainPending,
  };
}

function stepStatus(
  step: WorkflowStep,
  currentStep: WorkflowStep,
  isDone: boolean,
  isFailed: boolean
): StepStatus {
  if (isFailed) return "failed";
  if (isDone || step < currentStep) return "done";
  if (step === currentStep) return "active";
  return "pending";
}
