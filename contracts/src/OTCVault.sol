// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IOTCVault} from "./interfaces/IOTCVault.sol";
import {IReceiver} from "./interfaces/IReceiver.sol";
import {TacitConstants} from "./libraries/TacitConstants.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";

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
        Settle, // 0: Execute same-chain DvP settlement
        Refund, // 1: Refund both parties
        CrossChainSettle // 2: Execute cross-chain DvP via CCIP
    }

    // ============ State Variables ============

    /// @notice The KeystoneForwarder address authorized to deliver CRE reports
    address public immutable KEYSTONE_FORWARDER;

    /// @notice The CCIP Router contract for cross-chain messaging
    IRouterClient public immutable CCIP_ROUTER;

    /// @notice Mapping from trade ID to trade data
    mapping(bytes32 => Trade) private _trades;

    /// @notice Counter of total trades created
    uint256 private _tradeCount;

    /// @notice Total escrowed ETH across all active trades (prevents rescueTokens from draining deposits)
    uint256 private _totalEscrowedETH;

    /// @notice Total escrowed amount per ERC-20 token (prevents rescueTokens from draining deposits)
    mapping(address => uint256) private _totalEscrowedToken;

    /// @notice Allowed CCIP receiver contracts per destination chain
    mapping(uint64 => address) public allowedReceivers;

    /// @notice Mapping from CCIP message ID to trade ID for tracking
    mapping(bytes32 => bytes32) public ccipMessageToTrade;

    /// @notice Timestamp when a cross-chain settlement was initiated (for timeout)
    mapping(bytes32 => uint256) public crossChainInitiatedAt;

    // ============ Constructor ============

    /// @notice Initialize the OTCVault
    /// @param keystoneForwarder Address of the KeystoneForwarder contract
    /// @param initialOwner Address of the contract owner (for admin functions)
    /// @param ccipRouter Address of the CCIP Router contract (address(0) if no cross-chain)
    constructor(address keystoneForwarder, address initialOwner, address ccipRouter) Ownable(initialOwner) {
        if (keystoneForwarder == address(0)) revert OnlyForwarder();
        KEYSTONE_FORWARDER = keystoneForwarder;
        CCIP_ROUTER = IRouterClient(ccipRouter);
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
        trade.createdAt = uint48(block.timestamp);
        trade.expiresAt = uint48(block.timestamp + TacitConstants.DEFAULT_TRADE_EXPIRY);

        trade.partyA = Deposit({
            depositor: msg.sender, exists: true, token: address(0), amount: msg.value, encryptedParams: encryptedParams
        });

        _totalEscrowedETH += msg.value;

        unchecked {
            ++_tradeCount;
        }

        emit TradeCreated(tradeId);

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
        trade.createdAt = uint48(block.timestamp);
        trade.expiresAt = uint48(block.timestamp + TacitConstants.DEFAULT_TRADE_EXPIRY);

        trade.partyA = Deposit({
            depositor: msg.sender, exists: true, token: token, amount: amount, encryptedParams: encryptedParams
        });

        _totalEscrowedToken[token] += amount;

        unchecked {
            ++_tradeCount;
        }

        emit TradeCreated(tradeId);

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
            depositor: msg.sender, exists: true, token: address(0), amount: msg.value, encryptedParams: encryptedParams
        });

        trade.status = TradeStatus.BothDeposited;

        _totalEscrowedETH += msg.value;

        emit TradeMatched(tradeId);
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
            depositor: msg.sender, exists: true, token: token, amount: amount, encryptedParams: encryptedParams
        });

        trade.status = TradeStatus.BothDeposited;

        _totalEscrowedToken[token] += amount;

        emit TradeMatched(tradeId);
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
        if (msg.sender != trade.partyA.depositor) revert OnlyDepositor(tradeId);

        // EFFECTS
        trade.status = TradeStatus.Expired;
        uint256 refundAmount = trade.partyA.amount;
        address refundToken = trade.partyA.token;
        address refundTo = trade.partyA.depositor;

        // Update escrow tracking
        if (refundToken == address(0)) {
            _totalEscrowedETH -= refundAmount;
        } else {
            _totalEscrowedToken[refundToken] -= refundAmount;
        }

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

        // Decode the report — bytes data supports both string reasons and cross-chain data
        // ABI encoding of (bytes32, uint8, string) and (bytes32, uint8, bytes) is identical,
        // so existing same-chain reports decode correctly with this format.
        (bytes32 tradeId, uint8 actionRaw, bytes memory data) = abi.decode(report, (bytes32, uint8, bytes));

        Trade storage trade = _trades[tradeId];

        if (trade.status != TradeStatus.BothDeposited) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.BothDeposited);
        }

        if (actionRaw == uint8(ReportAction.Settle)) {
            _executeSettlement(trade, tradeId);
        } else if (actionRaw == uint8(ReportAction.Refund)) {
            _executeRefund(trade, tradeId, string(data));
        } else if (actionRaw == uint8(ReportAction.CrossChainSettle)) {
            _executeCrossChainSettlement(trade, tradeId, data);
        } else {
            revert InvalidAction(actionRaw);
        }
    }

    // ============ Admin Functions ============

    /// @notice Emergency function to rescue accidentally sent tokens (NOT trade deposits)
    /// @dev Only callable by owner. Cannot withdraw escrowed trade deposits.
    /// @param token Token to rescue (address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to rescue
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        if (to == address(0)) revert ETHTransferFailed(address(0), amount);

        if (token == address(0)) {
            uint256 available = address(this).balance - _totalEscrowedETH;
            if (amount > available) revert ZeroAmount();
            (bool success,) = to.call{value: amount}("");
            if (!success) revert ETHTransferFailed(to, amount);
        } else {
            uint256 available = IERC20(token).balanceOf(address(this)) - _totalEscrowedToken[token];
            if (amount > available) revert ZeroAmount();
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

        // Update escrow tracking
        if (tokenA == address(0)) { _totalEscrowedETH -= amountA; } else { _totalEscrowedToken[tokenA] -= amountA; }
        if (tokenB == address(0)) { _totalEscrowedETH -= amountB; } else { _totalEscrowedToken[tokenB] -= amountB; }

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

        // Update escrow tracking
        if (tokenA == address(0)) { _totalEscrowedETH -= amountA; } else { _totalEscrowedToken[tokenA] -= amountA; }
        if (tokenB == address(0)) { _totalEscrowedETH -= amountB; } else { _totalEscrowedToken[tokenB] -= amountB; }

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

    /// @notice Execute cross-chain DvP settlement via CCIP
    /// @dev Called from onReport() when action = CrossChainSettle (2).
    ///      Sends settlement instructions to the receiver on the destination chain.
    ///      Trade transitions to CrossChainPending until CCIP delivers or timeout triggers refund.
    /// @param trade Storage pointer to the trade
    /// @param tradeId The trade identifier
    /// @param data ABI-encoded (uint64 destChainSelector, bytes settlementData)
    function _executeCrossChainSettlement(Trade storage trade, bytes32 tradeId, bytes memory data) internal {
        (uint64 destChainSelector, bytes memory settlementData) = abi.decode(data, (uint64, bytes));

        address receiver = allowedReceivers[destChainSelector];
        if (receiver == address(0)) revert ReceiverNotConfigured(destChainSelector);

        Client.EVM2AnyMessage memory message = _buildCCIPMessage(receiver, settlementData);
        uint256 fees = CCIP_ROUTER.getFee(destChainSelector, message);
        if (address(this).balance < fees) revert InsufficientCCIPFee(fees, address(this).balance);

        // EFFECTS
        trade.status = TradeStatus.CrossChainPending;
        crossChainInitiatedAt[tradeId] = block.timestamp;

        // INTERACTIONS
        bytes32 messageId = CCIP_ROUTER.ccipSend{value: fees}(destChainSelector, message);
        ccipMessageToTrade[messageId] = tradeId;

        emit CrossChainSettlementSent(tradeId, messageId, destChainSelector);
    }

    // ============ CCIP Cross-Chain Functions ============

    /// @inheritdoc IOTCVault
    function setAllowedReceiver(uint64 chainSelector, address receiver) external onlyOwner {
        if (receiver == address(0)) revert ZeroDeposit();
        allowedReceivers[chainSelector] = receiver;
        emit AllowedReceiverSet(chainSelector, receiver);
    }

    /// @inheritdoc IOTCVault
    function estimateCCIPFee(uint64 destChainSelector, bytes calldata settlementData)
        external
        view
        returns (uint256 fee)
    {
        address receiver = allowedReceivers[destChainSelector];
        if (receiver == address(0)) revert ReceiverNotConfigured(destChainSelector);

        Client.EVM2AnyMessage memory message = _buildCCIPMessage(receiver, settlementData);
        fee = CCIP_ROUTER.getFee(destChainSelector, message);
    }

    /// @inheritdoc IOTCVault
    function refundTimedOutCrossChain(bytes32 tradeId) external nonReentrant {
        Trade storage trade = _trades[tradeId];

        if (trade.status != TradeStatus.CrossChainPending) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.CrossChainPending);
        }
        if (block.timestamp < crossChainInitiatedAt[tradeId] + TacitConstants.CROSS_CHAIN_TIMEOUT) {
            revert CrossChainNotTimedOut(tradeId);
        }

        _executeRefund(trade, tradeId, "cross-chain-timeout");
    }

    /// @notice Send cross-chain settlement instructions via CCIP
    /// @dev Only callable by KeystoneForwarder as part of the CRE workflow settlement.
    ///      The trade must be in BothDeposited status. After sending, status becomes CrossChainPending.
    /// @param tradeId The trade being settled cross-chain
    /// @param destChainSelector The CCIP chain selector for the destination chain
    /// @param settlementData ABI-encoded settlement instructions for the receiver
    /// @return messageId The CCIP message identifier for tracking
    function sendCrossChainSettlement(bytes32 tradeId, uint64 destChainSelector, bytes calldata settlementData)
        external
        nonReentrant
        returns (bytes32 messageId)
    {
        // CHECKS
        if (msg.sender != KEYSTONE_FORWARDER) revert OnlyForwarder();

        Trade storage trade = _trades[tradeId];
        if (trade.status != TradeStatus.BothDeposited) {
            revert InvalidTradeStatus(tradeId, trade.status, TradeStatus.BothDeposited);
        }

        address receiver = allowedReceivers[destChainSelector];
        if (receiver == address(0)) revert ReceiverNotConfigured(destChainSelector);

        Client.EVM2AnyMessage memory message = _buildCCIPMessage(receiver, settlementData);

        uint256 fees = CCIP_ROUTER.getFee(destChainSelector, message);
        if (address(this).balance < fees) revert InsufficientCCIPFee(fees, address(this).balance);

        // EFFECTS
        trade.status = TradeStatus.CrossChainPending;
        crossChainInitiatedAt[tradeId] = block.timestamp;

        // INTERACTIONS
        messageId = CCIP_ROUTER.ccipSend{value: fees}(destChainSelector, message);
        ccipMessageToTrade[messageId] = tradeId;

        emit CrossChainSettlementSent(tradeId, messageId, destChainSelector);
    }

    /// @notice Build a CCIP message for cross-chain settlement (data-only, no token transfer)
    /// @param receiver The receiver contract address on the destination chain
    /// @param data The encoded settlement instructions
    /// @return message The CCIP message struct
    function _buildCCIPMessage(address receiver, bytes memory data)
        internal
        pure
        returns (Client.EVM2AnyMessage memory message)
    {
        message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: data,
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.GenericExtraArgsV2({gasLimit: TacitConstants.CCIP_GAS_LIMIT, allowOutOfOrderExecution: true})
            ),
            feeToken: address(0) // Pay fees in native ETH
        });
    }

    // ============ Receive ============

    /// @notice Allow contract to receive ETH (for CCIP fee payments, etc.)
    receive() external payable {}
}
