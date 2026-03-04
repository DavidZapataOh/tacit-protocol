// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IOTCVault
/// @author Tacit Protocol
/// @notice Interface for the OTC Vault contract that manages encrypted trade deposits and settlements
/// @dev Trade parameters are stored as encrypted ciphertext; only the CRE workflow (TEE) can decrypt
interface IOTCVault {
    // ============ Enums ============

    /// @notice States of a trade in the settlement lifecycle
    /// @dev State machine: Created -> BothDeposited -> Settled | Refunded | Expired
    enum TradeStatus {
        None,           // 0: Trade does not exist
        Created,        // 1: Party A has deposited
        BothDeposited,  // 2: Both parties have deposited, awaiting CRE workflow
        Settled,        // 3: Trade settled successfully (DvP executed)
        Refunded,       // 4: Trade refunded (compliance failed or parameter mismatch)
        Expired         // 5: Trade expired (timeout reached before Party B deposited)
    }

    // ============ Structs ============

    /// @notice Represents one side of a trade deposit
    struct Deposit {
        address depositor;           // Address that made the deposit
        address token;               // Token address (address(0) for ETH)
        uint256 amount;              // Amount deposited
        bytes encryptedParams;       // Trade parameters encrypted with Vault DON public key
        bool exists;                 // Whether this deposit exists
    }

    /// @notice Represents a complete trade between two counterparties
    struct Trade {
        bytes32 tradeId;             // Unique trade identifier
        Deposit partyA;              // Party A's deposit
        Deposit partyB;              // Party B's deposit
        TradeStatus status;          // Current trade status
        uint256 createdAt;           // Timestamp of trade creation
        uint256 expiresAt;           // Timestamp when trade expires if Party B hasn't deposited
    }

    // ============ Events ============

    /// @notice Emitted when Party A creates a new trade and deposits
    /// @param tradeId The unique trade identifier
    /// @param partyA Address of the trade creator
    /// @param token Token deposited (address(0) for ETH)
    /// @param amount Amount deposited
    event TradeCreated(
        bytes32 indexed tradeId,
        address indexed partyA,
        address token,
        uint256 amount
    );

    /// @notice Emitted when Party B matches a trade and deposits
    /// @param tradeId The unique trade identifier
    /// @param partyB Address of the matching counterparty
    /// @param token Token deposited (address(0) for ETH)
    /// @param amount Amount deposited
    event TradeMatched(
        bytes32 indexed tradeId,
        address indexed partyB,
        address token,
        uint256 amount
    );

    /// @notice Emitted when both parties have deposited, triggering the CRE workflow
    /// @param tradeId The unique trade identifier
    event BothPartiesDeposited(bytes32 indexed tradeId);

    /// @notice Emitted when a trade is settled successfully (DvP executed)
    /// @param tradeId The unique trade identifier
    event TradeSettled(bytes32 indexed tradeId);

    /// @notice Emitted when a trade is refunded (compliance failure, mismatch, or timeout)
    /// @param tradeId The unique trade identifier
    /// @param reason The reason for refund
    event TradeRefunded(bytes32 indexed tradeId, string reason);

    // ============ Errors ============

    /// @notice Thrown when a trade with the given ID does not exist
    error TradeNotFound(bytes32 tradeId);

    /// @notice Thrown when attempting an action on a trade in an invalid state
    error InvalidTradeStatus(bytes32 tradeId, TradeStatus current, TradeStatus expected);

    /// @notice Thrown when the deposit amount is zero
    error ZeroAmount();

    /// @notice Thrown when depositing a zero address token without sending ETH
    error ZeroDeposit();

    /// @notice Thrown when a trade with the given ID already exists
    error TradeAlreadyExists(bytes32 tradeId);

    /// @notice Thrown when Party A tries to match their own trade
    error CannotMatchOwnTrade(bytes32 tradeId);

    /// @notice Thrown when caller is not the KeystoneForwarder
    error OnlyForwarder();

    /// @notice Thrown when an ETH transfer fails
    error ETHTransferFailed(address to, uint256 amount);

    /// @notice Thrown when the trade has expired
    error TradeExpired(bytes32 tradeId);

    /// @notice Thrown when the trade has not expired yet (cannot claim early refund)
    error TradeNotExpired(bytes32 tradeId);

    /// @notice Thrown when encrypted parameters are empty
    error EmptyEncryptedParams();

    // ============ External Functions ============

    /// @notice Create a new trade and deposit ETH as Party A
    /// @param tradeId Unique trade identifier (generated client-side)
    /// @param encryptedParams Trade parameters encrypted with Vault DON public key
    function createTradeETH(bytes32 tradeId, bytes calldata encryptedParams) external payable;

    /// @notice Create a new trade and deposit ERC-20 tokens as Party A
    /// @param tradeId Unique trade identifier
    /// @param token ERC-20 token address to deposit
    /// @param amount Amount of tokens to deposit
    /// @param encryptedParams Trade parameters encrypted with Vault DON public key
    function createTradeToken(
        bytes32 tradeId,
        address token,
        uint256 amount,
        bytes calldata encryptedParams
    ) external;

    /// @notice Match an existing trade and deposit ETH as Party B
    /// @param tradeId Trade ID to match (received from Party A off-chain)
    /// @param encryptedParams Party B's trade parameters encrypted with Vault DON public key
    function matchTradeETH(bytes32 tradeId, bytes calldata encryptedParams) external payable;

    /// @notice Match an existing trade and deposit ERC-20 tokens as Party B
    /// @param tradeId Trade ID to match
    /// @param token ERC-20 token address to deposit
    /// @param amount Amount of tokens to deposit
    /// @param encryptedParams Party B's trade parameters encrypted with Vault DON public key
    function matchTradeToken(
        bytes32 tradeId,
        address token,
        uint256 amount,
        bytes calldata encryptedParams
    ) external;

    /// @notice Claim refund for an expired trade (only Party A can call after timeout)
    /// @param tradeId Trade ID of the expired trade
    function claimExpiredRefund(bytes32 tradeId) external;

    /// @notice Get trade details
    /// @param tradeId The trade ID to query
    /// @return trade The trade struct
    function getTrade(bytes32 tradeId) external view returns (Trade memory trade);

    /// @notice Get the current status of a trade
    /// @param tradeId The trade ID to query
    /// @return status The current trade status
    function getTradeStatus(bytes32 tradeId) external view returns (TradeStatus status);
}
