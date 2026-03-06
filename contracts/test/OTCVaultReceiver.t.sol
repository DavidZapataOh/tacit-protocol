// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {OTCVaultReceiver} from "../src/OTCVaultReceiver.sol";
import {SettlementEncoder} from "../src/libraries/SettlementEncoder.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

/// @title OTCVaultReceiverTest
/// @notice Unit tests for OTCVaultReceiver CCIP receiver contract
contract OTCVaultReceiverTest is Test {
    OTCVaultReceiver public receiver;
    address public owner = makeAddr("owner");
    address public router = makeAddr("router");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint64 public constant SEPOLIA_SELECTOR = 16_015_286_601_757_825_753;
    address public constant SOURCE_VAULT = address(0x1234);
    bytes32 public constant TRADE_ID = keccak256("test-trade-1");
    bytes32 public constant MESSAGE_ID = keccak256("ccip-message-1");

    function setUp() public {
        vm.prank(owner);
        receiver = new OTCVaultReceiver(router);
    }

    // ═══════════════════════════════════════════════════════════════
    //                      CONSTRUCTOR TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_Constructor_SetsOwner() public view {
        assertEq(receiver.owner(), owner);
    }

    function test_Constructor_SetsRouter() public view {
        assertEq(receiver.getRouter(), router);
    }

    function test_Constructor_RevertsIfZeroRouter() public {
        vm.expectRevert();
        new OTCVaultReceiver(address(0));
    }

    // ═══════════════════════════════════════════════════════════════
    //                    SET ALLOWED SENDER TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_SetAllowedSender() public {
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
        assertEq(receiver.allowedSenders(SEPOLIA_SELECTOR), SOURCE_VAULT);
    }

    function test_SetAllowedSender_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit OTCVaultReceiver.AllowedSenderSet(SEPOLIA_SELECTOR, SOURCE_VAULT);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
    }

    function test_RevertIf_NonOwnerSetsAllowedSender() public {
        vm.prank(alice);
        vm.expectRevert();
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
    }

    function test_RevertIf_SetAllowedSenderZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(OTCVaultReceiver.ZeroAddress.selector));
        receiver.setAllowedSender(SEPOLIA_SELECTOR, address(0));
    }

    // ═══════════════════════════════════════════════════════════════
    //                    CCIP RECEIVE TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_CcipReceive_ETHSettlement() public {
        // Setup: allow sender and fund receiver
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
        vm.deal(address(receiver), 10 ether);

        // Build CCIP message
        Client.Any2EVMMessage memory message = _buildCCIPMessage(
            TRADE_ID, alice, address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        // Call ccipReceive as router
        vm.prank(router);
        receiver.ccipReceive(message);

        // Verify state
        assertTrue(receiver.tradeSettled(TRADE_ID));
        assertEq(uint8(receiver.settlementStatus(MESSAGE_ID)), uint8(OTCVaultReceiver.SettlementStatus.Executed));
        assertEq(receiver.messageToTrade(MESSAGE_ID), TRADE_ID);
        assertEq(alice.balance, 1 ether);
    }

    function test_CcipReceive_EmitsEvent() public {
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
        vm.deal(address(receiver), 10 ether);

        Client.Any2EVMMessage memory message = _buildCCIPMessage(
            TRADE_ID, alice, address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        vm.expectEmit(true, true, true, true);
        emit OTCVaultReceiver.CrossChainSettlementReceived(TRADE_ID, MESSAGE_ID);

        vm.prank(router);
        receiver.ccipReceive(message);
    }

    function test_RevertIf_SourceChainNotAllowed() public {
        // Don't configure any sender
        Client.Any2EVMMessage memory message =
            _buildCCIPMessage(TRADE_ID, alice, address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT);

        vm.prank(router);
        vm.expectRevert(abi.encodeWithSelector(OTCVaultReceiver.SourceChainNotAllowed.selector, SEPOLIA_SELECTOR));
        receiver.ccipReceive(message);
    }

    function test_RevertIf_UnauthorizedSender() public {
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);

        address wrongSender = makeAddr("wrongSender");
        Client.Any2EVMMessage memory message =
            _buildCCIPMessage(TRADE_ID, alice, address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, wrongSender);

        vm.prank(router);
        vm.expectRevert(
            abi.encodeWithSelector(OTCVaultReceiver.UnauthorizedSender.selector, SEPOLIA_SELECTOR, wrongSender)
        );
        receiver.ccipReceive(message);
    }

    function test_RevertIf_TradeAlreadySettled() public {
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
        vm.deal(address(receiver), 10 ether);

        Client.Any2EVMMessage memory message = _buildCCIPMessage(
            TRADE_ID, alice, address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        // First settlement succeeds
        vm.prank(router);
        receiver.ccipReceive(message);

        // Second attempt with different messageId but same tradeId
        bytes32 messageId2 = keccak256("ccip-message-2");
        Client.Any2EVMMessage memory message2 = _buildCCIPMessage(
            TRADE_ID, alice, address(0), 1 ether, messageId2, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        vm.prank(router);
        vm.expectRevert(abi.encodeWithSelector(OTCVaultReceiver.TradeAlreadySettled.selector, TRADE_ID));
        receiver.ccipReceive(message2);
    }

    function test_RevertIf_InsufficientETHBalance() public {
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
        // Fund with less than required
        vm.deal(address(receiver), 0.5 ether);

        Client.Any2EVMMessage memory message = _buildCCIPMessage(
            TRADE_ID, alice, address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        vm.prank(router);
        vm.expectRevert(abi.encodeWithSelector(OTCVaultReceiver.InsufficientBalance.selector, 0.5 ether, 1 ether));
        receiver.ccipReceive(message);
    }

    function test_RevertIf_ZeroRecipient() public {
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);
        vm.deal(address(receiver), 10 ether);

        Client.Any2EVMMessage memory message = _buildCCIPMessage(
            TRADE_ID, address(0), address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        vm.prank(router);
        vm.expectRevert(abi.encodeWithSelector(OTCVaultReceiver.ZeroAddress.selector));
        receiver.ccipReceive(message);
    }

    function test_RevertIf_ZeroAmount() public {
        vm.prank(owner);
        receiver.setAllowedSender(SEPOLIA_SELECTOR, SOURCE_VAULT);

        Client.Any2EVMMessage memory message = _buildCCIPMessage(
            TRADE_ID, alice, address(0), 0, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        vm.prank(router);
        vm.expectRevert(abi.encodeWithSelector(OTCVaultReceiver.ZeroAmount.selector));
        receiver.ccipReceive(message);
    }

    function test_RevertIf_NotRouter() public {
        Client.Any2EVMMessage memory message = _buildCCIPMessage(
            TRADE_ID, alice, address(0), 1 ether, MESSAGE_ID, SEPOLIA_SELECTOR, SOURCE_VAULT
        );

        vm.prank(alice);
        vm.expectRevert();
        receiver.ccipReceive(message);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    VIEW FUNCTION TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_IsTradeSettled_DefaultFalse() public view {
        assertFalse(receiver.isTradeSettled(TRADE_ID));
    }

    function test_GetSettlementStatus_DefaultNone() public view {
        assertEq(uint8(receiver.getSettlementStatus(MESSAGE_ID)), uint8(OTCVaultReceiver.SettlementStatus.None));
    }

    // ═══════════════════════════════════════════════════════════════
    //                    RECEIVE ETH TEST
    // ═══════════════════════════════════════════════════════════════

    function test_ReceiveETH() public {
        vm.deal(address(receiver), 10 ether);
        assertEq(address(receiver).balance, 10 ether);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    WITHDRAW TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_WithdrawETH() public {
        vm.deal(address(receiver), 5 ether);

        vm.prank(owner);
        receiver.withdrawETH(payable(alice), 2 ether);
        assertEq(alice.balance, 2 ether);
        assertEq(address(receiver).balance, 3 ether);
    }

    function test_RevertIf_NonOwnerWithdrawsETH() public {
        vm.deal(address(receiver), 5 ether);

        vm.prank(alice);
        vm.expectRevert();
        receiver.withdrawETH(payable(alice), 2 ether);
    }

    function test_RevertIf_WithdrawETHToZeroAddress() public {
        vm.deal(address(receiver), 5 ether);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(OTCVaultReceiver.ZeroAddress.selector));
        receiver.withdrawETH(payable(address(0)), 2 ether);
    }

    // ═══════════════════════════════════════════════════════════════
    //                    SETTLEMENT ENCODER TESTS
    // ═══════════════════════════════════════════════════════════════

    function test_SettlementEncoder_RoundTrip() public pure {
        SettlementEncoder.SettlementInstruction memory original = SettlementEncoder.SettlementInstruction({
            tradeId: keccak256("trade-1"),
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

    // ═══════════════════════════════════════════════════════════════
    //                    HELPERS
    // ═══════════════════════════════════════════════════════════════

    function _buildCCIPMessage(
        bytes32 tradeId,
        address recipient,
        address token,
        uint256 amount,
        bytes32 messageId,
        uint64 sourceChainSelector,
        address sender
    ) internal pure returns (Client.Any2EVMMessage memory) {
        bytes memory data = SettlementEncoder.encode(
            SettlementEncoder.SettlementInstruction({
                tradeId: tradeId,
                recipient: recipient,
                token: token,
                amount: amount
            })
        );

        return Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: sourceChainSelector,
            sender: abi.encode(sender),
            data: data,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
    }
}
