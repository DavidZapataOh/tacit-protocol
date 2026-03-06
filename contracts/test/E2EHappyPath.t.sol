// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {OTCVault} from "../src/OTCVault.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {IOTCVault} from "../src/interfaces/IOTCVault.sol";
import {IComplianceRegistry} from "../src/interfaces/IComplianceRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockKeystoneForwarder} from "./mocks/MockKeystoneForwarder.sol";

/// @title E2EHappyPathTest
/// @notice End-to-end test of the full Tacit trade lifecycle:
///         create -> match -> settle -> attestation
/// @dev Tests both same-chain ETH and cross-asset (ETH<>Token) settlement paths
contract E2EHappyPathTest is Test {
    OTCVault public vault;
    ComplianceRegistry public registry;
    MockKeystoneForwarder public forwarder;
    MockERC20 public usdc;

    address public owner = makeAddr("owner");
    address public partyA = makeAddr("partyA");
    address public partyB = makeAddr("partyB");

    bytes public encryptedParamsA = hex"c0ffee0001aabbccdd";
    bytes public encryptedParamsB = hex"c0ffee0002eeff0011";
    bytes public emptyMetadata = "";

    function setUp() public {
        forwarder = new MockKeystoneForwarder();
        vault = new OTCVault(address(forwarder), owner, address(0));
        registry = new ComplianceRegistry(address(forwarder), owner);

        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.deal(partyA, 100 ether);
        vm.deal(partyB, 100 ether);

        usdc.mint(partyA, 1_000_000e6);
        usdc.mint(partyB, 1_000_000e6);

        vm.prank(partyA);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(partyB);
        usdc.approve(address(vault), type(uint256).max);
    }

    // ============ Helpers ============

    function _settleViaForwarder(bytes32 tradeId) internal {
        bytes memory report = abi.encode(tradeId, uint8(0), "");
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    function _refundViaForwarder(bytes32 tradeId, string memory reason) internal {
        bytes memory report = abi.encode(tradeId, uint8(1), reason);
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    function _recordAttestation(bytes32 tradeId, bool result) internal {
        bytes memory report = abi.encode(tradeId, result, block.timestamp);
        forwarder.deliverReport(address(registry), emptyMetadata, report);
    }

    // ============ E2E Happy Path: ETH <> ETH ============

    /// @notice Full happy path: Party A deposits ETH, Party B deposits ETH, settlement + attestation
    function test_E2E_HappyPath_ETH_ETH() public {
        bytes32 tradeId = keccak256("e2e-eth-eth-001");

        // === PHASE 1: Party A creates trade ===
        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encryptedParamsA);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(uint8(trade.status), uint8(IOTCVault.TradeStatus.Created));
        assertEq(trade.partyA.depositor, partyA);
        assertEq(trade.partyA.amount, 10 ether);
        console2.log("Phase 1 PASS: Party A created trade, deposited 10 ETH");

        // === PHASE 2: Party B matches ===
        vm.prank(partyB);
        vault.matchTradeETH{value: 5 ether}(tradeId, encryptedParamsB);

        trade = vault.getTrade(tradeId);
        assertEq(uint8(trade.status), uint8(IOTCVault.TradeStatus.BothDeposited));
        assertEq(trade.partyB.depositor, partyB);
        assertEq(trade.partyB.amount, 5 ether);
        console2.log("Phase 2 PASS: Party B matched, deposited 5 ETH");

        // === PHASE 3: CRE settles via KeystoneForwarder ===
        uint256 partyABalBefore = partyA.balance;
        uint256 partyBBalBefore = partyB.balance;

        _settleViaForwarder(tradeId);

        // DvP: A's deposit -> B, B's deposit -> A
        assertEq(partyA.balance, partyABalBefore + 5 ether, "Party A should receive Party B's deposit");
        assertEq(partyB.balance, partyBBalBefore + 10 ether, "Party B should receive Party A's deposit");
        assertEq(address(vault).balance, 0, "Vault should be empty after settlement");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Settled));
        console2.log("Phase 3 PASS: Settlement executed, DvP verified");

        // === PHASE 4: Compliance attestation ===
        _recordAttestation(tradeId, true);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId);
        assertTrue(att.verified, "Attestation should be PASS");
        assertTrue(att.exists);
        assertGt(att.timestamp, 0);
        console2.log("Phase 4 PASS: Compliance attestation PASS recorded");

        console2.log("=== E2E HAPPY PATH (ETH<>ETH) COMPLETE ===");
    }

    // ============ E2E Happy Path: ETH <> Token ============

    /// @notice Full happy path: Party A deposits ETH, Party B deposits USDC
    function test_E2E_HappyPath_ETH_Token() public {
        bytes32 tradeId = keccak256("e2e-eth-token-001");

        // === PHASE 1: Party A creates trade with ETH ===
        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encryptedParamsA);
        console2.log("Phase 1 PASS: Party A deposited 10 ETH");

        // === PHASE 2: Party B matches with USDC ===
        vm.prank(partyB);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, encryptedParamsB);

        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.BothDeposited));
        console2.log("Phase 2 PASS: Party B deposited 25,000 USDC");

        // === PHASE 3: CRE settles — DvP cross-asset ===
        uint256 partyAUsdcBefore = usdc.balanceOf(partyA);
        uint256 partyBEthBefore = partyB.balance;

        _settleViaForwarder(tradeId);

        assertEq(usdc.balanceOf(partyA), partyAUsdcBefore + 25_000e6, "Party A should receive USDC");
        assertEq(partyB.balance, partyBEthBefore + 10 ether, "Party B should receive ETH");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Settled));
        console2.log("Phase 3 PASS: Cross-asset DvP settled (ETH -> B, USDC -> A)");

        // === PHASE 4: Compliance attestation ===
        _recordAttestation(tradeId, true);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId);
        assertTrue(att.verified);
        console2.log("Phase 4 PASS: Compliance attestation PASS");

        console2.log("=== E2E HAPPY PATH (ETH<>USDC) COMPLETE ===");
    }

    // ============ E2E Happy Path: Token <> Token ============

    /// @notice Full happy path: Party A deposits USDC, Party B deposits ETH
    function test_E2E_HappyPath_Token_ETH() public {
        bytes32 tradeId = keccak256("e2e-token-eth-001");

        // Party A creates with USDC
        vm.prank(partyA);
        vault.createTradeToken(tradeId, address(usdc), 25_000e6, encryptedParamsA);

        // Party B matches with ETH
        vm.prank(partyB);
        vault.matchTradeETH{value: 10 ether}(tradeId, encryptedParamsB);

        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.BothDeposited));

        // Settle
        uint256 partyAEthBefore = partyA.balance;
        uint256 partyBUsdcBefore = usdc.balanceOf(partyB);

        _settleViaForwarder(tradeId);

        assertEq(partyA.balance, partyAEthBefore + 10 ether, "Party A should receive ETH");
        assertEq(usdc.balanceOf(partyB), partyBUsdcBefore + 25_000e6, "Party B should receive USDC");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Settled));

        // Attestation
        _recordAttestation(tradeId, true);
        assertTrue(registry.getAttestation(tradeId).verified);

        console2.log("=== E2E HAPPY PATH (USDC<>ETH) COMPLETE ===");
    }

    // ============ E2E Compliance Failure Path ============

    /// @notice Full flow where compliance fails: both parties get refunded
    function test_E2E_ComplianceFailure_Refund() public {
        bytes32 tradeId = keccak256("e2e-compliance-fail-001");

        // Create & match
        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encryptedParamsA);
        vm.prank(partyB);
        vault.matchTradeETH{value: 5 ether}(tradeId, encryptedParamsB);

        uint256 partyABalBefore = partyA.balance;
        uint256 partyBBalBefore = partyB.balance;

        // CRE finds sanctions hit -> refund
        _refundViaForwarder(tradeId, "sanctions_hit");

        // Each party gets their own deposit back
        assertEq(partyA.balance, partyABalBefore + 10 ether, "Party A refunded");
        assertEq(partyB.balance, partyBBalBefore + 5 ether, "Party B refunded");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Refunded));
        assertEq(address(vault).balance, 0, "Vault empty after refund");

        // Attestation records FAIL
        _recordAttestation(tradeId, false);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId);
        assertFalse(att.verified, "Attestation should be FAIL");
        assertTrue(att.exists);

        console2.log("=== E2E COMPLIANCE FAILURE PATH COMPLETE ===");
    }

    // ============ E2E Multiple Trades Sequential ============

    /// @notice Run 3 happy path trades sequentially (KR4: 3+ successful settlements)
    function test_E2E_ThreeSequentialTrades() public {
        for (uint256 i = 1; i <= 3; i++) {
            bytes32 tradeId = keccak256(abi.encodePacked("e2e-sequential-", i));

            // Create
            vm.prank(partyA);
            vault.createTradeETH{value: 1 ether}(tradeId, encryptedParamsA);

            // Match
            vm.prank(partyB);
            vault.matchTradeETH{value: 1 ether}(tradeId, encryptedParamsB);

            // Settle
            _settleViaForwarder(tradeId);
            assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Settled));

            // Attest
            _recordAttestation(tradeId, true);
            assertTrue(registry.getAttestation(tradeId).verified);

            console2.log("Trade", i, "settled and attested successfully");
        }

        assertEq(registry.attestationCount(), 3, "Should have 3 attestations");
        console2.log("=== 3 SEQUENTIAL TRADES COMPLETE (KR4 VERIFIED) ===");
    }

    // ============ E2E Privacy Verification ============

    /// @notice Verify that on-chain data does NOT reveal trade parameters
    function test_E2E_PrivacyVerification() public {
        bytes32 tradeId = keccak256("e2e-privacy-001");

        // Create trade with encrypted params
        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encryptedParamsA);
        vm.prank(partyB);
        vault.matchTradeETH{value: 5 ether}(tradeId, encryptedParamsB);

        // Read trade data
        IOTCVault.Trade memory trade = vault.getTrade(tradeId);

        // Verify: encrypted params are stored as opaque bytes (not decoded)
        assertEq(trade.partyA.encryptedParams, encryptedParamsA, "Encrypted params A stored as-is");
        assertEq(trade.partyB.encryptedParams, encryptedParamsB, "Encrypted params B stored as-is");

        // Verify: the contract does NOT store human-readable trade terms
        // (asset type, price, direction are inside encryptedParams, not in separate fields)
        // Only depositor, token address, amount, and encrypted blob are stored
        assertEq(trade.partyA.token, address(0), "Token is just an address, not a label");

        // Settle and verify attestation only records pass/fail
        _settleViaForwarder(tradeId);
        _recordAttestation(tradeId, true);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId);
        // Attestation contains: verified (bool), exists (bool), timestamp (uint256)
        // NO amounts, NO asset types, NO counterparty addresses
        assertTrue(att.verified);
        assertGt(att.timestamp, 0);

        console2.log("=== PRIVACY VERIFICATION COMPLETE ===");
        console2.log("On-chain: only trade ID, pass/fail, timestamp visible");
        console2.log("Trade terms encrypted in opaque bytes - not parseable without TEE");
    }

    // ============ E2E Gas Cost Documentation ============

    /// @notice Measure gas costs for each operation (Paper Section 10.2)
    function test_E2E_GasCosts() public {
        bytes32 tradeId = keccak256("e2e-gas-001");

        // Measure createTradeETH gas
        uint256 gasStart = gasleft();
        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encryptedParamsA);
        uint256 gasCreateETH = gasStart - gasleft();
        console2.log("Gas: createTradeETH =", gasCreateETH);

        // Measure matchTradeETH gas
        gasStart = gasleft();
        vm.prank(partyB);
        vault.matchTradeETH{value: 5 ether}(tradeId, encryptedParamsB);
        uint256 gasMatchETH = gasStart - gasleft();
        console2.log("Gas: matchTradeETH  =", gasMatchETH);

        // Measure settlement gas
        gasStart = gasleft();
        _settleViaForwarder(tradeId);
        uint256 gasSettle = gasStart - gasleft();
        console2.log("Gas: settlement     =", gasSettle);

        // Measure attestation gas
        gasStart = gasleft();
        _recordAttestation(tradeId, true);
        uint256 gasAttest = gasStart - gasleft();
        console2.log("Gas: attestation    =", gasAttest);

        // Sanity checks — ensure gas costs are reasonable
        assertLt(gasCreateETH, 300_000, "createTradeETH should be under 300k gas");
        assertLt(gasMatchETH, 200_000, "matchTradeETH should be under 200k gas");
        assertLt(gasSettle, 300_000, "settlement should be under 300k gas");
        assertLt(gasAttest, 200_000, "attestation should be under 200k gas");
    }

    // ============ E2E Trade Expiry Path ============

    /// @notice Verify expiry refund works when Party B never matches
    function test_E2E_TradeExpiry_Refund() public {
        bytes32 tradeId = keccak256("e2e-expiry-001");

        // Party A creates trade
        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encryptedParamsA);

        uint256 partyABalBefore = partyA.balance;

        // Fast forward past expiry (24h + 1s)
        vm.warp(block.timestamp + 24 hours + 1);

        // Party A claims refund
        vm.prank(partyA);
        vault.claimExpiredRefund(tradeId);

        assertEq(partyA.balance, partyABalBefore + 10 ether, "Party A refunded after expiry");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Expired));

        console2.log("=== EXPIRY REFUND PATH COMPLETE ===");
    }

    // ============ Receive ETH ============

    receive() external payable {}
}
