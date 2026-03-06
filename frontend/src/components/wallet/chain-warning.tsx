"use client";

import { Button } from "@/components/ui/button";
import { useChainGuard } from "@/hooks/useChainGuard";

export function ChainWarning() {
  const { isConnected, isSupported, isSwitching, switchToSepolia } =
    useChainGuard();

  if (!isConnected || isSupported) return null;

  return (
    <div className="rounded-input border border-status-warning/30 bg-orange-50 px-4 py-3">
      <div className="flex items-center justify-between gap-4">
        <div>
          <p className="text-body font-medium text-status-warning">
            Wrong Network
          </p>
          <p className="text-small text-gray-500">
            Please switch to Sepolia to use Tacit.
          </p>
        </div>
        <Button
          onClick={switchToSepolia}
          disabled={isSwitching}
          variant="outline"
          className="shrink-0 border-status-warning/30 text-status-warning hover:bg-orange-50"
        >
          {isSwitching ? "Switching..." : "Switch to Sepolia"}
        </Button>
      </div>
    </div>
  );
}
