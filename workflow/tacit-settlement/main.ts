/**
 * Tacit Settlement Workflow
 *
 * Triggered when both parties have deposited into OTCVault (BothPartiesDeposited event).
 * Executes 6 steps inside TEE via Chainlink Confidential Compute:
 *
 * 1. Read encrypted trade parameters from OTCVault (EVM read)
 * 2. Decrypt parameters in TEE using Vault DON threshold decryption
 * 3. Verify bilateral parameter match
 * 4. Check sanctions via Confidential HTTP (OFAC SDN)
 * 5. Check KYC/accreditation via Confidential HTTP
 * 6. Execute settlement or refund + write compliance attestation on-chain
 *
 * See: Tacit Paper, Section 5.3.1 and Section 6.1
 */

import {
	bytesToHex,
	ConfidentialHTTPClient,
	EVMClient,
	type EVMLog,
	encodeCallMsg,
	getNetwork,
	handler,
	LAST_FINALIZED_BLOCK_NUMBER,
	prepareReportRequest,
	Runner,
	type Runtime,
	TxStatus,
} from "@chainlink/cre-sdk";
import {
	type Address,
	decodeFunctionResult,
	encodeFunctionData,
	toHex,
	zeroAddress,
} from "viem";
import { z } from "zod";

// ---------------------------------------------------------------------------
// Config schema — validated by zod at workflow startup
// ---------------------------------------------------------------------------
const configSchema = z.object({
	evms: z.array(
		z.object({
			otcVaultAddress: z.string(),
			complianceRegistryAddress: z.string(),
			chainSelectorName: z.string(),
			gasLimit: z.string(),
		}),
	),
	complianceApiBaseUrl: z.string(),
	owner: z.string(),
});

type Config = z.infer<typeof configSchema>;

// ---------------------------------------------------------------------------
// ABIs — stubs, will be replaced with real ABIs from contracts/out/ after
// Sprint 1 compilation. Only the functions we call are declared here.
// ---------------------------------------------------------------------------

/** OTCVault: read encrypted trade parameters */
const OTC_VAULT_ABI = [
	{
		type: "function",
		name: "getEncryptedParams",
		inputs: [{ name: "tradeId", type: "bytes32" }],
		outputs: [
			{ name: "partyAParams", type: "bytes" },
			{ name: "partyBParams", type: "bytes" },
		],
		stateMutability: "view",
	},
] as const;

/** ComplianceRegistry: write attestation via IReceiver.onReport */
const COMPLIANCE_REGISTRY_ABI = [
	{
		type: "function",
		name: "onReport",
		inputs: [
			{ name: "metadata", type: "bytes" },
			{ name: "rawReport", type: "bytes" },
		],
		outputs: [],
		stateMutability: "nonpayable",
	},
] as const;

// ---------------------------------------------------------------------------
// Log trigger handler — fires on BothPartiesDeposited(bytes32 tradeId)
// ---------------------------------------------------------------------------
const onBothPartiesDeposited = (
	runtime: Runtime<Config>,
	payload: EVMLog,
): string => {
	runtime.log("[Tacit] Workflow triggered — BothPartiesDeposited event");

	// Extract tradeId from event topics (topic[1] = indexed tradeId)
	if (payload.topics.length < 2) {
		throw new Error(
			`[Tacit] Expected at least 2 topics, got ${payload.topics.length}`,
		);
	}
	const tradeIdBytes = payload.topics[1];
	runtime.log(`[Tacit] Trade ID: ${bytesToHex(tradeIdBytes)}`);

	const evmConfig = runtime.config.evms[0];
	const network = getNetwork({
		chainFamily: "evm",
		chainSelectorName: evmConfig.chainSelectorName,
		isTestnet: true,
	});

	if (!network) {
		throw new Error(
			`[Tacit] Network not found: ${evmConfig.chainSelectorName}`,
		);
	}

	const evmClient = new EVMClient(network.chainSelector.selector);

	// -----------------------------------------------------------------------
	// Step 1: Read encrypted trade parameters from OTCVault
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 1: Reading encrypted trade parameters...");

	// TODO (Sprint 3): Uncomment when OTCVault is deployed
	// const callData = encodeFunctionData({
	//   abi: OTC_VAULT_ABI,
	//   functionName: "getEncryptedParams",
	//   args: [bytesToHex(tradeIdBytes) as `0x${string}`],
	// });
	// const readResult = evmClient.callContract(runtime, {
	//   call: encodeCallMsg({
	//     from: zeroAddress,
	//     to: evmConfig.otcVaultAddress as Address,
	//     data: callData,
	//   }),
	//   blockNumber: LAST_FINALIZED_BLOCK_NUMBER,
	// }).result();
	// const [partyAParams, partyBParams] = decodeFunctionResult({
	//   abi: OTC_VAULT_ABI,
	//   functionName: "getEncryptedParams",
	//   data: bytesToHex(readResult.data),
	// });

	// -----------------------------------------------------------------------
	// Step 2: Decrypt parameters in TEE using Vault DON
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 2: Decrypting parameters in TEE...");

	// TODO (Sprint 3): Decrypt the encrypted params using runtime secrets
	// The TEE environment ensures decrypted values never leave the enclave.
	// const decryptionKey = runtime.getSecret({
	//   id: "ENCRYPTION_KEY",
	// }).result().value;

	// -----------------------------------------------------------------------
	// Step 3: Verify bilateral parameter match
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 3: Verifying bilateral match...");

	// TODO (Sprint 3): Compare decrypted partyA and partyB trade parameters
	// - partyA.asset must equal partyB.wantAsset
	// - partyA.amount must equal partyB.wantAmount
	// - partyB.asset must equal partyA.wantAsset
	// - partyB.amount must equal partyA.wantAmount

	// -----------------------------------------------------------------------
	// Step 4: Check sanctions via Confidential HTTP (OFAC SDN)
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 4: Checking sanctions (OFAC SDN)...");

	// TODO (Sprint 3): Uncomment when compliance API is deployed
	// const confHttp = new ConfidentialHTTPClient();
	// const sanctionsResponse = confHttp.sendRequest(runtime, {
	//   request: {
	//     url: `${runtime.config.complianceApiBaseUrl}/sanctions/check`,
	//     method: "POST",
	//     bodyString: JSON.stringify({
	//       addresses: [partyAAddress, partyBAddress],
	//     }),
	//     multiHeaders: {
	//       "Content-Type": { values: ["application/json"] },
	//       "Authorization": { values: ["Bearer {{.OFAC_API_KEY}}"] },
	//     },
	//   },
	//   vaultDonSecrets: [
	//     { key: "OFAC_API_KEY", owner: runtime.config.owner },
	//   ],
	// }).result();

	// -----------------------------------------------------------------------
	// Step 5: Check KYC via Confidential HTTP
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 5: Checking KYC/accreditation...");

	// TODO (Sprint 3): Similar pattern to Step 4
	// const kycResponse = confHttp.sendRequest(runtime, {
	//   request: {
	//     url: `${runtime.config.complianceApiBaseUrl}/kyc/verify`,
	//     method: "POST",
	//     bodyString: JSON.stringify({
	//       addresses: [partyAAddress, partyBAddress],
	//     }),
	//     multiHeaders: {
	//       "Content-Type": { values: ["application/json"] },
	//       "Authorization": { values: ["Bearer {{.KYC_API_KEY}}"] },
	//     },
	//   },
	//   vaultDonSecrets: [
	//     { key: "KYC_API_KEY", owner: runtime.config.owner },
	//   ],
	// }).result();

	// -----------------------------------------------------------------------
	// Step 6: Execute settlement + write compliance attestation on-chain
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 6: Computing settlement instructions...");

	// TODO (Sprint 3): Generate signed report and write to ComplianceRegistry
	// const attestationCallData = encodeFunctionData({
	//   abi: COMPLIANCE_REGISTRY_ABI,
	//   functionName: "onReport",
	//   args: [toHex("0x"), attestationData],
	// });
	// const report = runtime.report(
	//   prepareReportRequest(attestationCallData),
	// ).result();
	// const writeResp = evmClient.writeReport(runtime, {
	//   receiver: evmConfig.complianceRegistryAddress,
	//   report,
	// }).result();
	// if (writeResp.txStatus !== TxStatus.SUCCESS) {
	//   throw new Error(`[Tacit] Failed to write attestation: ${writeResp.errorMessage}`);
	// }

	runtime.log("[Tacit] Workflow complete (stub — all steps are TODOs).");
	return "settlement-stub-complete";
};

// ---------------------------------------------------------------------------
// Workflow initialization — registers EVM log trigger for BothPartiesDeposited
// ---------------------------------------------------------------------------
const initWorkflow = (config: Config) => {
	const evmConfig = config.evms[0];
	const network = getNetwork({
		chainFamily: "evm",
		chainSelectorName: evmConfig.chainSelectorName,
		isTestnet: true,
	});

	if (!network) {
		throw new Error(
			`[Tacit] Network not found: ${evmConfig.chainSelectorName}`,
		);
	}

	const evmClient = new EVMClient(network.chainSelector.selector);

	return [
		handler(
			evmClient.logTrigger({
				// OTCVault contract address — placeholder, update after deploy
				addresses: [evmConfig.otcVaultAddress],
				// Topic filter for BothPartiesDeposited(bytes32 tradeId)
				// Event signature topic will be set after contract compilation:
				// keccak256("BothPartiesDeposited(bytes32)")
				// For now, no topic filter = match all logs from this address
			}),
			onBothPartiesDeposited,
		),
	];
};

// ---------------------------------------------------------------------------
// Entry point — required by CRE SDK
// ---------------------------------------------------------------------------
export async function main() {
	const runner = await Runner.newRunner<Config>({ configSchema });
	await runner.run(initWorkflow);
}
