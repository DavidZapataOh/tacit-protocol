// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {OTCVault} from "../src/OTCVault.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {IOTCVault} from "../src/interfaces/IOTCVault.sol";
import {IComplianceRegistry} from "../src/interfaces/IComplianceRegistry.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockKeystoneForwarder} from "./mocks/MockKeystoneForwarder.sol";

/// @title E2EFailurePathsTest
/// @notice End-to-end tests for all failure modes documented in Paper Section 6.3:
///         compliance failure, parameter mismatch, timeout, double settle/refund,
///         unauthorized callers, and edge cases.
contract E2EFailurePathsTest is Test {
    OTCVault public vault;
    ComplianceRegistry public registry;
    MockKeystoneForwarder public forwarder;
    MockERC20 public usdc;

    address public owner = makeAddr("owner");
    address public partyA = makeAddr("partyA");
    address public partyB = makeAddr("partyB");
    address public attacker = makeAddr("attacker");

    bytes public encA = hex"c0ffee0001";
    bytes public encB = hex"c0ffee0002";
    bytes public emptyMetadata = "";

    function setUp() public {
        forwarder = new MockKeystoneForwarder();
        vault = new OTCVault(address(forwarder), owner, address(0));
        registry = new ComplianceRegistry(address(forwarder), owner);

        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.deal(partyA, 100 ether);
        vm.deal(partyB, 100 ether);
        vm.deal(attacker, 100 ether);

        usdc.mint(partyA, 1_000_000e6);
        usdc.mint(partyB, 1_000_000e6);

        vm.prank(partyA);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(partyB);
        usdc.approve(address(vault), type(uint256).max);
    }

    // ============ Helpers ============

    function _createAndMatch(bytes32 tradeId, uint256 amountA, uint256 amountB) internal {
        vm.prank(partyA);
        vault.createTradeETH{value: amountA}(tradeId, encA);
        vm.prank(partyB);
        vault.matchTradeETH{value: amountB}(tradeId, encB);
    }

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

    // ================================================================
    //  FAILURE PATH 1: Compliance Failure (Sanctioned Address -> Refund)
    // ================================================================

    /// @notice Full E2E: sanctioned address detected by CRE -> refund + FAIL attestation
    function test_E2E_ComplianceFail_SanctionedAddress() public {
        bytes32 tradeId = keccak256("sanctions-fail-001");

        // Both parties deposit
        _createAndMatch(tradeId, 10 ether, 5 ether);

        uint256 balA = partyA.balance;
        uint256 balB = partyB.balance;

        // CRE detects sanctions hit -> sends refund report
        _refundViaForwarder(tradeId, "sanctions_hit");

        // Both parties get their deposits back
        assertEq(partyA.balance, balA + 10 ether, "Party A not refunded");
        assertEq(partyB.balance, balB + 5 ether, "Party B not refunded");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Refunded));
        assertEq(address(vault).balance, 0, "Vault not empty");

        // CRE also writes FAIL attestation
        _recordAttestation(tradeId, false);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId);
        assertFalse(att.verified, "Attestation should be FAIL");
        assertTrue(att.exists);

        console2.log("PASS: Sanctioned address -> refund + FAIL attestation");
    }

    /// @notice Compliance fail with cross-asset trade (ETH <> USDC)
    function test_E2E_ComplianceFail_CrossAsset() public {
        bytes32 tradeId = keccak256("sanctions-cross-asset");

        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encA);
        vm.prank(partyB);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, encB);

        uint256 ethBalA = partyA.balance;
        uint256 usdcBalB = usdc.balanceOf(partyB);

        _refundViaForwarder(tradeId, "kyc_failed");

        // Each party gets THEIR OWN deposit back (not swapped)
        assertEq(partyA.balance, ethBalA + 10 ether, "Party A ETH not refunded");
        assertEq(usdc.balanceOf(partyB), usdcBalB + 25_000e6, "Party B USDC not refunded");

        _recordAttestation(tradeId, false);
        assertFalse(registry.getAttestation(tradeId).verified);

        console2.log("PASS: Cross-asset compliance fail -> correct asset refund");
    }

    // ================================================================
    //  FAILURE PATH 2: Parameter Mismatch (Different terms -> Refund)
    // ================================================================

    /// @notice CRE detects parameter mismatch in TEE -> refund both parties
    function test_E2E_ParameterMismatch_Refund() public {
        bytes32 tradeId = keccak256("mismatch-001");

        // Different encrypted params (CRE will detect mismatch in TEE)
        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, hex"aabb"); // "wants 25000 USDC"
        vm.prank(partyB);
        vault.matchTradeETH{value: 5 ether}(tradeId, hex"ccdd"); // "wants 20000 USDC" (mismatch)

        uint256 balA = partyA.balance;
        uint256 balB = partyB.balance;

        _refundViaForwarder(tradeId, "parameter_mismatch");

        assertEq(partyA.balance, balA + 10 ether);
        assertEq(partyB.balance, balB + 5 ether);
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Refunded));

        console2.log("PASS: Parameter mismatch -> both refunded");
    }

    // ================================================================
    //  FAILURE PATH 3: Timeout (Party B never deposits)
    // ================================================================

    /// @notice Party B never matches -> Party A claims refund after 24h expiry
    function test_E2E_Timeout_PartyARefunded() public {
        bytes32 tradeId = keccak256("timeout-001");

        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encA);

        uint256 balBefore = partyA.balance;

        // Fast-forward past 24h expiry
        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(partyA);
        vault.claimExpiredRefund(tradeId);

        assertEq(partyA.balance, balBefore + 10 ether, "Party A not refunded after timeout");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Expired));

        console2.log("PASS: Timeout -> Party A refunded");
    }

    /// @notice Cannot claim refund before expiry
    function test_RevertIf_RefundBeforeExpiry() public {
        bytes32 tradeId = keccak256("early-refund");

        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encA);

        // Try immediately (before 24h)
        vm.prank(partyA);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeNotExpired.selector, tradeId));
        vault.claimExpiredRefund(tradeId);

        console2.log("PASS: Cannot refund before expiry");
    }

    /// @notice Token trade timeout refund
    function test_E2E_Timeout_Token_Refund() public {
        bytes32 tradeId = keccak256("timeout-token");

        vm.prank(partyA);
        vault.createTradeToken(tradeId, address(usdc), 25_000e6, encA);

        uint256 usdcBefore = usdc.balanceOf(partyA);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(partyA);
        vault.claimExpiredRefund(tradeId);

        assertEq(usdc.balanceOf(partyA), usdcBefore + 25_000e6, "USDC not refunded");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Expired));

        console2.log("PASS: Token timeout -> refunded");
    }

    // ================================================================
    //  FAILURE PATH 4: Double Settle / Double Refund
    // ================================================================

    /// @notice Double settle attempt -> revert
    function test_RevertIf_DoubleSettle() public {
        bytes32 tradeId = keccak256("double-settle");
        _createAndMatch(tradeId, 10 ether, 5 ether);

        _settleViaForwarder(tradeId);

        // Second settlement reverts
        bytes memory report = abi.encode(tradeId, uint8(0), "");
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.Settled,
                IOTCVault.TradeStatus.BothDeposited
            )
        );
        forwarder.deliverReport(address(vault), emptyMetadata, report);

        console2.log("PASS: Double settle reverts");
    }

    /// @notice Double refund attempt -> revert
    function test_RevertIf_DoubleRefund() public {
        bytes32 tradeId = keccak256("double-refund");
        _createAndMatch(tradeId, 10 ether, 5 ether);

        _refundViaForwarder(tradeId, "first_refund");

        // Second refund reverts
        bytes memory report = abi.encode(tradeId, uint8(1), "second_attempt");
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.Refunded,
                IOTCVault.TradeStatus.BothDeposited
            )
        );
        forwarder.deliverReport(address(vault), emptyMetadata, report);

        console2.log("PASS: Double refund reverts");
    }

    /// @notice Refund after settlement -> revert
    function test_RevertIf_RefundAfterSettle() public {
        bytes32 tradeId = keccak256("refund-after-settle");
        _createAndMatch(tradeId, 10 ether, 5 ether);

        _settleViaForwarder(tradeId);

        bytes memory report = abi.encode(tradeId, uint8(1), "too_late");
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.Settled,
                IOTCVault.TradeStatus.BothDeposited
            )
        );
        forwarder.deliverReport(address(vault), emptyMetadata, report);

        console2.log("PASS: Cannot refund after settlement");
    }

    /// @notice Settle after refund -> revert
    function test_RevertIf_SettleAfterRefund() public {
        bytes32 tradeId = keccak256("settle-after-refund");
        _createAndMatch(tradeId, 10 ether, 5 ether);

        _refundViaForwarder(tradeId, "compliance_failed");

        bytes memory report = abi.encode(tradeId, uint8(0), "");
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.Refunded,
                IOTCVault.TradeStatus.BothDeposited
            )
        );
        forwarder.deliverReport(address(vault), emptyMetadata, report);

        console2.log("PASS: Cannot settle after refund");
    }

    // ================================================================
    //  FAILURE PATH 5: Unauthorized Callers
    // ================================================================

    /// @notice Non-forwarder tries to settle -> revert
    function test_RevertIf_UnauthorizedSettlement() public {
        bytes32 tradeId = keccak256("unauth-settle");
        _createAndMatch(tradeId, 10 ether, 5 ether);

        bytes memory report = abi.encode(tradeId, uint8(0), "");

        vm.prank(attacker);
        vm.expectRevert(IOTCVault.OnlyForwarder.selector);
        vault.onReport(emptyMetadata, report);

        console2.log("PASS: Unauthorized settlement reverts");
    }

    /// @notice Non-forwarder tries to write attestation -> revert
    function test_RevertIf_UnauthorizedAttestation() public {
        bytes memory report = abi.encode(keccak256("unauth-att"), true, block.timestamp);

        vm.prank(attacker);
        vm.expectRevert(IComplianceRegistry.OnlyForwarder.selector);
        registry.onReport(emptyMetadata, report);

        console2.log("PASS: Unauthorized attestation reverts");
    }

    /// @notice Party B tries to claim expired refund (only Party A can)
    function test_RevertIf_NonDepositorClaimsExpiry() public {
        bytes32 tradeId = keccak256("wrong-claimer");

        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encA);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(partyB);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.OnlyDepositor.selector, tradeId));
        vault.claimExpiredRefund(tradeId);

        console2.log("PASS: Non-depositor cannot claim expiry refund");
    }

    // ================================================================
    //  FAILURE PATH 6: Invalid Inputs
    // ================================================================

    /// @notice Zero ETH deposit -> revert
    function test_RevertIf_ZeroETHDeposit() public {
        vm.prank(partyA);
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        vault.createTradeETH{value: 0}(keccak256("zero"), encA);
    }

    /// @notice Empty encrypted params -> revert
    function test_RevertIf_EmptyEncryptedParams() public {
        vm.prank(partyA);
        vm.expectRevert(IOTCVault.EmptyEncryptedParams.selector);
        vault.createTradeETH{value: 1 ether}(keccak256("empty"), "");
    }

    /// @notice Duplicate trade ID -> revert
    function test_RevertIf_DuplicateTradeId() public {
        bytes32 tradeId = keccak256("duplicate");

        vm.prank(partyA);
        vault.createTradeETH{value: 1 ether}(tradeId, encA);

        vm.prank(partyB);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeAlreadyExists.selector, tradeId));
        vault.createTradeETH{value: 1 ether}(tradeId, encB);
    }

    /// @notice Match non-existent trade -> revert
    function test_RevertIf_MatchNonExistentTrade() public {
        bytes32 tradeId = keccak256("ghost-trade");

        vm.prank(partyB);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.None,
                IOTCVault.TradeStatus.Created
            )
        );
        vault.matchTradeETH{value: 1 ether}(tradeId, encB);
    }

    /// @notice Self-match -> revert
    function test_RevertIf_SelfMatch() public {
        bytes32 tradeId = keccak256("self-match");

        vm.prank(partyA);
        vault.createTradeETH{value: 1 ether}(tradeId, encA);

        vm.prank(partyA);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.CannotMatchOwnTrade.selector, tradeId));
        vault.matchTradeETH{value: 1 ether}(tradeId, encA);
    }

    /// @notice Third party tries to match already-matched trade -> revert
    function test_RevertIf_AlreadyMatched() public {
        bytes32 tradeId = keccak256("already-matched");
        _createAndMatch(tradeId, 1 ether, 1 ether);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.BothDeposited,
                IOTCVault.TradeStatus.Created
            )
        );
        vault.matchTradeETH{value: 1 ether}(tradeId, hex"aabb");
    }

    /// @notice Settle trade that only has Party A (not BothDeposited) -> revert
    function test_RevertIf_SettleBeforeMatch() public {
        bytes32 tradeId = keccak256("premature-settle");

        vm.prank(partyA);
        vault.createTradeETH{value: 10 ether}(tradeId, encA);

        bytes memory report = abi.encode(tradeId, uint8(0), "");
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.Created,
                IOTCVault.TradeStatus.BothDeposited
            )
        );
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    /// @notice Invalid report action (not 0, 1, or 2) -> revert
    function test_RevertIf_InvalidReportAction() public {
        bytes32 tradeId = keccak256("invalid-action");
        _createAndMatch(tradeId, 1 ether, 1 ether);

        bytes memory report = abi.encode(tradeId, uint8(99), "");
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.InvalidAction.selector, uint8(99)));
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    /// @notice Duplicate attestation for same trade -> revert
    function test_RevertIf_DuplicateAttestation() public {
        bytes32 tradeId = keccak256("dup-attestation");

        _recordAttestation(tradeId, true);

        bytes memory report = abi.encode(tradeId, false, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IComplianceRegistry.AttestationAlreadyExists.selector, tradeId));
        forwarder.deliverReport(address(registry), emptyMetadata, report);
    }

    /// @notice Zero token amount -> revert
    function test_RevertIf_ZeroTokenAmount() public {
        vm.prank(partyA);
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        vault.createTradeToken(keccak256("zero-token"), address(usdc), 0, encA);
    }

    /// @notice Zero token address -> revert
    function test_RevertIf_ZeroTokenAddress() public {
        vm.prank(partyA);
        vm.expectRevert(IOTCVault.ZeroDeposit.selector);
        vault.createTradeToken(keccak256("zero-addr"), address(0), 1000e6, encA);
    }

    /// @notice Match with zero ETH -> revert
    function test_RevertIf_MatchZeroETH() public {
        bytes32 tradeId = keccak256("match-zero");
        vm.prank(partyA);
        vault.createTradeETH{value: 1 ether}(tradeId, encA);

        vm.prank(partyB);
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        vault.matchTradeETH{value: 0}(tradeId, encB);
    }

    /// @notice Match expired trade -> revert
    function test_RevertIf_MatchExpiredTrade() public {
        bytes32 tradeId = keccak256("match-expired");
        vm.prank(partyA);
        vault.createTradeETH{value: 1 ether}(tradeId, encA);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(partyB);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeExpired.selector, tradeId));
        vault.matchTradeETH{value: 1 ether}(tradeId, encB);
    }

    // ================================================================
    //  FAILURE PATH 7: Value Preservation Invariant
    // ================================================================

    /// @notice Verify total value is preserved through refund (no funds lost)
    function test_E2E_ValuePreservation_Refund() public {
        bytes32 tradeId = keccak256("value-preservation");

        uint256 totalBefore = partyA.balance + partyB.balance + address(vault).balance;

        _createAndMatch(tradeId, 10 ether, 5 ether);
        _refundViaForwarder(tradeId, "test_refund");

        uint256 totalAfter = partyA.balance + partyB.balance + address(vault).balance;
        assertEq(totalBefore, totalAfter, "Value not preserved through refund");

        console2.log("PASS: Value preserved through refund cycle");
    }

    /// @notice Value preserved through settlement
    function test_E2E_ValuePreservation_Settlement() public {
        bytes32 tradeId = keccak256("value-settle");

        uint256 totalBefore = partyA.balance + partyB.balance + address(vault).balance;

        _createAndMatch(tradeId, 10 ether, 5 ether);
        _settleViaForwarder(tradeId);

        uint256 totalAfter = partyA.balance + partyB.balance + address(vault).balance;
        assertEq(totalBefore, totalAfter, "Value not preserved through settlement");

        console2.log("PASS: Value preserved through settlement cycle");
    }

    // ================================================================
    //  FUZZ TESTS
    // ================================================================

    /// @notice Fuzz: any deposit amount > 0 should succeed
    function testFuzz_CreateTrade_AnyAmount(uint256 amount) public {
        amount = bound(amount, 1, 50 ether);
        bytes32 tradeId = keccak256(abi.encodePacked("fuzz-create-", amount));

        vm.prank(partyA);
        vault.createTradeETH{value: amount}(tradeId, encA);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(trade.partyA.amount, amount);
    }

    /// @notice Fuzz: settlement with any valid amounts preserves total value
    function testFuzz_Settlement_ValuePreservation(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1, 50 ether);
        amountB = bound(amountB, 1, 50 ether);
        bytes32 tradeId = keccak256(abi.encodePacked("fuzz-settle-", amountA, amountB));

        uint256 totalBefore = partyA.balance + partyB.balance;

        _createAndMatch(tradeId, amountA, amountB);
        _settleViaForwarder(tradeId);

        uint256 totalAfter = partyA.balance + partyB.balance;
        assertEq(totalBefore, totalAfter, "Fuzz: value not preserved");
    }

    /// @notice Fuzz: refund with any valid amounts preserves total value
    function testFuzz_Refund_ValuePreservation(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1, 50 ether);
        amountB = bound(amountB, 1, 50 ether);
        bytes32 tradeId = keccak256(abi.encodePacked("fuzz-refund-", amountA, amountB));

        uint256 totalBefore = partyA.balance + partyB.balance;

        _createAndMatch(tradeId, amountA, amountB);
        _refundViaForwarder(tradeId, "fuzz");

        uint256 totalAfter = partyA.balance + partyB.balance;
        assertEq(totalBefore, totalAfter, "Fuzz: value not preserved on refund");
    }

    /// @notice Fuzz: settlement on non-existent trade always reverts
    function testFuzz_SettleNonExistent_Reverts(bytes32 randomId) public {
        bytes memory report = abi.encode(randomId, uint8(0), "");
        vm.expectRevert();
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    /// @notice Fuzz: any trade ID for attestation works
    function testFuzz_Attestation_AnyTradeId(bytes32 tradeId) public {
        _recordAttestation(tradeId, true);
        assertTrue(registry.hasAttestation(tradeId));
    }

    // ============ Receive ETH ============

    receive() external payable {}
}
