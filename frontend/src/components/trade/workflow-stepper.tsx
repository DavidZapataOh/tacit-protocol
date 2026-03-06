"use client";

import { cn } from "@/lib/utils";
import type { StepStatus, StepInfo } from "@/hooks/useTradeStatus";

interface WorkflowStepperProps {
  steps: StepInfo[];
}

function StepIcon({ status }: { status: StepStatus }) {
  switch (status) {
    case "pending":
      return (
        <div className="h-8 w-8 rounded-full border-2 border-surface-border bg-white" />
      );
    case "active":
      return (
        <div className="relative h-8 w-8">
          <div className="absolute inset-0 animate-ping rounded-full bg-brand-500/20" />
          <div className="relative flex h-8 w-8 items-center justify-center rounded-full border-2 border-brand-500 bg-brand-50">
            <div className="h-3 w-3 rounded-full bg-brand-500" />
          </div>
        </div>
      );
    case "done":
      return (
        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-green-50">
          <svg
            className="h-4 w-4 text-status-success"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={2.5}
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M4.5 12.75l6 6 9-13.5"
            />
          </svg>
        </div>
      );
    case "failed":
      return (
        <div className="flex h-8 w-8 items-center justify-center rounded-full bg-red-50">
          <svg
            className="h-4 w-4 text-status-error"
            fill="none"
            viewBox="0 0 24 24"
            strokeWidth={2.5}
            stroke="currentColor"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </div>
      );
  }
}

export function WorkflowStepper({ steps }: WorkflowStepperProps) {
  return (
    <div className="flex flex-col">
      {steps.map((step, index) => (
        <div key={step.label} className="flex gap-4">
          {/* Vertical line + icon */}
          <div className="flex flex-col items-center">
            <StepIcon status={step.status} />
            {index < steps.length - 1 && (
              <div
                className={cn(
                  "min-h-[32px] w-0.5 flex-1",
                  step.status === "done"
                    ? "bg-status-success/30"
                    : step.status === "failed"
                      ? "bg-status-error/30"
                      : "bg-surface-border"
                )}
              />
            )}
          </div>

          {/* Step content */}
          <div className="flex-1 pb-8">
            <div className="flex items-center gap-2">
              <p
                className={cn(
                  "text-body font-medium",
                  step.status === "active" && "text-brand-600",
                  step.status === "done" && "text-status-success",
                  step.status === "failed" && "text-status-error",
                  step.status === "pending" && "text-gray-400"
                )}
              >
                {step.label}
              </p>
              {step.service && (
                <span className="rounded-badge bg-brand-50 px-1.5 py-0.5 text-tiny font-medium text-brand-700">
                  {step.service}
                </span>
              )}
            </div>
            <p
              className={cn(
                "mt-1 text-small",
                step.status === "pending" ? "text-gray-300" : "text-gray-500"
              )}
            >
              {step.description}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}
