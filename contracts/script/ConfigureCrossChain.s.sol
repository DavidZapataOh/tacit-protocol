// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OTCVault} from "../src/OTCVault.sol";

/// @title ConfigureCrossChain
/// @notice Configures OTCVault on Sepolia to recognize OTCVaultReceiver on Arbitrum Sepolia
/// @dev Run AFTER deploying OTCVaultReceiver on Arbitrum Sepolia.
///   Usage: forge script script/ConfigureCrossChain.s.sol --rpc-url sepolia --broadcast -vvv
contract ConfigureCrossChain is Script {
    /// @notice Arbitrum Sepolia chain selector (from CCIP Directory)
    uint64 constant ARBITRUM_SEPOLIA_CHAIN_SELECTOR = 3_478_487_238_524_512_106;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Read addresses from .env
        address otcVaultAddress = vm.envAddress("OTC_VAULT_SEPOLIA");
        address receiverAddress = vm.envAddress("OTC_VAULT_RECEIVER_ARBITRUM");

        console2.log("=== Configure Cross-Chain (Sepolia) ===");
        console2.log("Deployer:", deployer);
        console2.log("OTCVault:", otcVaultAddress);
        console2.log("Receiver (Arbitrum Sepolia):", receiverAddress);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        OTCVault vault = OTCVault(payable(otcVaultAddress));

        // Set the Arbitrum Sepolia receiver as allowed destination
        vault.setAllowedReceiver(ARBITRUM_SEPOLIA_CHAIN_SELECTOR, receiverAddress);

        vm.stopBroadcast();

        console2.log("=== Configuration Complete ===");
        console2.log("OTCVault allowedReceivers updated:");
        console2.log("  Chain selector (Arb Sepolia):", ARBITRUM_SEPOLIA_CHAIN_SELECTOR);
        console2.log("  Receiver:", receiverAddress);
        console2.log("");
        console2.log("Verify with:");
        console2.log("  cast call", otcVaultAddress);
        console2.log('  "allowedReceivers(uint64)(address)" 3478487238524512106');
        console2.log("  --rpc-url sepolia");
        console2.log("==============================");
    }
}
