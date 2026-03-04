// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OTCVault} from "../src/OTCVault.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";

/// @title DeployLocal
/// @notice Deploys contracts to local Anvil with deterministic addresses
/// @dev Usage: forge script script/DeployLocal.s.sol --rpc-url localhost --broadcast
contract DeployLocal is Script {
    // Anvil default account #0 (publicly known key — NEVER use on testnet/mainnet)
    uint256 constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() public {
        address deployer = vm.addr(ANVIL_PRIVATE_KEY);

        console2.log("=== Tacit Local Deploy ===");
        console2.log("Deployer:", deployer);

        vm.startBroadcast(ANVIL_PRIVATE_KEY);

        // Use deployer as KeystoneForwarder for local testing
        ComplianceRegistry complianceRegistry = new ComplianceRegistry(deployer, deployer);
        console2.log("ComplianceRegistry:", address(complianceRegistry));

        OTCVault otcVault = new OTCVault(deployer, deployer);
        console2.log("OTCVault:", address(otcVault));

        vm.stopBroadcast();

        console2.log("");
        console2.log("=== Local Deploy Complete ===");
        console2.log("Use deployer address as KeystoneForwarder to call onReport() via cast");
    }
}
