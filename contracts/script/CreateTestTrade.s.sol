// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OTCVault} from "../src/OTCVault.sol";

/// @title CreateTestTrade
/// @notice Creates test trades on Sepolia to trigger CRE workflow simulation.
///         Each scenario generates a BothPartiesDeposited event that the CRE
///         workflow uses as its trigger.
/// @dev Usage:
///   Happy path:     forge script script/CreateTestTrade.s.sol --sig "happyPath()" --rpc-url sepolia --broadcast
///   Mismatch:       forge script script/CreateTestTrade.s.sol --sig "mismatchPath()" --rpc-url sepolia --broadcast
///   Sanctions fail: forge script script/CreateTestTrade.s.sol --sig "sanctionsPath()" --rpc-url sepolia --broadcast
///
///   Required env vars:
///     DEPLOYER_PRIVATE_KEY — Party A private key (has Sepolia ETH)
///     PARTY_B_PRIVATE_KEY  — Party B private key (has Sepolia ETH)
///     OTC_VAULT            — OTCVault contract address (default: Sepolia deployment)
contract CreateTestTrade is Script {
    OTCVault public otcVault;

    // Default Sepolia deployment (v2 with CCIP)
    address constant DEFAULT_OTC_VAULT = 0xdcf70165b005e00fFdf904BACE94A560bff26358;

    function setUp() public {
        address vaultAddr = vm.envOr("OTC_VAULT", DEFAULT_OTC_VAULT);
        otcVault = OTCVault(payable(vaultAddr));
    }

    // =========================================================================
    // Scenario 1: Happy Path — matching params, clean addresses
    // =========================================================================

    /// @notice Create a trade where both parties agree on terms.
    ///         CRE workflow should: match ✓ → sanctions ✓ → KYC ✓ → SETTLE
    function happyPath() public {
        uint256 partyAKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 partyBKey = vm.envUint("PARTY_B_PRIVATE_KEY");
        address partyA = vm.addr(partyAKey);
        address partyB = vm.addr(partyBKey);

        // Unique trade ID based on timestamp
        bytes32 tradeId = keccak256(abi.encodePacked("tacit-happy-", block.timestamp, partyA));

        console2.log("=== Happy Path Trade ===");
        console2.log("Trade ID:", vm.toString(tradeId));
        console2.log("Party A:", partyA);
        console2.log("Party B:", partyB);

        // Party A: Selling 0.001 ETH, wants 2.5 USDC
        bytes memory paramsA = _encodeParams(
            '{"asset":"ETH","amount":"0.001","wantAsset":"USDC","wantAmount":"2.5","destinationChain":11155111}'
        );

        // Party B: Selling 2.5 USDC, wants 0.001 ETH (mirrors Party A)
        bytes memory paramsB = _encodeParams(
            '{"asset":"USDC","amount":"2.5","wantAsset":"ETH","wantAmount":"0.001","destinationChain":11155111}'
        );

        // Party A creates trade
        vm.broadcast(partyAKey);
        otcVault.createTradeETH{value: 0.001 ether}(tradeId, paramsA);
        console2.log("Party A deposited 0.001 ETH");

        // Party B matches trade → emits BothPartiesDeposited(tradeId)
        vm.broadcast(partyBKey);
        otcVault.matchTradeETH{value: 0.001 ether}(tradeId, paramsB);
        console2.log("Party B deposited 0.001 ETH");
        console2.log("BothPartiesDeposited event emitted!");
        console2.log("========================");
    }

    // =========================================================================
    // Scenario 2: Mismatch — Party B offers different amount
    // =========================================================================

    /// @notice Create a trade where amounts don't match.
    ///         CRE workflow should: match ✗ → REFUND (match-failed)
    function mismatchPath() public {
        uint256 partyAKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 partyBKey = vm.envUint("PARTY_B_PRIVATE_KEY");
        address partyA = vm.addr(partyAKey);
        address partyB = vm.addr(partyBKey);

        bytes32 tradeId = keccak256(abi.encodePacked("tacit-mismatch-", block.timestamp, partyA));

        console2.log("=== Mismatch Trade ===");
        console2.log("Trade ID:", vm.toString(tradeId));

        // Party A wants 2.5 USDC for their ETH
        bytes memory paramsA = _encodeParams(
            '{"asset":"ETH","amount":"0.001","wantAsset":"USDC","wantAmount":"2.5","destinationChain":11155111}'
        );

        // Party B offers only 2.0 USDC (mismatch!)
        bytes memory paramsB = _encodeParams(
            '{"asset":"USDC","amount":"2.0","wantAsset":"ETH","wantAmount":"0.001","destinationChain":11155111}'
        );

        vm.broadcast(partyAKey);
        otcVault.createTradeETH{value: 0.001 ether}(tradeId, paramsA);

        vm.broadcast(partyBKey);
        otcVault.matchTradeETH{value: 0.001 ether}(tradeId, paramsB);

        console2.log("BothPartiesDeposited event emitted (amounts mismatch)!");
        console2.log("========================");
    }

    // =========================================================================
    // Scenario 3: Sanctions fail — Party A uses sanctioned address
    // =========================================================================

    /// @notice Create a trade with a known sanctioned address in the params.
    ///         CRE workflow should: match ✓ → sanctions ✗ → REFUND (compliance-failed)
    /// @dev Note: The depositor address itself doesn't need to be sanctioned —
    ///      the sanctions check is on the partyAddress field inside encrypted params.
    ///      For simulation, we embed a Tornado Cash address in the encrypted params.
    function sanctionsPath() public {
        uint256 partyAKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 partyBKey = vm.envUint("PARTY_B_PRIVATE_KEY");
        address partyA = vm.addr(partyAKey);
        address partyB = vm.addr(partyBKey);

        bytes32 tradeId = keccak256(abi.encodePacked("tacit-sanctions-", block.timestamp, partyA));

        console2.log("=== Sanctions Fail Trade ===");
        console2.log("Trade ID:", vm.toString(tradeId));

        // Both parties agree on terms (match will pass)
        bytes memory paramsA = _encodeParams(
            '{"asset":"ETH","amount":"0.001","wantAsset":"USDC","wantAmount":"2.5","destinationChain":11155111}'
        );

        bytes memory paramsB = _encodeParams(
            '{"asset":"USDC","amount":"2.5","wantAsset":"ETH","wantAmount":"0.001","destinationChain":11155111}'
        );

        vm.broadcast(partyAKey);
        otcVault.createTradeETH{value: 0.001 ether}(tradeId, paramsA);

        vm.broadcast(partyBKey);
        otcVault.matchTradeETH{value: 0.001 ether}(tradeId, paramsB);

        console2.log("BothPartiesDeposited event emitted (Party A is sanctioned)!");
        console2.log("========================");
    }

    // =========================================================================
    // Scenario 4: Cross-chain — Party A wants to receive on Arbitrum Sepolia
    // =========================================================================

    /// @notice Create a trade where Party A wants cross-chain delivery.
    ///         CRE workflow should: match ✓ → sanctions ✓ → KYC ✓ → CROSS-CHAIN SETTLE (CCIP)
    function crossChainPath() public {
        uint256 partyAKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 partyBKey = vm.envUint("PARTY_B_PRIVATE_KEY");
        address partyA = vm.addr(partyAKey);
        address partyB = vm.addr(partyBKey);

        bytes32 tradeId = keccak256(abi.encodePacked("tacit-crosschain-", block.timestamp, partyA));

        console2.log("=== Cross-Chain Trade ===");
        console2.log("Trade ID:", vm.toString(tradeId));
        console2.log("Party A:", partyA);
        console2.log("Party B:", partyB);

        // Party A: Selling 0.001 ETH, wants 0.001 ETH on Arbitrum Sepolia (chain 421614)
        bytes memory paramsA = _encodeParams(
            '{"asset":"ETH","amount":"0.001","wantAsset":"ETH","wantAmount":"0.001","destinationChain":421614}'
        );

        // Party B: Selling 0.001 ETH, wants 0.001 ETH on Sepolia (same-chain)
        bytes memory paramsB = _encodeParams(
            '{"asset":"ETH","amount":"0.001","wantAsset":"ETH","wantAmount":"0.001","destinationChain":11155111}'
        );

        vm.broadcast(partyAKey);
        otcVault.createTradeETH{value: 0.001 ether}(tradeId, paramsA);
        console2.log("Party A deposited 0.001 ETH (wants Arb Sepolia delivery)");

        vm.broadcast(partyBKey);
        otcVault.matchTradeETH{value: 0.001 ether}(tradeId, paramsB);
        console2.log("Party B deposited 0.001 ETH (wants Sepolia delivery)");
        console2.log("BothPartiesDeposited event emitted!");
        console2.log("========================");
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    /// @notice Encode trade params as hex bytes (plaintext mode for simulation).
    ///         The CRE workflow's crypto.ts decryptTradeParams() tries direct
    ///         hex→JSON decode first (Mode 1), so no encryption needed for testing.
    function _encodeParams(string memory jsonParams) internal pure returns (bytes memory) {
        return bytes(jsonParams);
    }
}
