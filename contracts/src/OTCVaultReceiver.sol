// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {SettlementEncoder} from "./libraries/SettlementEncoder.sol";

/// @title OTCVaultReceiver
/// @author Tacit Protocol
/// @notice Receives cross-chain settlement instructions via CCIP and executes
///         the destination-chain leg of a cross-chain DvP trade.
/// @dev Inherits CCIPReceiver for CCIP message handling. Only processes
///      messages from authorized senders on allowed source chains.
///      Deployed on Arbitrum Sepolia to receive instructions from OTCVault on Sepolia.
contract OTCVaultReceiver is CCIPReceiver, ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20;

    // ═══════════════════════════════════════════════════════════════
    //                        TYPE DECLARATIONS
    // ═══════════════════════════════════════════════════════════════

    enum SettlementStatus {
        None,
        Executed,
        Failed
    }

    // ═══════════════════════════════════════════════════════════════
    //                        STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════

    /// @notice Mapping of source chain selector => allowed sender address
    mapping(uint64 => address) public allowedSenders;

    /// @notice Mapping of CCIP messageId => settlement status
    mapping(bytes32 => SettlementStatus) public settlementStatus;

    /// @notice Mapping of tradeId => whether settlement was executed on this chain
    mapping(bytes32 => bool) public tradeSettled;

    /// @notice Mapping of CCIP messageId => tradeId for tracking
    mapping(bytes32 => bytes32) public messageToTrade;

    // ═══════════════════════════════════════════════════════════════
    //                           EVENTS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Emitted when a cross-chain settlement is executed on this chain
    /// @param tradeId The trade identifier from the source chain
    /// @param messageId The CCIP message that triggered this settlement
    /// @param recipient The address that received the assets
    /// @param token The token transferred (address(0) for ETH)
    /// @param amount The amount transferred
    event CrossChainSettlementReceived(
        bytes32 indexed tradeId,
        bytes32 indexed messageId,
        address indexed recipient,
        address token,
        uint256 amount
    );

    /// @notice Emitted when an allowed sender is configured
    /// @param chainSelector The source chain selector
    /// @param sender The allowed sender address
    event AllowedSenderSet(uint64 indexed chainSelector, address indexed sender);

    /// @notice Emitted when a cross-chain settlement fails during execution
    /// @param tradeId The trade that failed settlement
    /// @param messageId The CCIP message ID
    /// @param reason The failure reason
    event CrossChainSettlementFailed(bytes32 indexed tradeId, bytes32 indexed messageId, bytes reason);

    // ═══════════════════════════════════════════════════════════════
    //                           ERRORS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Thrown when a message comes from an unauthorized sender
    error UnauthorizedSender(uint64 sourceChainSelector, address sender);

    /// @notice Thrown when a message comes from a chain with no allowed sender
    error SourceChainNotAllowed(uint64 sourceChainSelector);

    /// @notice Thrown when trying to settle a trade that was already settled
    error TradeAlreadySettled(bytes32 tradeId);

    /// @notice Thrown when the receiver has insufficient balance for ETH transfer
    error InsufficientBalance(uint256 available, uint256 required);

    /// @notice Thrown when an ETH transfer fails
    error ETHTransferFailed(address recipient, uint256 amount);

    /// @notice Thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Thrown when a zero amount is provided
    error ZeroAmount();

    // ═══════════════════════════════════════════════════════════════
    //                          CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════

    /// @notice Initializes the receiver with the CCIP Router
    /// @param router The CCIP Router address on this chain (e.g., Arbitrum Sepolia)
    constructor(address router) CCIPReceiver(router) Ownable(msg.sender) {}

    // ═══════════════════════════════════════════════════════════════
    //                      RECEIVE FUNCTION
    // ═══════════════════════════════════════════════════════════════

    /// @notice Allows contract to receive ETH for settlement distributions
    receive() external payable {}

    // ═══════════════════════════════════════════════════════════════
    //                      ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Configures an allowed sender on a source chain
    /// @dev Only callable by the contract owner. The sender should be the
    ///      OTCVault contract address on the source chain.
    /// @param sourceChainSelector The CCIP chain selector of the source chain
    /// @param sender The authorized sender contract address
    function setAllowedSender(uint64 sourceChainSelector, address sender) external onlyOwner {
        if (sender == address(0)) revert ZeroAddress();
        allowedSenders[sourceChainSelector] = sender;
        emit AllowedSenderSet(sourceChainSelector, sender);
    }

    /// @notice Allows owner to withdraw ETH (for funding or recovery)
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        (bool success,) = to.call{value: amount}("");
        if (!success) revert ETHTransferFailed(to, amount);
    }

    /// @notice Allows owner to withdraw ERC-20 tokens
    /// @param token The token to withdraw
    /// @param to The recipient address
    /// @param amount The amount to withdraw
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
    }

    // ═══════════════════════════════════════════════════════════════
    //                     CCIP RECEIVE LOGIC
    // ═══════════════════════════════════════════════════════════════

    /// @notice Processes incoming CCIP messages containing settlement instructions
    /// @dev Called by the CCIP Router via ccipReceive(). Validates the sender,
    ///      decodes instructions via SettlementEncoder, and executes the transfer.
    ///      Follows CEI pattern: marks settled BEFORE executing transfers.
    /// @param message The CCIP message containing settlement data
    function _ccipReceive(Client.Any2EVMMessage memory message) internal override nonReentrant {
        // CHECKS: Verify sender authorization
        uint64 sourceChainSelector = message.sourceChainSelector;
        address sender = abi.decode(message.sender, (address));

        address allowedSender = allowedSenders[sourceChainSelector];
        if (allowedSender == address(0)) revert SourceChainNotAllowed(sourceChainSelector);
        if (sender != allowedSender) revert UnauthorizedSender(sourceChainSelector, sender);

        // Decode settlement instructions using shared library
        SettlementEncoder.SettlementInstruction memory instruction = SettlementEncoder.decode(message.data);

        // Validate instruction
        if (instruction.recipient == address(0)) revert ZeroAddress();
        if (instruction.amount == 0) revert ZeroAmount();

        // Verify trade hasn't been settled already
        if (tradeSettled[instruction.tradeId]) {
            revert TradeAlreadySettled(instruction.tradeId);
        }

        // EFFECTS: Mark as settled before interactions (CEI pattern)
        tradeSettled[instruction.tradeId] = true;
        settlementStatus[message.messageId] = SettlementStatus.Executed;
        messageToTrade[message.messageId] = instruction.tradeId;

        // INTERACTIONS: Execute the transfer
        if (instruction.token == address(0)) {
            // Native ETH transfer
            if (address(this).balance < instruction.amount) {
                revert InsufficientBalance(address(this).balance, instruction.amount);
            }
            (bool success,) = instruction.recipient.call{value: instruction.amount}("");
            if (!success) revert ETHTransferFailed(instruction.recipient, instruction.amount);
        } else {
            // ERC-20 token transfer
            IERC20(instruction.token).safeTransfer(instruction.recipient, instruction.amount);
        }

        emit CrossChainSettlementReceived(
            instruction.tradeId, message.messageId, instruction.recipient, instruction.token, instruction.amount
        );
    }

    // ═══════════════════════════════════════════════════════════════
    //                       VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════

    /// @notice Checks if a trade has been settled on this chain
    /// @param tradeId The trade identifier
    /// @return settled Whether the trade has been settled
    function isTradeSettled(bytes32 tradeId) external view returns (bool settled) {
        settled = tradeSettled[tradeId];
    }

    /// @notice Gets the settlement status for a CCIP message
    /// @param messageId The CCIP message ID
    /// @return status The settlement status
    function getSettlementStatus(bytes32 messageId) external view returns (SettlementStatus status) {
        status = settlementStatus[messageId];
    }
}
