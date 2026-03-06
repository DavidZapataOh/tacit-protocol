"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";

/**
 * Converts a matching code or trade ID to a bytes32 trade ID.
 * Accepts:
 *   - Full trade ID: "0x..." (66 chars)
 *   - Matching code: "TACIT-A1B2C3D4" (pads to bytes32)
 */
function parseTradeInput(input: string): `0x${string}` | null {
  const trimmed = input.trim();

  // Full trade ID (0x + 64 hex chars)
  if (/^0x[0-9a-fA-F]{64}$/.test(trimmed)) {
    return trimmed as `0x${string}`;
  }

  // Matching code format: TACIT-XXXXXXXX
  const stripped = trimmed.replace(/^TACIT-/i, "");
  if (/^[0-9a-fA-F]{8,}$/.test(stripped)) {
    return `0x${stripped.toLowerCase().padEnd(64, "0")}` as `0x${string}`;
  }

  return null;
}

function getCodeButtonState(params: {
  code: string;
  isLoading: boolean;
}): { label: string; disabled: boolean } {
  if (!params.code.trim())
    return { label: "Enter matching code", disabled: true };
  if (params.isLoading) return { label: "Searching...", disabled: true };
  return { label: "Find Trade", disabled: false };
}

interface MatchCodeCardProps {
  onTradeFound: (id: `0x${string}`) => void;
  isLoading: boolean;
  error?: string | null;
}

export function MatchCodeCard({
  onTradeFound,
  isLoading,
  error,
}: MatchCodeCardProps) {
  const [code, setCode] = useState("");
  const [validationError, setValidationError] = useState<string | null>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setValidationError(null);

    const tradeId = parseTradeInput(code);
    if (!tradeId) {
      setValidationError(
        "Invalid format. Use TACIT-XXXXXXXX or a full trade ID (0x...)"
      );
      return;
    }
    onTradeFound(tradeId);
  };

  const buttonState = getCodeButtonState({ code, isLoading });

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <div className="flex flex-col gap-1.5">
        <label className="text-small font-medium text-gray-600">
          Matching code
        </label>
        <input
          type="text"
          placeholder="TACIT-A1B2C3D4"
          value={code}
          onChange={(e) => {
            setCode(e.target.value);
            setValidationError(null);
          }}
          className="h-10 w-full rounded-input border border-surface-border bg-white px-3 font-mono tracking-wider text-body text-gray-900 placeholder:text-gray-400 focus:border-brand-500 focus:outline-none focus:ring-1 focus:ring-brand-500"
        />
        {validationError && (
          <p className="text-tiny text-status-error">{validationError}</p>
        )}
        {error && (
          <p className="text-tiny text-status-error">{error}</p>
        )}
      </div>

      <Button
        type="submit"
        disabled={buttonState.disabled}
        className="h-11 rounded-button bg-brand-600 text-body font-medium text-white hover:bg-brand-700 disabled:bg-brand-50 disabled:text-brand-300"
      >
        {buttonState.label}
      </Button>
    </form>
  );
}
