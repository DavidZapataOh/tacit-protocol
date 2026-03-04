// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IOTCVault} from "./interfaces/IOTCVault.sol";
import {IReceiver} from "./interfaces/IReceiver.sol";
import {TacitConstants} from "./libraries/TacitConstants.sol";

/// @title OTCVault
/// @author Tacit Protocol
/// @notice Non-custodial escrow for private OTC trade settlement.
///         Accepts encrypted trade parameters and asset deposits from two counterparties.
///         Only the CRE workflow (running in a TEE) can trigger settlement or refund.
/// @dev Trade parameters are stored as opaque ciphertext encrypted with the Vault DON public key.
///      The contract never decrypts, parses, or validates the encrypted parameters.
///      Implements IReceiver for receiving settlement/refund reports via KeystoneForwarder.
contract OTCVault is IOTCVault, IReceiver, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    // ============ Internal Types for Report Decoding ============

    /// @notice Report action types from CRE workflow
    enum ReportAction {
        Settle, // 0: Execute DvP settlement
        Refund // 1: Refund both parties
    }

    // ============ State Variables ============

    /// @notice The KeystoneForwarder address authorized to deliver CRE reports
    address public immutable KEYSTONE_FORWARDER;

    /// @notice Mapping from trade ID to trade data
    mapping(bytes32 => Trade) private _trades;

    /// @notice Counter of total trades created
    uint256 private _tradeCount;

    // ============ Constructor ============

    /// @notice Initialize the OTCVault
    /// @param keystoneForwarder Address of the KeystoneForwarder contract
    /// @param initialOwner Address of the contract owner (for admin functions)
    constructor(address keystoneForwarder, address initialOwner) Ownable(initialOwner) {
        if (keystoneForwarder == address(0)) revert OnlyForwarder();
        KEYSTONE_FORWARDER = keystoneForwarder;
    }

    // ============ External Functions — Deposit ============

    /// @inheritdoc IOTCVault
    function createTradeETH(bytes32 tradeId, bytes calldata encryptedParams) external payable nonReentrant {
        // CHECKS
        if (_trades[tradeId].status != TradeStatus.None) revert TradeAlreadyExists(tradeId);
        if (msg.value == 0) revert ZeroAmount();
        if (encryptedParams.length == 0) revert EmptyEncryptedParams();

        // EFFECTS
        Trade storage trade = _trades[tradeId];
        trade.tradeId = tradeId;
        trade.status = TradeStatus.Created;
        trade.createdAt = block.timestamp;
        trade.expiresAt = block.timestamp + TacitConstants.DEFAULT_TRADE_EXPIRY;

        trade.partyA = Deposit({
            depositor: msg.sender, token: address(0), amount: msg.value, encryptedParams: encryptedParams, exists: true
        });

        unchecked {
            ++_tradeCount;
        }

        emit TradeCreated(tradeId, msg.sender, address(0), msg.value);

        // INTERACTIONS: none (ETH received via msg.value)
    }

    /// @inheritdoc IOTCVault
    function createTradeToken(bytes32 tradeId, address token, uint256 amount, bytes calldata encryptedParams)
        external
        nonReentrant
    {
        // CHECKS
        if (_trades[tradeId].status != TradeStatus.None) revert TradeAlreadyExists(tradeId);
        if (token == address(0)) revert ZeroDeposit();
        if (amount == 0) revert ZeroAmount();
        if (encryptedParams.length == 0) revert EmptyEncryptedParams();

        // EFFECTS
        Trade storage trade = _trades[tradeId];
        trade.tradeId = tradeId;
        trade.status = TradeStatus.Created;
        trade.createdAt = block.timestamp;
        trade.expiresAt = block.timestamp + TacitConstants.DEFAULT_TRADE_EXPIRY;

        trade.partyA = Deposit({
            depositor: msg.sender, token: token, amount: amount, encryptedParams: encryptedParams, exists: true
        });

        unchecked {
            ++_tradeCount;
        }

        emit TradeCreated(tradeId, msg.sender, token, amount);

        // INTERACTIONS
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IOTCVault
    function matchTradeETH(bytes32 tradeId, bytes calldata encryptedParams) external payable nonReentrant {
        Trade storage trade = _trades[tradeId];

        // CHECKS
        if (trade.status != TradeStatus.Created) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.Created);
        }
        if (block.timestamp > trade.expiresAt) revert TradeExpired(tradeId);
        if (msg.sender == trade.partyA.depositor) revert CannotMatchOwnTrade(tradeId);
        if (msg.value == 0) revert ZeroAmount();
        if (encryptedParams.length == 0) revert EmptyEncryptedParams();

        // EFFECTS
        trade.partyB = Deposit({
            depositor: msg.sender, token: address(0), amount: msg.value, encryptedParams: encryptedParams, exists: true
        });

        trade.status = TradeStatus.BothDeposited;

        emit TradeMatched(tradeId, msg.sender, address(0), msg.value);
        emit BothPartiesDeposited(tradeId);

        // INTERACTIONS: none (ETH received via msg.value)
    }

    /// @inheritdoc IOTCVault
    function matchTradeToken(bytes32 tradeId, address token, uint256 amount, bytes calldata encryptedParams)
        external
        nonReentrant
    {
        Trade storage trade = _trades[tradeId];

        // CHECKS
        if (trade.status != TradeStatus.Created) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.Created);
        }
        if (block.timestamp > trade.expiresAt) revert TradeExpired(tradeId);
        if (msg.sender == trade.partyA.depositor) revert CannotMatchOwnTrade(tradeId);
        if (token == address(0)) revert ZeroDeposit();
        if (amount == 0) revert ZeroAmount();
        if (encryptedParams.length == 0) revert EmptyEncryptedParams();

        // EFFECTS
        trade.partyB = Deposit({
            depositor: msg.sender, token: token, amount: amount, encryptedParams: encryptedParams, exists: true
        });

        trade.status = TradeStatus.BothDeposited;

        emit TradeMatched(tradeId, msg.sender, token, amount);
        emit BothPartiesDeposited(tradeId);

        // INTERACTIONS
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IOTCVault
    function claimExpiredRefund(bytes32 tradeId) external nonReentrant {
        Trade storage trade = _trades[tradeId];

        // CHECKS
        if (trade.status != TradeStatus.Created) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.Created);
        }
        if (block.timestamp <= trade.expiresAt) revert TradeNotExpired(tradeId);
        if (msg.sender != trade.partyA.depositor) revert OnlyForwarder();

        // EFFECTS
        trade.status = TradeStatus.Expired;
        uint256 refundAmount = trade.partyA.amount;
        address refundToken = trade.partyA.token;
        address refundTo = trade.partyA.depositor;

        emit TradeRefunded(tradeId, "expired");

        // INTERACTIONS
        if (refundToken == address(0)) {
            (bool success,) = refundTo.call{value: refundAmount}("");
            if (!success) revert ETHTransferFailed(refundTo, refundAmount);
        } else {
            IERC20(refundToken).safeTransfer(refundTo, refundAmount);
        }
    }

    // ============ External Functions — IReceiver ============

    /// @inheritdoc IReceiver
    /// @notice Process a settlement or refund report from the CRE workflow
    /// @dev Called by KeystoneForwarder after verifying DON signatures.
    ///      Decodes the report and executes atomic DvP settlement or mutual refund.
    ///      CEI pattern: all checks and state changes happen before any external calls.
    function onReport(bytes calldata metadata, bytes calldata report) external override nonReentrant {
        // CHECKS
        if (msg.sender != KEYSTONE_FORWARDER) revert OnlyForwarder();
        (metadata); // metadata contains workflow/DON IDs — not validated for hackathon scope

        // Decode the report
        (bytes32 tradeId, uint8 actionRaw, string memory reason) = abi.decode(report, (bytes32, uint8, string));

        Trade storage trade = _trades[tradeId];

        if (trade.status != TradeStatus.BothDeposited) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.BothDeposited);
        }

        if (actionRaw == uint8(ReportAction.Settle)) {
            _executeSettlement(trade, tradeId);
        } else if (actionRaw == uint8(ReportAction.Refund)) {
            _executeRefund(trade, tradeId, reason);
        } else {
            revert ZeroAmount(); // invalid action — reuse error to avoid adding new one for hackathon
        }
    }

    // ============ Admin Functions ============

    /// @notice Emergency function to rescue accidentally sent tokens (NOT trade deposits)
    /// @dev Only callable by owner. Does not track escrowed balances — use with care.
    /// @param token Token to rescue (address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to rescue
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ETHTransferFailed(address(0), amount);

        if (token == address(0)) {
            (bool success,) = to.call{value: amount}("");
            if (!success) revert ETHTransferFailed(to, amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    // ============ External Functions — View ============

    /// @inheritdoc IOTCVault
    function getTrade(bytes32 tradeId) external view returns (Trade memory trade) {
        trade = _trades[tradeId];
        if (trade.status == TradeStatus.None) revert TradeNotFound(tradeId);
    }

    /// @inheritdoc IOTCVault
    function getTradeStatus(bytes32 tradeId) external view returns (TradeStatus status) {
        status = _trades[tradeId].status;
    }

    /// @notice Get the total number of trades created
    /// @return count The total trade count
    function tradeCount() external view returns (uint256 count) {
        count = _tradeCount;
    }

    // ============ Internal Functions ============

    /// @notice Execute atomic DvP settlement: Party A's deposit -> Party B, Party B's deposit -> Party A
    /// @dev Follows CEI: state change first, then all transfers. If any transfer fails, entire tx reverts.
    /// @param trade Storage pointer to the trade
    /// @param tradeId The trade identifier (for events)
    function _executeSettlement(Trade storage trade, bytes32 tradeId) internal {
        // EFFECTS — state change before any external calls
        trade.status = TradeStatus.Settled;

        // Cache values to avoid multiple storage reads
        address partyADepositor = trade.partyA.depositor;
        address partyBDepositor = trade.partyB.depositor;
        address tokenA = trade.partyA.token;
        address tokenB = trade.partyB.token;
        uint256 amountA = trade.partyA.amount;
        uint256 amountB = trade.partyB.amount;

        emit TradeSettled(tradeId);

        // INTERACTIONS — DvP: Party A's assets -> Party B, Party B's assets -> Party A

        // Transfer Party A's deposit to Party B
        if (tokenA == address(0)) {
            (bool successA,) = partyBDepositor.call{value: amountA}("");
            if (!successA) revert ETHTransferFailed(partyBDepositor, amountA);
        } else {
            IERC20(tokenA).safeTransfer(partyBDepositor, amountA);
        }

        // Transfer Party B's deposit to Party A
        if (tokenB == address(0)) {
            (bool successB,) = partyADepositor.call{value: amountB}("");
            if (!successB) revert ETHTransferFailed(partyADepositor, amountB);
        } else {
            IERC20(tokenB).safeTransfer(partyADepositor, amountB);
        }
    }

    /// @notice Execute mutual refund: return each party's deposit to their originating address
    /// @dev Follows CEI: state change first, then transfers.
    /// @param trade Storage pointer to the trade
    /// @param tradeId The trade identifier (for events)
    /// @param reason The reason for refund (compliance failure, parameter mismatch, etc.)
    function _executeRefund(Trade storage trade, bytes32 tradeId, string memory reason) internal {
        // EFFECTS — state change before any external calls
        trade.status = TradeStatus.Refunded;

        // Cache values
        address partyADepositor = trade.partyA.depositor;
        address partyBDepositor = trade.partyB.depositor;
        address tokenA = trade.partyA.token;
        address tokenB = trade.partyB.token;
        uint256 amountA = trade.partyA.amount;
        uint256 amountB = trade.partyB.amount;

        emit TradeRefunded(tradeId, reason);

        // INTERACTIONS — return each party's deposit

        // Refund Party A
        if (tokenA == address(0)) {
            (bool successA,) = partyADepositor.call{value: amountA}("");
            if (!successA) revert ETHTransferFailed(partyADepositor, amountA);
        } else {
            IERC20(tokenA).safeTransfer(partyADepositor, amountA);
        }

        // Refund Party B
        if (tokenB == address(0)) {
            (bool successB,) = partyBDepositor.call{value: amountB}("");
            if (!successB) revert ETHTransferFailed(partyBDepositor, amountB);
        } else {
            IERC20(tokenB).safeTransfer(partyBDepositor, amountB);
        }
    }

    // ============ Receive ============

    /// @notice Allow contract to receive ETH (for CCIP fee payments, etc.)
    receive() external payable {}
}
