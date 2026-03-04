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
	zeroAddress,
} from "viem";
import { z } from "zod";
import { decryptTradeParams } from "./crypto";
import { verifyBilateralMatch } from "./match";
import {
	type SanctionsApiResponse,
	type KycApiResponse,
	parseResponseBody,
	makeComplianceDecision,
} from "./compliance";
import {
	ReportAction,
	IRECEIVER_ABI,
	encodeSettlementReport,
	encodeAttestationReport,
} from "./settlement";

// ---------------------------------------------------------------------------
// Event signature: BothPartiesDeposited(bytes32 indexed tradeId)
// Computed via: cast sig-event "BothPartiesDeposited(bytes32)"
// ---------------------------------------------------------------------------
const BOTH_PARTIES_DEPOSITED_TOPIC =
	"0x7bda33a9fd14a201ddd6a6a589e3d4a35d42ff709512c7ec4fe93aaac146cc00";

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
	sanctionsApiBaseUrl: z.string(),
	kycApiBaseUrl: z.string(),
	owner: z.string(),
});

type Config = z.infer<typeof configSchema>;

// ---------------------------------------------------------------------------
// ABIs — matching the deployed contracts (IOTCVault.sol, IComplianceRegistry.sol)
// ---------------------------------------------------------------------------

/** Deposit struct components (nested in Trade) */
const DEPOSIT_COMPONENTS = [
	{ name: "depositor", type: "address" },
	{ name: "token", type: "address" },
	{ name: "amount", type: "uint256" },
	{ name: "encryptedParams", type: "bytes" },
	{ name: "exists", type: "bool" },
] as const;

/** OTCVault.getTrade(bytes32) → Trade struct */
const GET_TRADE_ABI = [
	{
		type: "function",
		name: "getTrade",
		inputs: [{ name: "tradeId", type: "bytes32" }],
		outputs: [
			{
				name: "trade",
				type: "tuple",
				components: [
					{ name: "tradeId", type: "bytes32" },
					{ name: "partyA", type: "tuple", components: DEPOSIT_COMPONENTS },
					{ name: "partyB", type: "tuple", components: DEPOSIT_COMPONENTS },
					{ name: "status", type: "uint8" },
					{ name: "createdAt", type: "uint256" },
					{ name: "expiresAt", type: "uint256" },
				],
			},
		],
		stateMutability: "view",
	},
] as const;

// IReceiver.onReport ABI is imported from ./settlement (IRECEIVER_ABI)

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

	const tradeIdHex = bytesToHex(tradeIdBytes) as `0x${string}`;

	const callData = encodeFunctionData({
		abi: GET_TRADE_ABI,
		functionName: "getTrade",
		args: [tradeIdHex],
	});

	const readResult = evmClient
		.callContract(runtime, {
			call: encodeCallMsg({
				from: zeroAddress,
				to: evmConfig.otcVaultAddress as Address,
				data: callData,
			}),
			blockNumber: LAST_FINALIZED_BLOCK_NUMBER,
		})
		.result();

	const trade = decodeFunctionResult({
		abi: GET_TRADE_ABI,
		functionName: "getTrade",
		data: bytesToHex(readResult.data) as `0x${string}`,
	});

	const partyAAddress = trade.partyA.depositor;
	const partyBAddress = trade.partyB.depositor;
	const encryptedParamsA = trade.partyA.encryptedParams;
	const encryptedParamsB = trade.partyB.encryptedParams;

	runtime.log(`[Tacit] Party A: ${partyAAddress}`);
	runtime.log(`[Tacit] Party B: ${partyBAddress}`);
	runtime.log("[Tacit] Encrypted parameters read from OTCVault");

	// -----------------------------------------------------------------------
	// Step 2: Decrypt parameters in TEE using Vault DON key
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 2: Decrypting parameters in TEE...");

	// Retrieve decryption key from Vault DON (threshold-encrypted secret)
	const encryptionKey = runtime
		.getSecret({ id: "ENCRYPTION_KEY" })
		.result().value;
	runtime.log("[Tacit] Encryption key retrieved from Vault DON");

	// Decrypt both parties' parameters — only visible inside the TEE
	const paramsA = decryptTradeParams(encryptedParamsA, encryptionKey);
	runtime.log(
		`[Tacit] Party A decrypted: ${paramsA.amount} ${paramsA.asset} -> ${paramsA.wantAmount} ${paramsA.wantAsset}`,
	);

	const paramsB = decryptTradeParams(encryptedParamsB, encryptionKey);
	runtime.log(
		`[Tacit] Party B decrypted: ${paramsB.amount} ${paramsB.asset} -> ${paramsB.wantAmount} ${paramsB.wantAsset}`,
	);

	// -----------------------------------------------------------------------
	// Step 3: Verify bilateral parameter match
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 3: Verifying bilateral match...");

	const matchResult = verifyBilateralMatch(paramsA, paramsB);

	if (!matchResult.isMatch) {
		runtime.log(
			`[Tacit] MATCH FAILED: ${matchResult.reason} — initiating refund`,
		);
		writeReports(
			runtime,
			evmClient,
			evmConfig,
			tradeIdHex,
			ReportAction.Refund,
			`match-failed: ${matchResult.reason}`,
			false,
		);
		return "refund-match-failed";
	}

	runtime.log(
		`[Tacit] MATCH CONFIRMED: ${paramsA.amount} ${paramsA.asset} <-> ${paramsB.amount} ${paramsB.asset}`,
	);

	// -----------------------------------------------------------------------
	// Step 4: Check sanctions via Confidential HTTP (OFAC SDN)
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 4: Checking sanctions (OFAC SDN)...");
	runtime.log(
		`[Tacit] Sanctions API: ${runtime.config.sanctionsApiBaseUrl}/sanctions/check`,
	);

	const confHttp = new ConfidentialHTTPClient();

	const sanctionsResponse = confHttp
		.sendRequest(runtime, {
			request: {
				url: `${runtime.config.sanctionsApiBaseUrl}/sanctions/check`,
				method: "POST",
				bodyString: JSON.stringify({
					addresses: [partyAAddress, partyBAddress],
				}),
				multiHeaders: {
					"Content-Type": { values: ["application/json"] },
					Authorization: { values: ["Bearer {{.OFAC_API_KEY}}"] },
				},
			},
			vaultDonSecrets: [
				{ key: "OFAC_API_KEY", owner: runtime.config.owner },
			],
		})
		.result();

	if (sanctionsResponse.statusCode !== 200) {
		throw new Error(
			`[Tacit] Sanctions API error: HTTP ${sanctionsResponse.statusCode}`,
		);
	}

	const sanctionsData =
		parseResponseBody<SanctionsApiResponse>(sanctionsResponse.body);

	for (const r of sanctionsData.results) {
		const status = r.sanctioned ? "SANCTIONED" : "CLEAR";
		runtime.log(`[Tacit] Sanctions — ${r.address}: ${status}`);
	}
	runtime.log(
		`[Tacit] Sanctions result: ${sanctionsData.allClear ? "ALL CLEAR" : "SANCTIONS HIT — refund required"}`,
	);

	// -----------------------------------------------------------------------
	// Step 5: Check KYC via Confidential HTTP
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 5: Checking KYC/accreditation...");
	runtime.log(
		`[Tacit] KYC API: ${runtime.config.kycApiBaseUrl}/kyc/verify`,
	);

	const kycResponse = confHttp
		.sendRequest(runtime, {
			request: {
				url: `${runtime.config.kycApiBaseUrl}/kyc/verify`,
				method: "POST",
				bodyString: JSON.stringify({
					addresses: [partyAAddress, partyBAddress],
					requiredLevel: "accredited",
				}),
				multiHeaders: {
					"Content-Type": { values: ["application/json"] },
					Authorization: { values: ["Bearer {{.KYC_API_KEY}}"] },
				},
			},
			vaultDonSecrets: [
				{ key: "KYC_API_KEY", owner: runtime.config.owner },
			],
		})
		.result();

	if (kycResponse.statusCode !== 200) {
		throw new Error(
			`[Tacit] KYC API error: HTTP ${kycResponse.statusCode}`,
		);
	}

	const kycData = parseResponseBody<KycApiResponse>(kycResponse.body);

	for (const r of kycData.results) {
		const status = r.verified ? "VERIFIED" : "NOT VERIFIED";
		runtime.log(`[Tacit] KYC — ${r.address}: ${status} (level: ${r.level})`);
	}
	runtime.log(
		`[Tacit] KYC result: ${kycData.allVerified ? "ALL VERIFIED" : "VERIFICATION FAILED — refund required"}`,
	);

	// -----------------------------------------------------------------------
	// Compliance decision: aggregate sanctions + KYC results
	// -----------------------------------------------------------------------
	const compliance = makeComplianceDecision(
		sanctionsData.allClear,
		kycData.allVerified,
	);

	runtime.log(
		`[Tacit] Compliance: sanctions=${compliance.sanctionsPass ? "PASS" : "FAIL"} kyc=${compliance.kycPass ? "PASS" : "FAIL"}`,
	);

	const compliancePassed = compliance.sanctionsPass && compliance.kycPass;

	if (!compliancePassed) {
		runtime.log(
			"[Tacit] COMPLIANCE FAILED — initiating refund for all parties",
		);
		writeReports(
			runtime,
			evmClient,
			evmConfig,
			tradeIdHex,
			ReportAction.Refund,
			`compliance-failed: sanctions=${compliance.sanctionsPass} kyc=${compliance.kycPass}`,
			false,
		);
		return "refund-compliance-failed";
	}

	runtime.log("[Tacit] ALL COMPLIANCE CHECKS PASSED — proceeding to settlement");

	// -----------------------------------------------------------------------
	// Step 6: Execute settlement + write compliance attestation on-chain
	// -----------------------------------------------------------------------
	runtime.log("[Tacit] Step 6: Executing settlement + writing attestation...");

	writeReports(
		runtime,
		evmClient,
		evmConfig,
		tradeIdHex,
		ReportAction.Settle,
		"",
		true,
	);

	runtime.log(
		`[Tacit] Workflow complete for trade ${tradeIdHex} — all 6 steps done`,
	);
	return "settlement-complete";
};

// ---------------------------------------------------------------------------
// Report writer — writes settlement/refund + attestation reports on-chain
// ---------------------------------------------------------------------------

/**
 * Write settlement/refund report to OTCVault and compliance attestation
 * to ComplianceRegistry using the CRE report-based write pattern.
 *
 * Pattern: encode → runtime.report(prepareReportRequest()) → evmClient.writeReport()
 *          → KeystoneForwarder verifies DON signatures → contract.onReport()
 */
function writeReports(
	runtime: Runtime<Config>,
	evmClient: EVMClient,
	evmConfig: Config["evms"][0],
	tradeIdHex: `0x${string}`,
	action: ReportAction,
	reason: string,
	compliancePassed: boolean,
): void {
	const actionLabel = action === ReportAction.Settle ? "SETTLEMENT" : "REFUND";

	// -------------------------------------------------------------------
	// Step 6a: Write settlement/refund report to OTCVault
	// -------------------------------------------------------------------
	runtime.log(`[Tacit] Step 6a: Writing ${actionLabel} report to OTCVault...`);

	const settlementPayload = encodeSettlementReport(tradeIdHex, action, reason);
	runtime.log(`[Tacit] Report: tradeId=${tradeIdHex} action=${actionLabel} reason="${reason}"`);

	const settlementCallData = encodeFunctionData({
		abi: IRECEIVER_ABI,
		functionName: "onReport",
		args: ["0x" as `0x${string}`, settlementPayload],
	});

	const settlementReport = runtime
		.report(prepareReportRequest(settlementCallData))
		.result();
	runtime.log("[Tacit] Settlement report signed by DON");

	const settlementResp = evmClient
		.writeReport(runtime, {
			receiver: evmConfig.otcVaultAddress,
			report: settlementReport,
		})
		.result();

	if (settlementResp.txStatus !== TxStatus.SUCCESS) {
		throw new Error(
			`[Tacit] ${actionLabel} report to OTCVault failed: ${settlementResp.errorMessage}`,
		);
	}
	runtime.log(
		`[Tacit] ${actionLabel} report written to OTCVault via KeystoneForwarder`,
	);

	// -------------------------------------------------------------------
	// Step 6b: Write compliance attestation to ComplianceRegistry
	// -------------------------------------------------------------------
	runtime.log("[Tacit] Step 6b: Writing compliance attestation...");

	const timestamp = Math.floor(Date.now() / 1000);
	const attestationPayload = encodeAttestationReport(
		tradeIdHex,
		compliancePassed,
		timestamp,
	);
	runtime.log(
		`[Tacit] Attestation: tradeId=${tradeIdHex} compliance=${compliancePassed ? "PASS" : "FAIL"} timestamp=${timestamp}`,
	);
	runtime.log(
		"[Tacit] (No amounts, no assets, no identities — privacy preserved)",
	);

	const attestationCallData = encodeFunctionData({
		abi: IRECEIVER_ABI,
		functionName: "onReport",
		args: ["0x" as `0x${string}`, attestationPayload],
	});

	const attestationReport = runtime
		.report(prepareReportRequest(attestationCallData))
		.result();
	runtime.log("[Tacit] Attestation report signed by DON");

	const attestationResp = evmClient
		.writeReport(runtime, {
			receiver: evmConfig.complianceRegistryAddress,
			report: attestationReport,
		})
		.result();

	if (attestationResp.txStatus !== TxStatus.SUCCESS) {
		throw new Error(
			`[Tacit] Attestation report to ComplianceRegistry failed: ${attestationResp.errorMessage}`,
		);
	}
	runtime.log(
		"[Tacit] Attestation written to ComplianceRegistry via KeystoneForwarder",
	);
	runtime.log(
		`[Tacit] Public sees ONLY: Trade ${tradeIdHex} | Compliance: ${compliancePassed ? "PASS" : "FAIL"}`,
	);
}

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
				addresses: [evmConfig.otcVaultAddress],
				// Filter for BothPartiesDeposited(bytes32 indexed tradeId) only
				topics: [
					{ values: [BOTH_PARTIES_DEPOSITED_TOPIC] }, // topic[0] = event signature
					{ values: [] }, // topic[1] = any tradeId (no filter)
					{ values: [] }, // unused
					{ values: [] }, // unused
				],
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
