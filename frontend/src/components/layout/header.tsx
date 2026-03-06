"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { cn } from "@/lib/utils";

const navigation = [
  { name: "Create", href: "/" },
  { name: "Match", href: "/match" },
  { name: "Explorer", href: "/explorer" },
];

function CustomConnectButton() {
  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
        openAccountModal,
        openChainModal,
        openConnectModal,
        mounted,
      }) => {
        const ready = mounted;
        const connected = ready && account && chain;

        return (
          <div
            {...(!ready && {
              "aria-hidden": true,
              style: {
                opacity: 0,
                pointerEvents: "none" as const,
                userSelect: "none" as const,
              },
            })}
          >
            {(() => {
              if (!connected) {
                return (
                  <button
                    onClick={openConnectModal}
                    className="h-9 rounded-button border border-surface-border bg-white px-4 text-small font-medium text-gray-900 transition-colors hover:bg-surface-overlay"
                  >
                    Connect
                  </button>
                );
              }

              if (chain.unsupported) {
                return (
                  <button
                    onClick={openChainModal}
                    className="h-9 rounded-button border border-status-error/30 bg-red-50 px-4 text-small font-medium text-status-error transition-colors hover:bg-red-100"
                  >
                    Wrong network
                  </button>
                );
              }

              return (
                <div className="flex items-center gap-2">
                  <button
                    onClick={openChainModal}
                    className="flex h-9 items-center gap-1.5 rounded-button border border-surface-border bg-white px-2.5 transition-colors hover:bg-surface-overlay"
                  >
                    {chain.hasIcon && chain.iconUrl && (
                      <img
                        alt={chain.name ?? "Chain"}
                        src={chain.iconUrl}
                        className="h-4 w-4 rounded-full"
                      />
                    )}
                    <svg
                      className="h-3 w-3 text-gray-400"
                      fill="none"
                      viewBox="0 0 24 24"
                      strokeWidth={2}
                      stroke="currentColor"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M19.5 8.25l-7.5 7.5-7.5-7.5"
                      />
                    </svg>
                  </button>

                  <button
                    onClick={openAccountModal}
                    className="flex h-9 items-center gap-2 rounded-button border border-surface-border bg-white px-3 transition-colors hover:bg-surface-overlay"
                  >
                    <span className="text-small font-medium text-gray-900">
                      {account.displayName}
                    </span>
                  </button>
                </div>
              );
            })()}
          </div>
        );
      }}
    </ConnectButton.Custom>
  );
}

export function Header() {
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-50 border-b border-surface-border bg-white/80 backdrop-blur-sm">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between px-6 md:px-8 lg:px-12">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2.5">
          <span className="text-subheading font-bold tracking-tight text-gray-900">
            tacit
          </span>
          <span className="rounded-full border border-surface-border-light px-2 py-0.5 text-tiny font-medium text-gray-400">
            testnet
          </span>
        </Link>

        {/* Navigation */}
        <nav className="hidden items-center gap-6 md:flex">
          {navigation.map((item) => {
            const isActive =
              item.href === "/"
                ? pathname === "/"
                : pathname.startsWith(item.href);

            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "text-small font-medium transition-colors",
                  isActive
                    ? "text-gray-900"
                    : "text-gray-400 hover:text-gray-600"
                )}
              >
                {item.name}
              </Link>
            );
          })}
        </nav>

        {/* Wallet Connect */}
        <CustomConnectButton />
      </div>
    </header>
  );
}
