import { TradeForm } from "@/components/trade/trade-form";
import { ChainWarning } from "@/components/wallet/chain-warning";

export default function CreateTradePage() {
  return (
    <div className="flex flex-col gap-8">
      <ChainWarning />

      {/* Stats bar — like arpa dashboard */}
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
              d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
            />
          </svg>
        </div>
        <div className="ml-5 flex items-center divide-x divide-surface-border">
          <div className="pr-6">
            <p className="text-2xl font-bold tabular-nums text-gray-900">Tacit</p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Private OTC Settlement
            </p>
          </div>
          <div className="px-6 text-center">
            <p className="text-2xl font-bold tabular-nums text-gray-900">6</p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Chainlink Services
            </p>
          </div>
          <div className="px-6 text-center">
            <p className="text-2xl font-bold tabular-nums text-gray-900">2</p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Chains
            </p>
          </div>
          <div className="pl-6 text-center">
            <p className="text-2xl font-bold tabular-nums text-gray-900">TEE</p>
            <p className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              Confidential Compute
            </p>
          </div>
        </div>
      </div>

      {/* Two-column layout */}
      <div className="grid grid-cols-1 gap-10 lg:grid-cols-2">
        {/* Left: Form */}
        <div>
          {/* Section header */}
          <div className="mb-6 flex items-center justify-between border-b border-surface-border pb-3">
            <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
              New Trade
            </h2>
            <span className="text-tiny text-gray-400">
              All parameters encrypted
            </span>
          </div>
          <TradeForm />
        </div>

        {/* Right: How it works */}
        <div>
          <div className="mb-6 flex items-center justify-between border-b border-surface-border pb-3">
            <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
              How It Works
            </h2>
          </div>

          <div className="flex flex-col gap-0">
            {[
              {
                step: "1",
                title: "Create & Encrypt",
                desc: "Trade parameters are encrypted client-side with the Vault DON threshold public key before deposit.",
              },
              {
                step: "2",
                title: "Share Code",
                desc: "Send the matching code to your counterparty. No trade details are visible on-chain.",
              },
              {
                step: "3",
                title: "Counterparty Matches",
                desc: "Your counterparty deposits their side using the matching code.",
              },
              {
                step: "4",
                title: "CRE Workflow",
                desc: "Chainlink CRE decrypts inside a TEE, runs KYC/sanctions checks via Confidential HTTP, and settles.",
              },
              {
                step: "5",
                title: "Settlement",
                desc: "Funds are released to both parties. Only a pass/fail attestation is recorded on-chain.",
              },
            ].map((item, i) => (
              <div
                key={item.step}
                className={`flex gap-4 py-4 ${i < 4 ? "border-b border-surface-border" : ""}`}
              >
                <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-surface-overlay text-tiny font-bold text-gray-500">
                  {item.step}
                </span>
                <div>
                  <p className="text-body font-medium text-gray-900">
                    {item.title}
                  </p>
                  <p className="mt-0.5 text-small text-gray-500">
                    {item.desc}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
