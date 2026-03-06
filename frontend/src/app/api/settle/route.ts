import { NextRequest, NextResponse } from "next/server";
import {
  createWalletClient,
  createPublicClient,
  http,
  encodeAbiParameters,
  parseAbiParameters,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { sepolia } from "viem/chains";

/**
 * CRE Workflow Settlement Endpoint
 *
 * Executes the same on-chain writes that the CRE Workflow DON would perform
 * after completing all 6 steps (decrypt, match, sanctions, KYC, settle, attest).
 *
 * In production with CRE deploy access, the DON handles this automatically
 * via KeystoneForwarder. For the hackathon demo, the deployer wallet IS the
 * KeystoneForwarder, so this endpoint produces identical on-chain results.
 *
 * Set NEXT_PUBLIC_CRE_LIVE=true to disable this endpoint when using real DON.
 */

const VAULT = "0xdcf70165b005e00fFdf904BACE94A560bff26358" as const;
const REGISTRY = "0x58FCD94b1BB542fF728c9FC40a7BBfE2fFEa018e" as const;

const onReportAbi = [
  {
    type: "function" as const,
    name: "onReport" as const,
    inputs: [
      { name: "metadata", type: "bytes" as const },
      { name: "report", type: "bytes" as const },
    ],
    outputs: [],
    stateMutability: "nonpayable" as const,
  },
];

const getTradeStatusAbi = [
  {
    type: "function" as const,
    name: "getTradeStatus" as const,
    inputs: [{ name: "tradeId", type: "bytes32" as const }],
    outputs: [{ name: "status", type: "uint8" as const }],
    stateMutability: "view" as const,
  },
];

const hasAttestationAbi = [
  {
    type: "function" as const,
    name: "hasAttestation" as const,
    inputs: [{ name: "tradeId", type: "bytes32" as const }],
    outputs: [{ name: "exists", type: "bool" as const }],
    stateMutability: "view" as const,
  },
];

export async function POST(request: NextRequest) {
  // Skip if CRE DON is handling settlement
  if (process.env.NEXT_PUBLIC_CRE_LIVE === "true") {
    return NextResponse.json(
      { error: "CRE DON is active — settlement handled by KeystoneForwarder" },
      { status: 400 }
    );
  }

  try {
    const { tradeId } = await request.json();

    if (!tradeId || typeof tradeId !== "string" || !tradeId.startsWith("0x")) {
      return NextResponse.json({ error: "Invalid tradeId" }, { status: 400 });
    }

    const deployerKey = process.env.DEPLOYER_PRIVATE_KEY;
    if (!deployerKey) {
      return NextResponse.json(
        { error: "DEPLOYER_PRIVATE_KEY not configured" },
        { status: 500 }
      );
    }

    const rpcUrl =
      process.env.SEPOLIA_RPC_URL ||
      "https://ethereum-sepolia-rpc.publicnode.com";

    const account = privateKeyToAccount(deployerKey as `0x${string}`);

    const publicClient = createPublicClient({
      chain: sepolia,
      transport: http(rpcUrl),
    });

    const walletClient = createWalletClient({
      account,
      chain: sepolia,
      transport: http(rpcUrl),
    });

    // Verify trade is in BothDeposited (status=2)
    const statusRaw = await publicClient.readContract({
      address: VAULT,
      abi: getTradeStatusAbi,
      functionName: "getTradeStatus",
      args: [tradeId as `0x${string}`],
    });
    const status = Number(statusRaw);

    if (status !== 2) {
      return NextResponse.json(
        { error: `Trade not ready (status=${status})`, settled: status === 3 },
        { status: 400 }
      );
    }

    // Step 1: Settle the trade (action=0)
    const settleReport = encodeAbiParameters(
      parseAbiParameters("bytes32, uint8, bytes"),
      [tradeId as `0x${string}`, 0, "0x"]
    );

    const settleTx = await walletClient.writeContract({
      address: VAULT,
      abi: onReportAbi,
      functionName: "onReport",
      args: ["0x", settleReport],
    });

    await publicClient.waitForTransactionReceipt({ hash: settleTx });

    // Step 2: Record compliance attestation (pass=true)
    const hasAtt = await publicClient.readContract({
      address: REGISTRY,
      abi: hasAttestationAbi,
      functionName: "hasAttestation",
      args: [tradeId as `0x${string}`],
    });

    let attestTx: `0x${string}` | null = null;

    if (!hasAtt) {
      const timestamp = BigInt(Math.floor(Date.now() / 1000));
      const attestReport = encodeAbiParameters(
        parseAbiParameters("bytes32, bool, uint256"),
        [tradeId as `0x${string}`, true, timestamp]
      );

      attestTx = await walletClient.writeContract({
        address: REGISTRY,
        abi: onReportAbi,
        functionName: "onReport",
        args: ["0x", attestReport],
      });

      await publicClient.waitForTransactionReceipt({ hash: attestTx });
    }

    return NextResponse.json({
      success: true,
      tradeId,
      settleTx,
      attestTx,
    });
  } catch (error: unknown) {
    const message =
      error instanceof Error ? error.message : "Settlement failed";
    console.error("Settlement error:", error);
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
