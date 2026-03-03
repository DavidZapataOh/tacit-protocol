"use client";

import { ConnectButton } from "@rainbow-me/rainbowkit";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-8">
      <div className="text-center">
        <h1 className="text-4xl font-bold tracking-tight">Tacit</h1>
        <p className="mt-2 text-lg text-muted-foreground">
          Trade privately. Settle compliantly.
        </p>
      </div>
      <ConnectButton />
    </main>
  );
}
