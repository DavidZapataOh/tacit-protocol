import type { Metadata } from "next";
import { Inter } from "next/font/google";
import dynamic from "next/dynamic";
import { Toaster } from "@/components/ui/sonner";
import "./globals.css";

const Web3Provider = dynamic(
  () => import("@/providers/web3-provider").then((mod) => mod.Web3Provider),
  { ssr: false }
);

const Header = dynamic(
  () => import("@/components/layout/header").then((mod) => mod.Header),
  { ssr: false }
);

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "Tacit",
  description:
    "Trade privately. Settle compliantly. Private OTC settlement with automated compliance via Chainlink Confidential Compute.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.variable} suppressHydrationWarning>
      <body className="min-h-screen bg-surface font-sans text-gray-900 antialiased">
        <Web3Provider>
          <div className="flex min-h-screen flex-col">
            <Header />
            <main className="flex-1 px-6 py-8 md:px-8 lg:px-12">
              <div className="mx-auto max-w-6xl">{children}</div>
            </main>
          </div>
          <Toaster />
        </Web3Provider>
      </body>
    </html>
  );
}
