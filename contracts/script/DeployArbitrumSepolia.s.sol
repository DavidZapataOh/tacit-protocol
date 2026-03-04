// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OTCVaultReceiver} from "../src/OTCVaultReceiver.sol";

/// @title DeployArbitrumSepolia
/// @notice Deploys OTCVaultReceiver to Arbitrum Sepolia and configures the allowed sender
/// @dev Usage:
///   Dry run:  forge script script/DeployArbitrumSepolia.s.sol --rpc-url arbitrum_sepolia -vvv
///   Deploy:   forge script script/DeployArbitrumSepolia.s.sol --rpc-url arbitrum_sepolia --broadcast --verify -vvv
contract DeployArbitrumSepolia is Script {
    /// @notice Arbitrum Sepolia CCIP Router (from CCIP Directory)
    address constant ARBITRUM_SEPOLIA_ROUTER = 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165;

    /// @notice Sepolia chain selector (for configuring allowed sender)
    uint64 constant SEPOLIA_CHAIN_SELECTOR = 16_015_286_601_757_825_753;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // OTCVault address on Sepolia — must be set in .env
        address otcVaultSepolia = vm.envAddress("OTC_VAULT_SEPOLIA");

        console2.log("=== Tacit Deploy: Arbitrum Sepolia ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("CCIP Router:", ARBITRUM_SEPOLIA_ROUTER);
        console2.log("OTCVault Sepolia (sender):", otcVaultSepolia);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy OTCVaultReceiver
        OTCVaultReceiver receiver = new OTCVaultReceiver(ARBITRUM_SEPOLIA_ROUTER);
        console2.log("OTCVaultReceiver deployed at:", address(receiver));

        // 2. Configure OTCVault on Sepolia as allowed sender
        receiver.setAllowedSender(SEPOLIA_CHAIN_SELECTOR, otcVaultSepolia);
        console2.log("Allowed sender configured:");
        console2.log("  Chain selector (Sepolia):", SEPOLIA_CHAIN_SELECTOR);
        console2.log("  Sender (OTCVault):", otcVaultSepolia);

        vm.stopBroadcast();

        // Print deployment summary
        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("OTCVaultReceiver:", address(receiver));
        console2.log("CCIP Router:", ARBITRUM_SEPOLIA_ROUTER);
        console2.log("Owner:", deployer);
        console2.log("");
        console2.log("NEXT STEPS:");
        console2.log("1. Add to .env: OTC_VAULT_RECEIVER_ARBITRUM=", address(receiver));
        console2.log("2. Run ConfigureCrossChain.s.sol on Sepolia");
        console2.log("3. Fund receiver with ETH for settlement demo");
        console2.log("==========================");
    }
}
