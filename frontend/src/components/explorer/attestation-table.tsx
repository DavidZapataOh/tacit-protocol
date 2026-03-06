"use client";

import Link from "next/link";
import { Badge } from "@/components/ui/badge";
import type { AttestationEntry } from "@/hooks/useAttestations";

interface AttestationTableProps {
  attestations: AttestationEntry[];
  filter: "all" | "pass" | "fail";
}

function formatTimestamp(ts: bigint): string {
  return new Date(Number(ts) * 1000).toLocaleString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function AttestationTable({ attestations, filter }: AttestationTableProps) {
  const filtered =
    filter === "all"
      ? attestations
      : attestations.filter((a) =>
          filter === "pass" ? a.verified : !a.verified
        );

  if (filtered.length === 0) {
    return <EmptyState filter={filter} />;
  }

  return (
    <table className="w-full">
      <thead>
        <tr className="border-b border-surface-border">
          <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
            Trade
          </th>
          <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
            Status
          </th>
          <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
            Date
          </th>
          <th className="pb-2 text-right text-tiny font-medium uppercase tracking-wider text-gray-400">
            Actions
          </th>
        </tr>
      </thead>
      <tbody>
        {filtered.map((attestation, index) => (
          <tr
            key={`${attestation.tradeId}-${index}`}
            className="border-b border-surface-border transition-colors hover:bg-surface"
          >
            <td className="py-3.5 pr-4">
              <div className="flex items-center gap-3">
                <div className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-overlay">
                  <svg
                    className="h-4 w-4 text-gray-500"
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
                <span className="font-mono text-body font-medium text-gray-900">
                  {attestation.tradeId.slice(2, 10).toUpperCase()}
                </span>
              </div>
            </td>
            <td className="py-3.5 pr-4">
              <Badge
                variant="outline"
                className={
                  attestation.verified
                    ? "border-green-200 bg-green-50 text-green-700"
                    : "border-red-200 bg-red-50 text-red-700"
                }
              >
                {attestation.verified ? "Verified" : "Failed"}
              </Badge>
            </td>
            <td className="py-3.5 pr-4">
              <span className="text-small text-gray-500">
                {formatTimestamp(attestation.timestamp)}
              </span>
            </td>
            <td className="py-3.5 text-right">
              <div className="flex items-center justify-end gap-2">
                <Link
                  href={`/status/${attestation.tradeId}`}
                  className="rounded-button border border-surface-border px-3 py-1 text-tiny font-medium text-gray-600 transition-colors hover:border-brand-500 hover:text-brand-600"
                >
                  View Status
                </Link>
                <a
                  href={`https://sepolia.etherscan.io/search?q=${attestation.tradeId}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="rounded-button border border-surface-border p-1.5 text-gray-400 transition-colors hover:border-brand-500 hover:text-brand-600"
                  aria-label="View on block explorer"
                >
                  <svg
                    className="h-3.5 w-3.5"
                    fill="none"
                    viewBox="0 0 24 24"
                    strokeWidth={1.5}
                    stroke="currentColor"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"
                    />
                  </svg>
                </a>
              </div>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

function EmptyState({ filter }: { filter: string }) {
  return (
    <div className="flex flex-col items-center gap-4 py-16 text-center">
      <p className="text-body text-gray-500">
        {filter === "all"
          ? "No attestations yet. Complete a trade to see compliance records here."
          : `No ${filter === "pass" ? "verified" : "failed"} attestations found.`}
      </p>
      <Link
        href="/"
        className="text-small font-medium text-brand-600 hover:text-brand-700"
      >
        Create your first trade
      </Link>
    </div>
  );
}
