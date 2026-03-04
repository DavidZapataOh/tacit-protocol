// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {CCIPLocalSimulator} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

import {OTCVault} from "../src/OTCVault.sol";
import {IOTCVault} from "../src/interfaces/IOTCVault.sol";
import {OTCVaultReceiver} from "../src/OTCVaultReceiver.sol";
import {SettlementEncoder} from "../src/libraries/SettlementEncoder.sol";
import {TacitConstants} from "../src/libraries/TacitConstants.sol";
import {MockKeystoneForwarder} from "./mocks/MockKeystoneForwarder.sol";

/// @title CCIP Cross-Chain Settlement Tests
/// @notice Integration tests for cross-chain DvP using CCIPLocalSimulator.
///         Tests the full flow: OTCVault → CCIP Router → OTCVaultReceiver.
/// @dev Uses CCIPLocalSimulator which delivers CCIP messages synchronously
///      in a single transaction, enabling deterministic end-to-end testing.
contract CCIPTest is Test {
    // ═══════════════════════════════════════════════════════
    //                    TEST FIXTURES
    // ═══════════════════════════════════════════════════════

    CCIPLocalSimulator public ccipSimulator;
    OTCVault public vault;
    OTCVaultReceiver public receiver;
    MockKeystoneForwarder public forwarder;
    IRouterClient public router;
    uint64 public chainSelector;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public attacker = makeAddr("attacker");

    bytes32 public tradeId = keccak256("ccip-trade-001");
    bytes public aliceParams = hex"aabb01";
    bytes public bobParams = hex"aabb02";
    bytes public emptyMetadata = "";
    uint256 public constant TRADE_AMOUNT = 1 ether;

    // ═══════════════════════════════════════════════════════
    //                       SETUP
    // ═══════════════════════════════════════════════════════

    function setUp() public {
        // Deploy CCIP Local Simulator (provides MockRouter + chain selector)
        ccipSimulator = new CCIPLocalSimulator();
        (uint64 cs, IRouterClient r,,,,, ) = ccipSimulator.configuration();
        chainSelector = cs;
        router = r;

        // Deploy mock KeystoneForwarder for CRE report delivery
        forwarder = new MockKeystoneForwarder();

        // Deploy OTCVault (source chain) with CCIP router
        vm.prank(owner);
        vault = new OTCVault(address(forwarder), owner, address(router));

        // Deploy OTCVaultReceiver (destination chain) — same router in local sim
        vm.prank(owner);
        receiver = new OTCVaultReceiver(address(router));

        // Configure cross-chain trust relationships
        vm.startPrank(owner);
        vault.setAllowedReceiver(chainSelector, address(receiver));
        receiver.setAllowedSender(chainSelector, address(vault));
        vm.stopPrank();

        // Fund accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(address(vault), 10 ether); // For CCIP fees
        vm.deal(address(receiver), 10 ether); // For settlement distributions
    }

    // ═══════════════════════════════════════════════════════
    //                       HELPERS
    // ═══════════════════════════════════════════════════════

    function _createAndMatchETH(bytes32 tid, uint256 amountA, uint256 amountB) internal {
        vm.prank(alice);
        vault.createTradeETH{value: amountA}(tid, aliceParams);
        vm.prank(bob);
        vault.matchTradeETH{value: amountB}(tid, bobParams);
    }

    /// @dev Build a cross-chain settlement report (action=2) for OTCVault.onReport()
    function _buildCrossChainReport(bytes32 tid, address recipient, uint256 amount)
        internal
        view
        returns (bytes memory)
    {
        bytes memory settlementPayload = SettlementEncoder.encode(
            SettlementEncoder.SettlementInstruction({
                tradeId: tid,
                recipient: recipient,
                token: address(0),
                amount: amount
            })
        );
        bytes memory crossChainData = abi.encode(chainSelector, settlementPayload);
        return abi.encode(tid, uint8(2), crossChainData);
    }

    /// @dev Send a cross-chain settlement report via MockKeystoneForwarder
    function _sendCrossChainReport(bytes32 tid, address recipient, uint256 amount) internal {
        bytes memory report = _buildCrossChainReport(tid, recipient, amount);
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    /// @dev Send a same-chain settlement report (action=0)
    function _settleViaForwarder(bytes32 tid) internal {
        bytes memory report = abi.encode(tid, uint8(0), "");
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    /// @dev Send a refund report (action=1)
    function _refundViaForwarder(bytes32 tid, string memory reason) internal {
        bytes memory report = abi.encode(tid, uint8(1), reason);
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    // ═══════════════════════════════════════════════════════
    //           CROSS-CHAIN: HAPPY PATH
    // ═══════════════════════════════════════════════════════

    /// @notice Full cross-chain settlement: deposit → onReport(action=2) → CCIP → receiver → recipient gets ETH
    function test_CrossChain_HappyPath() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        uint256 aliceBalBefore = alice.balance;
        uint256 receiverBalBefore = address(receiver).balance;

        _sendCrossChainReport(tradeId, alice, TRADE_AMOUNT);

        // Recipient received ETH on destination chain (from receiver's pre-funded balance)
        assertEq(alice.balance, aliceBalBefore + TRADE_AMOUNT, "Alice should receive ETH from receiver");
        assertEq(address(receiver).balance, receiverBalBefore - TRADE_AMOUNT, "Receiver balance should decrease");
    }

    /// @notice After cross-chain settlement, vault trade status is CrossChainPending
    function test_CrossChain_TradeStatusIsCrossChainPending() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        _sendCrossChainReport(tradeId, alice, TRADE_AMOUNT);

        assertEq(
            uint8(vault.getTradeStatus(tradeId)),
            uint8(IOTCVault.TradeStatus.CrossChainPending),
            "Trade should be CrossChainPending"
        );
    }

    /// @notice After cross-chain settlement, receiver marks trade as settled
    function test_CrossChain_ReceiverMarksSettled() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        assertFalse(receiver.isTradeSettled(tradeId), "Trade should NOT be settled before report");

        _sendCrossChainReport(tradeId, alice, TRADE_AMOUNT);

        assertTrue(receiver.isTradeSettled(tradeId), "Trade should be settled after CCIP delivery");
    }

    /// @notice Cross-chain records the CCIP message-to-trade mapping
    function test_CrossChain_CcipMessageMapped() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        _sendCrossChainReport(tradeId, alice, TRADE_AMOUNT);

        // The crossChainInitiatedAt timestamp should be set
        assertGt(vault.crossChainInitiatedAt(tradeId), 0, "Cross-chain timestamp should be recorded");
    }

    // ═══════════════════════════════════════════════════════
    //           CROSS-CHAIN: SECURITY
    // ═══════════════════════════════════════════════════════

    /// @notice Receiver rejects CCIP messages from unauthorized senders
    function test_RevertIf_Receiver_UnauthorizedSender() public {
        bytes memory payload = SettlementEncoder.encode(
            SettlementEncoder.SettlementInstruction({
                tradeId: tradeId,
                recipient: attacker,
                token: address(0),
                amount: 1 ether
            })
        );

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(address(receiver)),
            data: payload,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({gasLimit: 200_000, allowOutOfOrderExecution: true})
            ),
            feeToken: address(0)
        });

        uint256 fee = router.getFee(chainSelector, message);
        vm.deal(attacker, fee + 1 ether);

        // Attacker sends directly through CCIP router — receiver rejects (sender != allowedSender)
        vm.prank(attacker);
        vm.expectRevert();
        router.ccipSend{value: fee}(chainSelector, message);
    }

    /// @notice Can't settle the same trade twice — vault rejects second report (trade not BothDeposited)
    function test_RevertIf_DoubleSettlement_VaultRejects() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        // First cross-chain settlement succeeds
        _sendCrossChainReport(tradeId, alice, TRADE_AMOUNT);
        assertTrue(receiver.isTradeSettled(tradeId));

        // Second attempt fails: trade is now CrossChainPending, not BothDeposited
        bytes memory report2 = _buildCrossChainReport(tradeId, alice, TRADE_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.CrossChainPending,
                IOTCVault.TradeStatus.BothDeposited
            )
        );
        forwarder.deliverReport(address(vault), emptyMetadata, report2);
    }

    /// @notice Cross-chain report fails when receiver is not configured for destination chain
    function test_RevertIf_CrossChain_ReceiverNotConfigured() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        uint64 unknownSelector = 999;
        bytes memory settlementPayload = SettlementEncoder.encode(
            SettlementEncoder.SettlementInstruction({
                tradeId: tradeId,
                recipient: alice,
                token: address(0),
                amount: TRADE_AMOUNT
            })
        );
        bytes memory crossChainData = abi.encode(unknownSelector, settlementPayload);
        bytes memory report = abi.encode(tradeId, uint8(2), crossChainData);

        vm.expectRevert(abi.encodeWithSelector(IOTCVault.ReceiverNotConfigured.selector, unknownSelector));
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    // ═══════════════════════════════════════════════════════
    //           SAME-CHAIN COMPATIBILITY
    // ═══════════════════════════════════════════════════════

    /// @notice Same-chain settlement (action=0) still works with CCIP router configured
    function test_SameChain_SettlementStillWorks() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;

        _settleViaForwarder(tradeId);

        // DvP: Alice gets Bob's deposit, Bob gets Alice's deposit
        assertEq(alice.balance, aliceBalBefore + TRADE_AMOUNT, "Alice gets Bob's deposit");
        assertEq(bob.balance, bobBalBefore + TRADE_AMOUNT, "Bob gets Alice's deposit");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Settled));
    }

    /// @notice Refund (action=1) still works with CCIP router configured
    function test_SameChain_RefundStillWorks() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;

        _refundViaForwarder(tradeId, "compliance-failed");

        assertEq(alice.balance, aliceBalBefore + TRADE_AMOUNT, "Alice gets refund");
        assertEq(bob.balance, bobBalBefore + TRADE_AMOUNT, "Bob gets refund");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Refunded));
    }

    // ═══════════════════════════════════════════════════════
    //           TIMEOUT REFUND
    // ═══════════════════════════════════════════════════════

    /// @notice Timeout refund succeeds after CROSS_CHAIN_TIMEOUT (1 hour)
    function test_TimeoutRefund_Success() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        _sendCrossChainReport(tradeId, alice, TRADE_AMOUNT);
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.CrossChainPending));

        // Fast-forward past timeout
        vm.warp(block.timestamp + TacitConstants.CROSS_CHAIN_TIMEOUT + 1);

        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;

        vault.refundTimedOutCrossChain(tradeId);

        // Both parties get their original deposits back
        assertEq(alice.balance, aliceBalBefore + TRADE_AMOUNT, "Alice gets deposit back");
        assertEq(bob.balance, bobBalBefore + TRADE_AMOUNT, "Bob gets deposit back");
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Refunded));
    }

    /// @notice Timeout refund fails before timeout period
    function test_RevertIf_TimeoutRefund_TooEarly() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);
        _sendCrossChainReport(tradeId, alice, TRADE_AMOUNT);

        vm.expectRevert(abi.encodeWithSelector(IOTCVault.CrossChainNotTimedOut.selector, tradeId));
        vault.refundTimedOutCrossChain(tradeId);
    }

    /// @notice Timeout refund fails for non-CrossChainPending trades
    function test_RevertIf_TimeoutRefund_NotCrossChainPending() public {
        _createAndMatchETH(tradeId, TRADE_AMOUNT, TRADE_AMOUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.BothDeposited,
                IOTCVault.TradeStatus.CrossChainPending
            )
        );
        vault.refundTimedOutCrossChain(tradeId);
    }

    // ═══════════════════════════════════════════════════════
    //           FEE ESTIMATION
    // ═══════════════════════════════════════════════════════

    /// @notice estimateCCIPFee returns without reverting for configured chain
    function test_EstimateCCIPFee() public view {
        bytes memory payload = SettlementEncoder.encode(
            SettlementEncoder.SettlementInstruction({
                tradeId: tradeId,
                recipient: alice,
                token: address(0),
                amount: TRADE_AMOUNT
            })
        );

        uint256 fee = vault.estimateCCIPFee(chainSelector, payload);
        assertGe(fee, 0, "Fee should be non-negative");
    }

    /// @notice estimateCCIPFee reverts for unconfigured chain
    function test_RevertIf_EstimateFee_NotConfigured() public {
        uint64 unknownSelector = 999;
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.ReceiverNotConfigured.selector, unknownSelector));
        vault.estimateCCIPFee(unknownSelector, "");
    }

    // ═══════════════════════════════════════════════════════
    //           SETTLEMENT ENCODER
    // ═══════════════════════════════════════════════════════

    /// @notice SettlementEncoder encode/decode round-trip preserves data
    function test_SettlementEncoder_RoundTrip() public pure {
        SettlementEncoder.SettlementInstruction memory original = SettlementEncoder.SettlementInstruction({
            tradeId: bytes32(uint256(42)),
            recipient: address(0xBEEF),
            token: address(0),
            amount: 5 ether
        });

        bytes memory encoded = SettlementEncoder.encode(original);
        SettlementEncoder.SettlementInstruction memory decoded = SettlementEncoder.decode(encoded);

        assertEq(decoded.tradeId, original.tradeId);
        assertEq(decoded.recipient, original.recipient);
        assertEq(decoded.token, original.token);
        assertEq(decoded.amount, original.amount);
    }

    /// @notice Fuzz test: SettlementEncoder works with arbitrary inputs
    function testFuzz_SettlementEncoder(bytes32 tid, address recipient, address token, uint256 amount) public pure {
        vm.assume(recipient != address(0));

        SettlementEncoder.SettlementInstruction memory original =
            SettlementEncoder.SettlementInstruction({tradeId: tid, recipient: recipient, token: token, amount: amount});

        bytes memory encoded = SettlementEncoder.encode(original);
        SettlementEncoder.SettlementInstruction memory decoded = SettlementEncoder.decode(encoded);

        assertEq(decoded.tradeId, original.tradeId);
        assertEq(decoded.recipient, original.recipient);
        assertEq(decoded.token, original.token);
        assertEq(decoded.amount, original.amount);
    }

    // ═══════════════════════════════════════════════════════
    //           RECEIVER VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════

    /// @notice Default view function values before any settlement
    function test_ReceiverViewFunctions_Defaults() public view {
        assertFalse(receiver.isTradeSettled(tradeId), "Trade should not be settled by default");
        assertEq(
            uint256(receiver.getSettlementStatus(bytes32(0))),
            uint256(OTCVaultReceiver.SettlementStatus.None),
            "Settlement status should be None by default"
        );
    }

    /// @notice allowedSenders returns zero for unconfigured chain selectors
    function test_ReceiverAllowedSenders_Unconfigured() public view {
        assertEq(receiver.allowedSenders(999), address(0), "Unconfigured chain should have no allowed sender");
    }

    // ═══════════════════════════════════════════════════════
    //           RECEIVE ETH
    // ═══════════════════════════════════════════════════════

    receive() external payable {}
}
