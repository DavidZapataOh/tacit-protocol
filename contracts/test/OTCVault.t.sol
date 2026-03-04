// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {OTCVault} from "../src/OTCVault.sol";
import {IOTCVault} from "../src/interfaces/IOTCVault.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockKeystoneForwarder} from "./mocks/MockKeystoneForwarder.sol";

contract OTCVaultTest is Test {
    OTCVault public vault;
    MockERC20 public usdc;
    MockERC20 public weth;
    MockKeystoneForwarder public forwarder;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice"); // Party A
    address public bob = makeAddr("bob"); // Party B
    address public charlie = makeAddr("charlie"); // Third party (unauthorized)

    bytes32 public tradeId = keccak256("trade-001");
    bytes public aliceEncryptedParams = hex"deadbeef0001";
    bytes public bobEncryptedParams = hex"deadbeef0002";
    bytes public emptyMetadata = "";

    function setUp() public {
        // Deploy mock contracts
        forwarder = new MockKeystoneForwarder();
        vault = new OTCVault(address(forwarder), owner, address(0));

        // Deploy mock tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped ETH", "WETH", 18);

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        // Mint tokens to test accounts
        usdc.mint(alice, 1_000_000e6);
        usdc.mint(bob, 1_000_000e6);
        weth.mint(alice, 100e18);
        weth.mint(bob, 100e18);

        // Approve vault for token transfers
        vm.prank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(vault), type(uint256).max);
        vm.prank(alice);
        weth.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        weth.approve(address(vault), type(uint256).max);
    }

    // ============ Helpers ============

    /// @dev Helper to create ETH trade as alice and match as bob
    function _createAndMatchETH(bytes32 tid, uint256 amountA, uint256 amountB) internal {
        vm.prank(alice);
        vault.createTradeETH{value: amountA}(tid, aliceEncryptedParams);
        vm.prank(bob);
        vault.matchTradeETH{value: amountB}(tid, bobEncryptedParams);
    }

    /// @dev Helper to send settlement report
    function _settleViaForwarder(bytes32 tid) internal {
        bytes memory report = abi.encode(tid, uint8(0), "");
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    /// @dev Helper to send refund report
    function _refundViaForwarder(bytes32 tid, string memory reason) internal {
        bytes memory report = abi.encode(tid, uint8(1), reason);
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    // ============ Constructor ============

    function test_Constructor_Deployed() public view {
        assertEq(vault.KEYSTONE_FORWARDER(), address(forwarder));
        assertEq(vault.owner(), owner);
        assertEq(vault.tradeCount(), 0);
    }

    function test_RevertIf_Constructor_ZeroForwarder() public {
        vm.expectRevert(IOTCVault.OnlyForwarder.selector);
        new OTCVault(address(0), owner, address(0));
    }

    // ============ createTradeETH ============

    function test_CreateTradeETH_Success() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(trade.partyA.depositor, alice);
        assertEq(trade.partyA.token, address(0));
        assertEq(trade.partyA.amount, 10 ether);
        assertEq(trade.partyA.exists, true);
        assertEq(uint8(trade.status), uint8(IOTCVault.TradeStatus.Created));
        assertEq(vault.tradeCount(), 1);
        assertGt(trade.expiresAt, block.timestamp);
    }

    function test_CreateTradeETH_EmitsTradeCreated() public {
        vm.expectEmit(true, true, true, true);
        emit IOTCVault.TradeCreated(tradeId, alice, address(0), 10 ether);

        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);
    }

    function test_RevertIf_CreateTradeETH_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        vault.createTradeETH{value: 0}(tradeId, aliceEncryptedParams);
    }

    function test_RevertIf_CreateTradeETH_EmptyParams() public {
        vm.prank(alice);
        vm.expectRevert(IOTCVault.EmptyEncryptedParams.selector);
        vault.createTradeETH{value: 1 ether}(tradeId, "");
    }

    function test_RevertIf_CreateTradeETH_DuplicateTradeId() public {
        vm.prank(alice);
        vault.createTradeETH{value: 1 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeAlreadyExists.selector, tradeId));
        vault.createTradeETH{value: 1 ether}(tradeId, bobEncryptedParams);
    }

    // ============ createTradeToken ============

    function test_CreateTradeToken_Success() public {
        vm.prank(alice);
        vault.createTradeToken(tradeId, address(usdc), 25_000e6, aliceEncryptedParams);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(trade.partyA.depositor, alice);
        assertEq(trade.partyA.token, address(usdc));
        assertEq(trade.partyA.amount, 25_000e6);
        assertEq(trade.partyA.exists, true);
        assertEq(usdc.balanceOf(address(vault)), 25_000e6);
        assertEq(uint8(trade.status), uint8(IOTCVault.TradeStatus.Created));
    }

    function test_CreateTradeToken_EmitsTradeCreated() public {
        vm.expectEmit(true, true, true, true);
        emit IOTCVault.TradeCreated(tradeId, alice, address(usdc), 25_000e6);

        vm.prank(alice);
        vault.createTradeToken(tradeId, address(usdc), 25_000e6, aliceEncryptedParams);
    }

    function test_RevertIf_CreateTradeToken_ZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        vault.createTradeToken(tradeId, address(usdc), 0, aliceEncryptedParams);
    }

    function test_RevertIf_CreateTradeToken_ZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(IOTCVault.ZeroDeposit.selector);
        vault.createTradeToken(tradeId, address(0), 1000e6, aliceEncryptedParams);
    }

    function test_RevertIf_CreateTradeToken_EmptyParams() public {
        vm.prank(alice);
        vm.expectRevert(IOTCVault.EmptyEncryptedParams.selector);
        vault.createTradeToken(tradeId, address(usdc), 1000e6, "");
    }

    function test_RevertIf_CreateTradeToken_DuplicateTradeId() public {
        vm.prank(alice);
        vault.createTradeToken(tradeId, address(usdc), 1000e6, aliceEncryptedParams);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeAlreadyExists.selector, tradeId));
        vault.createTradeToken(tradeId, address(usdc), 1000e6, bobEncryptedParams);
    }

    // ============ matchTradeETH ============

    function test_MatchTradeETH_Success() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vault.matchTradeETH{value: 5 ether}(tradeId, bobEncryptedParams);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(trade.partyB.depositor, bob);
        assertEq(trade.partyB.token, address(0));
        assertEq(trade.partyB.amount, 5 ether);
        assertEq(trade.partyB.exists, true);
        assertEq(uint8(trade.status), uint8(IOTCVault.TradeStatus.BothDeposited));
    }

    function test_MatchTradeETH_EmitsBothEvents() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.expectEmit(true, true, true, true);
        emit IOTCVault.TradeMatched(tradeId, bob, address(0), 5 ether);
        vm.expectEmit(true, true, true, true);
        emit IOTCVault.BothPartiesDeposited(tradeId);

        vm.prank(bob);
        vault.matchTradeETH{value: 5 ether}(tradeId, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeETH_SelfMatch() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.CannotMatchOwnTrade.selector, tradeId));
        vault.matchTradeETH{value: 5 ether}(tradeId, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeETH_NonexistentTrade() public {
        bytes32 fakeTrade = keccak256("fake");
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                fakeTrade,
                IOTCVault.TradeStatus.None,
                IOTCVault.TradeStatus.Created
            )
        );
        vault.matchTradeETH{value: 5 ether}(fakeTrade, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeETH_Expired() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        // Fast forward past expiry (24 hours + 1 second)
        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeExpired.selector, tradeId));
        vault.matchTradeETH{value: 5 ether}(tradeId, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeETH_ZeroAmount() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        vault.matchTradeETH{value: 0}(tradeId, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeETH_EmptyParams() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vm.expectRevert(IOTCVault.EmptyEncryptedParams.selector);
        vault.matchTradeETH{value: 5 ether}(tradeId, "");
    }

    function test_RevertIf_MatchTradeETH_AlreadyMatched() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        vm.prank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.BothDeposited,
                IOTCVault.TradeStatus.Created
            )
        );
        vault.matchTradeETH{value: 5 ether}(tradeId, hex"aabbcc");
    }

    // ============ matchTradeToken ============

    function test_MatchTradeToken_Success() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, bobEncryptedParams);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(trade.partyB.token, address(usdc));
        assertEq(trade.partyB.amount, 25_000e6);
        assertEq(trade.partyB.exists, true);
        assertEq(uint8(trade.status), uint8(IOTCVault.TradeStatus.BothDeposited));
        assertEq(usdc.balanceOf(address(vault)), 25_000e6);
    }

    function test_MatchTradeToken_EmitsBothEvents() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.expectEmit(true, true, true, true);
        emit IOTCVault.TradeMatched(tradeId, bob, address(usdc), 25_000e6);
        vm.expectEmit(true, true, true, true);
        emit IOTCVault.BothPartiesDeposited(tradeId);

        vm.prank(bob);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeToken_ZeroAddress() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vm.expectRevert(IOTCVault.ZeroDeposit.selector);
        vault.matchTradeToken(tradeId, address(0), 1000e6, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeToken_ZeroAmount() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        vault.matchTradeToken(tradeId, address(usdc), 0, bobEncryptedParams);
    }

    function test_RevertIf_MatchTradeToken_EmptyParams() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(bob);
        vm.expectRevert(IOTCVault.EmptyEncryptedParams.selector);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, "");
    }

    function test_RevertIf_MatchTradeToken_SelfMatch() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.CannotMatchOwnTrade.selector, tradeId));
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, bobEncryptedParams);
    }

    // ============ onReport — Settlement ============

    function test_OnReport_Settlement_ETH_ETH() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;

        _settleViaForwarder(tradeId);

        // DvP: Alice gets Bob's deposit, Bob gets Alice's deposit
        assertEq(alice.balance, aliceBalBefore + 5 ether);
        assertEq(bob.balance, bobBalBefore + 10 ether);
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Settled));
        assertEq(address(vault).balance, 0);
    }

    function test_OnReport_Settlement_Token_Token() public {
        vm.prank(alice);
        vault.createTradeToken(tradeId, address(weth), 10e18, aliceEncryptedParams);
        vm.prank(bob);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, bobEncryptedParams);

        _settleViaForwarder(tradeId);

        // DvP: Alice gets USDC, Bob gets WETH
        assertEq(usdc.balanceOf(alice), 1_000_000e6 + 25_000e6);
        assertEq(weth.balanceOf(bob), 100e18 + 10e18);
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Settled));
    }

    function test_OnReport_Settlement_ETH_Token() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);
        vm.prank(bob);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, bobEncryptedParams);

        uint256 aliceUsdcBefore = usdc.balanceOf(alice);
        uint256 bobEthBefore = bob.balance;

        _settleViaForwarder(tradeId);

        // DvP: Alice gets USDC, Bob gets ETH
        assertEq(usdc.balanceOf(alice), aliceUsdcBefore + 25_000e6);
        assertEq(bob.balance, bobEthBefore + 10 ether);
    }

    function test_OnReport_Settlement_Token_ETH() public {
        vm.prank(alice);
        vault.createTradeToken(tradeId, address(usdc), 25_000e6, aliceEncryptedParams);
        vm.prank(bob);
        vault.matchTradeETH{value: 10 ether}(tradeId, bobEncryptedParams);

        uint256 aliceEthBefore = alice.balance;
        uint256 bobUsdcBefore = usdc.balanceOf(bob);

        _settleViaForwarder(tradeId);

        // DvP: Alice gets ETH, Bob gets USDC
        assertEq(alice.balance, aliceEthBefore + 10 ether);
        assertEq(usdc.balanceOf(bob), bobUsdcBefore + 25_000e6);
    }

    function test_OnReport_Settlement_EmitsTradeSettled() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        vm.expectEmit(true, true, true, true);
        emit IOTCVault.TradeSettled(tradeId);

        _settleViaForwarder(tradeId);
    }

    // ============ onReport — Refund ============

    function test_OnReport_Refund_ETH_ETH() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        uint256 aliceBalBefore = alice.balance;
        uint256 bobBalBefore = bob.balance;

        _refundViaForwarder(tradeId, "compliance_failed");

        // Each gets their own deposit back
        assertEq(alice.balance, aliceBalBefore + 10 ether);
        assertEq(bob.balance, bobBalBefore + 5 ether);
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Refunded));
        assertEq(address(vault).balance, 0);
    }

    function test_OnReport_Refund_Token_Token() public {
        vm.prank(alice);
        vault.createTradeToken(tradeId, address(weth), 10e18, aliceEncryptedParams);
        vm.prank(bob);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, bobEncryptedParams);

        _refundViaForwarder(tradeId, "sanctions_hit");

        // Each gets their own tokens back
        assertEq(weth.balanceOf(alice), 100e18);
        assertEq(usdc.balanceOf(bob), 1_000_000e6);
    }

    function test_OnReport_Refund_ETH_Token() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);
        vm.prank(bob);
        vault.matchTradeToken(tradeId, address(usdc), 25_000e6, bobEncryptedParams);

        uint256 aliceEthBefore = alice.balance;
        uint256 bobUsdcBefore = usdc.balanceOf(bob);

        _refundViaForwarder(tradeId, "parameter_mismatch");

        assertEq(alice.balance, aliceEthBefore + 10 ether);
        assertEq(usdc.balanceOf(bob), bobUsdcBefore + 25_000e6);
    }

    function test_OnReport_Refund_EmitsTradeRefunded() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        vm.expectEmit(true, true, true, true);
        emit IOTCVault.TradeRefunded(tradeId, "parameter_mismatch");

        _refundViaForwarder(tradeId, "parameter_mismatch");
    }

    // ============ onReport — Access Control ============

    function test_RevertIf_OnReport_NotForwarder() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        bytes memory report = abi.encode(tradeId, uint8(0), "");

        vm.prank(charlie);
        vm.expectRevert(IOTCVault.OnlyForwarder.selector);
        vault.onReport(emptyMetadata, report);
    }

    function test_RevertIf_OnReport_DoubleSettlement() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

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
    }

    function test_RevertIf_OnReport_TradeNotBothDeposited() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        // Try to settle before Party B deposits
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

    function test_RevertIf_OnReport_InvalidAction() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        // Action 3 is invalid (only 0=Settle, 1=Refund, 2=CrossChainSettle exist)
        bytes memory report = abi.encode(tradeId, uint8(3), "");
        vm.expectRevert(IOTCVault.ZeroAmount.selector);
        forwarder.deliverReport(address(vault), emptyMetadata, report);
    }

    function test_RevertIf_OnReport_RefundAfterSettlement() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        _settleViaForwarder(tradeId);

        // Can't refund a settled trade
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
    }

    // ============ claimExpiredRefund ============

    function test_ClaimExpiredRefund_ETH() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        uint256 aliceBalBefore = alice.balance;

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(alice);
        vault.claimExpiredRefund(tradeId);

        assertEq(alice.balance, aliceBalBefore + 10 ether);
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Expired));
    }

    function test_ClaimExpiredRefund_Token() public {
        vm.prank(alice);
        vault.createTradeToken(tradeId, address(usdc), 25_000e6, aliceEncryptedParams);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(alice);
        vault.claimExpiredRefund(tradeId);

        assertEq(usdc.balanceOf(alice), 1_000_000e6); // Full balance restored
        assertEq(uint8(vault.getTradeStatus(tradeId)), uint8(IOTCVault.TradeStatus.Expired));
    }

    function test_ClaimExpiredRefund_EmitsTradeRefunded() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.expectEmit(true, true, true, true);
        emit IOTCVault.TradeRefunded(tradeId, "expired");

        vm.prank(alice);
        vault.claimExpiredRefund(tradeId);
    }

    function test_RevertIf_ClaimExpiredRefund_NotExpired() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeNotExpired.selector, tradeId));
        vault.claimExpiredRefund(tradeId);
    }

    function test_RevertIf_ClaimExpiredRefund_NotPartyA() public {
        vm.prank(alice);
        vault.createTradeETH{value: 10 ether}(tradeId, aliceEncryptedParams);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(bob);
        vm.expectRevert(IOTCVault.OnlyForwarder.selector); // reuses OnlyForwarder error
        vault.claimExpiredRefund(tradeId);
    }

    function test_RevertIf_ClaimExpiredRefund_AlreadyMatched() public {
        _createAndMatchETH(tradeId, 10 ether, 5 ether);

        vm.warp(block.timestamp + 24 hours + 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IOTCVault.InvalidTradeStatus.selector,
                tradeId,
                IOTCVault.TradeStatus.BothDeposited,
                IOTCVault.TradeStatus.Created
            )
        );
        vault.claimExpiredRefund(tradeId);
    }

    // ============ rescueTokens ============

    function test_RescueTokens_ETH() public {
        // Send ETH directly to vault (not via trade)
        vm.deal(address(vault), 1 ether);

        uint256 ownerBalBefore = owner.balance;

        vm.prank(owner);
        vault.rescueTokens(address(0), owner, 1 ether);

        assertEq(owner.balance, ownerBalBefore + 1 ether);
    }

    function test_RescueTokens_Token() public {
        // Send tokens directly to vault (not via trade)
        usdc.mint(address(vault), 1000e6);

        vm.prank(owner);
        vault.rescueTokens(address(usdc), owner, 1000e6);

        assertEq(usdc.balanceOf(owner), 1000e6);
    }

    function test_RevertIf_RescueTokens_NotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        vault.rescueTokens(address(usdc), alice, 1000e6);
    }

    function test_RevertIf_RescueTokens_ZeroRecipient() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.ETHTransferFailed.selector, address(0), 1000e6));
        vault.rescueTokens(address(usdc), address(0), 1000e6);
    }

    // ============ View Functions ============

    function test_GetTradeStatus_None() public view {
        assertEq(uint8(vault.getTradeStatus(keccak256("nonexistent"))), uint8(IOTCVault.TradeStatus.None));
    }

    function test_RevertIf_GetTrade_NonExistent() public {
        bytes32 fake = keccak256("fake");
        vm.expectRevert(abi.encodeWithSelector(IOTCVault.TradeNotFound.selector, fake));
        vault.getTrade(fake);
    }

    function test_TradeCount_IncrementsByOne() public {
        assertEq(vault.tradeCount(), 0);

        vm.prank(alice);
        vault.createTradeETH{value: 1 ether}(keccak256("t1"), aliceEncryptedParams);
        assertEq(vault.tradeCount(), 1);

        vm.prank(alice);
        vault.createTradeETH{value: 1 ether}(keccak256("t2"), aliceEncryptedParams);
        assertEq(vault.tradeCount(), 2);
    }

    // ============ Fuzz Tests ============

    function testFuzz_CreateTradeETH_AnyAmount(uint256 amount) public {
        amount = bound(amount, 1, 100 ether);

        vm.prank(alice);
        vault.createTradeETH{value: amount}(tradeId, aliceEncryptedParams);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(trade.partyA.amount, amount);
    }

    function testFuzz_CreateTradeToken_AnyAmount(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000e6);

        vm.prank(alice);
        vault.createTradeToken(tradeId, address(usdc), amount, aliceEncryptedParams);

        IOTCVault.Trade memory trade = vault.getTrade(tradeId);
        assertEq(trade.partyA.amount, amount);
    }

    function testFuzz_SettlementPreservesTotalValue_ETH(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1, 50 ether);
        amountB = bound(amountB, 1, 50 ether);

        _createAndMatchETH(tradeId, amountA, amountB);

        uint256 totalBefore = alice.balance + bob.balance + address(vault).balance;

        _settleViaForwarder(tradeId);

        uint256 totalAfter = alice.balance + bob.balance + address(vault).balance;
        assertEq(totalBefore, totalAfter, "Total value must be preserved after settlement");
    }

    function testFuzz_RefundPreservesTotalValue_ETH(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1, 50 ether);
        amountB = bound(amountB, 1, 50 ether);

        _createAndMatchETH(tradeId, amountA, amountB);

        uint256 totalBefore = alice.balance + bob.balance + address(vault).balance;

        _refundViaForwarder(tradeId, "fuzz_test");

        uint256 totalAfter = alice.balance + bob.balance + address(vault).balance;
        assertEq(totalBefore, totalAfter, "Total value must be preserved after refund");
    }

    function testFuzz_CreateTradeETH_AnyTradeId(bytes32 tid) public {
        vm.prank(alice);
        vault.createTradeETH{value: 1 ether}(tid, aliceEncryptedParams);
        assertEq(uint8(vault.getTradeStatus(tid)), uint8(IOTCVault.TradeStatus.Created));
    }

    // ============ Receive ETH ============

    receive() external payable {}
}
