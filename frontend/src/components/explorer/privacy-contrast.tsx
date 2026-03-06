import { Badge } from "@/components/ui/badge";

const PRIVATE_FIELDS = [
  "Asset Offered",
  "Amount Offered",
  "Asset Wanted",
  "Amount Wanted",
  "Destination Chain",
  "Negotiated Terms",
];

export function PrivacyContrast() {
  return (
    <section className="flex flex-col gap-0">
      {/* Section header */}
      <div className="flex items-center justify-between border-b border-surface-border pb-3">
        <h2 className="text-tiny font-medium uppercase tracking-wider text-gray-900">
          Privacy Model
        </h2>
        <p className="text-tiny text-gray-400">
          No amounts. No assets. No identities.
        </p>
      </div>

      <div className="grid grid-cols-1 gap-10 pt-5 lg:grid-cols-2">
        {/* Left: What a trade contains (private) */}
        <div>
          <div className="mb-3 flex items-center gap-2">
            <div className="h-2 w-2 rounded-full bg-brand-500" />
            <span className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              What Parties Know
            </span>
          </div>

          <table className="w-full">
            <thead>
              <tr className="border-b border-surface-border">
                <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
                  Field
                </th>
                <th className="pb-2 text-right text-tiny font-medium uppercase tracking-wider text-gray-400">
                  Visibility
                </th>
              </tr>
            </thead>
            <tbody>
              {PRIVATE_FIELDS.map((field) => (
                <tr key={field} className="border-b border-surface-border">
                  <td className="py-2.5 text-small text-gray-600">{field}</td>
                  <td className="py-2.5 text-right">
                    <span className="rounded bg-red-50 px-1.5 py-0.5 font-mono text-tiny text-red-600">
                      ENCRYPTED
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p className="mt-3 text-tiny text-gray-400">
            All parameters encrypted with threshold public key before deposit.
          </p>
        </div>

        {/* Right: What blockchain records (public) */}
        <div>
          <div className="mb-3 flex items-center gap-2">
            <div className="h-2 w-2 rounded-full bg-gray-400" />
            <span className="text-tiny font-medium uppercase tracking-wider text-gray-400">
              What the Blockchain Records
            </span>
          </div>

          <table className="w-full">
            <thead>
              <tr className="border-b border-surface-border">
                <th className="pb-2 text-left text-tiny font-medium uppercase tracking-wider text-gray-400">
                  Field
                </th>
                <th className="pb-2 text-right text-tiny font-medium uppercase tracking-wider text-gray-400">
                  Value
                </th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b border-surface-border">
                <td className="py-2.5 text-small text-gray-600">Trade ID</td>
                <td className="py-2.5 text-right font-mono text-small text-gray-900">
                  0x8f2a...c91d
                </td>
              </tr>
              <tr className="border-b border-surface-border">
                <td className="py-2.5 text-small text-gray-600">Party Addresses</td>
                <td className="py-2.5 text-right font-mono text-small text-gray-900">
                  Public
                </td>
              </tr>
              <tr className="border-b border-surface-border">
                <td className="py-2.5 text-small text-gray-600">Trade Params</td>
                <td className="py-2.5 text-right font-mono text-small text-gray-300">
                  0x7b2261...
                </td>
              </tr>
              <tr className="border-b border-surface-border">
                <td className="py-2.5 text-small text-gray-600">Compliance</td>
                <td className="py-2.5 text-right">
                  <Badge
                    variant="outline"
                    className="border-green-200 bg-green-50 text-green-700"
                  >
                    VERIFIED
                  </Badge>
                </td>
              </tr>
              <tr>
                <td className="py-2.5 text-small text-gray-600">Timestamp</td>
                <td className="py-2.5 text-right text-small text-gray-900">
                  Recorded on-chain
                </td>
              </tr>
            </tbody>
          </table>
          <p className="mt-3 text-tiny text-gray-400">
            This is the COMPLETE public record. Nothing else is stored.
          </p>
        </div>
      </div>
    </section>
  );
}
