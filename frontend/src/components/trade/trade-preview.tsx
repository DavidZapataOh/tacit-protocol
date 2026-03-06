"use client";

import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { TradeStatus } from "@/types/trade";
import type { Trade } from "@/types/trade";

interface TradePreviewProps {
  trade: Trade;
}

function formatTimestamp(timestamp: bigint): string {
  return new Date(Number(timestamp) * 1000).toLocaleString();
}

function truncateAddress(addr: string): string {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

const STATUS_LABELS: Record<number, { label: string; className: string }> = {
  [TradeStatus.Created]: {
    label: "Waiting for Match",
    className: "border-status-success/30 bg-status-success/10 text-status-success",
  },
  [TradeStatus.BothDeposited]: {
    label: "Both Deposited",
    className: "border-status-info/30 bg-status-info/10 text-status-info",
  },
  [TradeStatus.Settled]: {
    label: "Settled",
    className: "border-status-success/30 bg-status-success/10 text-status-success",
  },
  [TradeStatus.Refunded]: {
    label: "Refunded",
    className: "border-status-warning/30 bg-status-warning/10 text-status-warning",
  },
  [TradeStatus.CrossChainPending]: {
    label: "Cross-Chain Pending",
    className: "border-brand-500/30 bg-brand-500/10 text-brand-400",
  },
};

export function TradePreview({ trade }: TradePreviewProps) {
  const statusInfo = STATUS_LABELS[trade.status] ?? {
    label: "Unknown",
    className: "border-surface-border text-slate-400",
  };

  return (
    <Card className="border-surface-border bg-surface-raised shadow-soft">
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle className="text-subheading font-semibold text-slate-100">
            Trade Found
          </CardTitle>
          <Badge variant="outline" className={statusInfo.className}>
            {statusInfo.label}
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-element">
        {/* Public trade info only — no private data */}
        <div className="grid grid-cols-2 gap-related">
          <div>
            <p className="text-small text-slate-500">Trade ID</p>
            <p className="font-mono text-body text-slate-300">
              {trade.tradeId.slice(0, 10)}...{trade.tradeId.slice(-8)}
            </p>
          </div>
          <div>
            <p className="text-small text-slate-500">Created by</p>
            <p className="font-mono text-body text-slate-300">
              {truncateAddress(trade.partyA.depositor)}
            </p>
          </div>
          <div>
            <p className="text-small text-slate-500">Created at</p>
            <p className="text-body text-slate-300">
              {formatTimestamp(trade.createdAt)}
            </p>
          </div>
          <div>
            <p className="text-small text-slate-500">Status</p>
            <p className="text-body text-slate-300">
              {trade.status === TradeStatus.Created
                ? "Awaiting counterparty"
                : statusInfo.label}
            </p>
          </div>
        </div>

        {/* Privacy emphasis */}
        <div className="rounded-card border border-surface-border bg-surface px-4 py-3">
          <p className="text-small text-slate-400">
            Trade parameters (assets, amounts, terms) are encrypted and not
            visible. You cannot see what the counterparty deposited. Only the
            CRE workflow running in a TEE can decrypt and verify both sides.
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
