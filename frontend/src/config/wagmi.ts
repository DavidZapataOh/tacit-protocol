import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { sepolia, arbitrumSepolia } from "wagmi/chains";

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID;

if (!projectId) {
  console.warn(
    "NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID not set. Get one at https://cloud.walletconnect.com"
  );
}

export const config = getDefaultConfig({
  appName: "Tacit",
  projectId: projectId || "PLACEHOLDER_GET_FROM_WALLETCONNECT",
  chains: [sepolia, arbitrumSepolia],
  ssr: true,
});
