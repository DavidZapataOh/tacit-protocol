"use client";

import { useParams } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { WorkflowStepper } from "@/components/trade/workflow-stepper";
import { useTradeStatus } from "@/hooks/useTradeStatus";
import { useAutoSettle } from "@/hooks/useAutoSettle";
import type { TradeStatusData } from "@/hooks/useTradeStatus";

export default function TradeStatusPage() {
  const params = useParams();
  const tradeId = params.tradeId as `0x${string}`;
  const { statusData, isLoading } = useTradeStatus(tradeId);
  const { isSettling, settleError } = useAutoSettle({
    tradeId,
    onChainStatus: statusData?.onChainStatus,
    hasAttestation: statusData?.complianceVerified !== null,
  });

  if (isLoading || !statusData) {
    return <StatusSkeleton />;
  }

  return (
    <div className="flex flex-col gap-0">
      {/* Stats bar */}
      <div className="flex items-center gap-0 border-b border-surface-border pb-6">
        <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-overlay">
          <svg
            className="h-6 w-6 text-gray-500"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={1.5}
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M7.5 21 3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5"
            />
          </svg>
        </div>
        <div className="ml-5 flex items-center divide-x divide-surface-border">
          <div className="pr-6">
            <p className="font-mono text-body font-medium text-gray-900">
              {tradeId.slice(0, 10)}...{tradeId.slice(-6)}
            </p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Trade ID
            </p>
          </div>
          <div className="px-6 text-center">
            <OverallStatusBadge data={statusData} />
            <p className="mt-1 text-tiny font-medium uppercase tracking-wider text-gray-400">
              Status
            </p>
          </div>
          {statusData.complianceTimestamp && (
            <div className="px-6 text-center">
              <p className="text-body font-medium text-gray-900">
                {new Date(Number(statusData.complianceTimestamp) * 1000).toLocaleDateString()}
              </p>
              <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
                Compliance Date
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Settlement progress */}
      {isSettling && (
        <div className="flex items-center gap-3 rounded-input border border-brand-200 bg-brand-50 px-4 py-3">
          <div className="h-4 w-4 animate-spin rounded-full border-2 border-brand-600 border-t-transparent" />
          <p className="text-small text-brand-700">
            CRE Workflow executing: compliance check + settlement...
          </p>
        </div>
      )}
      {settleError && (
        <div className="rounded-input border border-red-200 bg-red-50 px-4 py-3">
          <p className="text-small text-red-700">Settlement error: {settleError}</p>
        </div>
      )}

      {/* Two-column layout */}
      <div className="grid grid-cols-1 gap-10 pt-6 lg:grid-cols-2">
        {/* Left: Workflow */}
        <div>
          <div className="mb-5 flex items-center justify-between border-b border-surface-border pb-3">
            <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
              Settlement Workflow
            </h2>
            <span className="text-tiny text-gray-400">
              Chainlink CRE + Confidential Compute
            </span>
          </div>
          <WorkflowStepper steps={statusData.steps} />
        </div>

        {/* Right: Details */}
        <div>
          {/* Compliance */}
          {statusData.complianceTimestamp && (
            <>
              <div className="mb-5 border-b border-surface-border pb-3">
                <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
                  Compliance Attestation
                </h2>
              </div>
              <table className="w-full">
                <thead>
                  <tr className="border-b border-surface-border">
                    <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
                      Result
                    </th>
                    <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
                      Timestamp
                    </th>
                    <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
                      Registry
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td className="py-3">
                      <Badge
                        variant="outline"
                        className={
                          statusData.complianceVerified
                            ? "border-green-200 bg-green-50 text-green-700"
                            : "border-red-200 bg-red-50 text-red-700"
                        }
                      >
                        {statusData.complianceVerified ? "VERIFIED" : "FAILED"}
                      </Badge>
                    </td>
                    <td className="py-3 text-small text-gray-700">
                      {new Date(
                        Number(statusData.complianceTimestamp) * 1000
                      ).toLocaleString()}
                    </td>
                    <td className="py-3 font-mono text-small text-gray-500">
                      ComplianceRegistry
                    </td>
                  </tr>
                </tbody>
              </table>
              <p className="mt-3 text-tiny text-gray-400">
                This attestation is the ONLY public record. No amounts, assets,
                or identities are stored on-chain.
              </p>
            </>
          )}

          {/* Privacy info */}
          <div className={statusData.complianceTimestamp ? "mt-8" : ""}>
            <div className="mb-5 border-b border-surface-border pb-3">
              <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
                Privacy
              </h2>
            </div>
            <div className="flex gap-4">
              <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-surface-overlay">
                <svg
                  className="h-4.5 w-4.5 text-gray-500"
                  fill="none"
                  viewBox="0 0 24 24"
                  strokeWidth={1.5}
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
                  />
                </svg>
              </div>
              <div>
                <p className="text-body font-medium text-gray-700">
                  Chainlink Confidential Compute
                </p>
                <p className="mt-1 text-small text-gray-500">
                  All verification happens inside a Trusted Execution Environment.
                  Trade parameters never leave the TEE.
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function OverallStatusBadge({ data }: { data: TradeStatusData }) {
  if (data.isSettled) {
    return (
      <Badge className="border-green-200 bg-green-50 text-green-700">
        Settled
      </Badge>
    );
  }
  if (data.isRefunded) {
    return (
      <Badge className="border-orange-200 bg-orange-50 text-orange-700">
        Refunded
      </Badge>
    );
  }
  if (data.isCrossChainPending) {
    return (
      <Badge className="border-brand-200 bg-brand-50 text-brand-700">
        Cross-Chain
      </Badge>
    );
  }
  return (
    <Badge className="border-brand-200 bg-brand-50 text-brand-700">
      In Progress
    </Badge>
  );
}

function StatusSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-5 border-b border-surface-border pb-6">
        <Skeleton className="h-12 w-12 rounded-full bg-surface-overlay" />
        <div className="flex gap-6">
          <Skeleton className="h-10 w-32 bg-surface-overlay" />
          <Skeleton className="h-10 w-24 bg-surface-overlay" />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-10">
        <Skeleton className="h-64 bg-surface-overlay" />
        <Skeleton className="h-40 bg-surface-overlay" />
      </div>
    </div>
  );
}
