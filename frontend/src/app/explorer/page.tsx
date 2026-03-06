"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { AttestationTable } from "@/components/explorer/attestation-table";
import { useAttestations } from "@/hooks/useAttestations";
import { PrivacyContrast } from "@/components/explorer/privacy-contrast";
import { cn } from "@/lib/utils";

type Filter = "all" | "pass" | "fail";

export default function ExplorerPage() {
  const { attestations, totalCount, isLoading } = useAttestations();
  const [filter, setFilter] = useState<Filter>("all");

  const passCount = attestations.filter((a) => a.verified).length;
  const failCount = attestations.filter((a) => !a.verified).length;

  return (
    <div className="flex flex-col gap-0">
      {/* Stats bar — arpa style: icon + big numbers separated by vertical lines */}
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
              d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z"
            />
          </svg>
        </div>
        <div className="ml-5 flex items-center divide-x divide-surface-border">
          <div className="pr-6 text-center">
            <p className="text-2xl font-bold tabular-nums text-gray-900">{totalCount}</p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Total Trades
            </p>
          </div>
          <div className="px-6 text-center">
            <p className="text-2xl font-bold tabular-nums text-status-success">{passCount}</p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Verified
            </p>
          </div>
          <div className="px-6 text-center">
            <p className="text-2xl font-bold tabular-nums text-status-error">{failCount}</p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Failed
            </p>
          </div>
        </div>
      </div>

      {/* Section header with inline tabs */}
      <div className="flex items-center justify-between border-b border-surface-border py-4">
        <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
          Attestations
        </h2>
        <div className="flex items-center gap-0">
          {(["all", "pass", "fail"] as Filter[]).map((f) => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={cn(
                "border-b-2 px-4 py-1 text-tiny font-medium uppercase tracking-wider transition-colors",
                filter === f
                  ? "border-brand-600 text-brand-600"
                  : "border-transparent text-gray-400 hover:text-gray-600"
              )}
            >
              {f === "all" ? "All" : f === "pass" ? "Verified" : "Failed"}
            </button>
          ))}
        </div>
      </div>

      {/* Content area */}
      <div className="pt-4">
        {/* Empty state when no attestations at all */}
        {!isLoading && totalCount === 0 ? (
          <div className="flex flex-col items-center gap-4 py-16 text-center">
            <div className="flex h-12 w-12 items-center justify-center rounded-full bg-surface-overlay">
              <svg
                className="h-6 w-6 text-gray-400"
                fill="none"
                viewBox="0 0 24 24"
                strokeWidth={1.5}
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z"
                />
              </svg>
            </div>
            <div>
              <p className="text-body font-medium text-gray-700">
                No attestations yet
              </p>
              <p className="mt-1 text-small text-gray-400">
                Attestations appear here after trades are processed through the CRE
                workflow.
              </p>
            </div>
            <Button asChild variant="outline" size="sm">
              <Link href="/">Create First Trade</Link>
            </Button>
          </div>
        ) : isLoading ? (
          <div className="flex flex-col gap-0">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton
                key={i}
                className="h-14 w-full border-b border-surface-border bg-surface-overlay"
              />
            ))}
          </div>
        ) : (
          <AttestationTable attestations={attestations} filter={filter} />
        )}
      </div>

      {/* Privacy contrast section */}
      <div className="mt-10">
        <PrivacyContrast />
      </div>
    </div>
  );
}
