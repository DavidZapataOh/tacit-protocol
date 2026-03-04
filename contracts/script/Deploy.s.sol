// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OTCVault} from "../src/OTCVault.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";

/// @title Deploy
/// @notice Deploys OTCVault and ComplianceRegistry to a target chain
/// @dev Usage:
///   Sepolia:          forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify
///   Arbitrum Sepolia: forge script script/Deploy.s.sol --rpc-url arbitrum_sepolia --broadcast --verify
///   Local:            forge script script/Deploy.s.sol --rpc-url localhost --broadcast
contract Deploy is Script {
    /// @notice Deployed contract addresses
    OTCVault public otcVault;
    ComplianceRegistry public complianceRegistry;

    function setUp() public {}

    function run() public {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // KeystoneForwarder address — different per chain
        // For initial development, use deployer as forwarder (will be updated post-CRE deploy)
        address keystoneForwarder = vm.envOr("KEYSTONE_FORWARDER", deployer);

        console2.log("=== Tacit Deploy ===");
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);
        console2.log("KeystoneForwarder:", keystoneForwarder);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ComplianceRegistry
        complianceRegistry = new ComplianceRegistry(keystoneForwarder, deployer);
        console2.log("ComplianceRegistry deployed at:", address(complianceRegistry));

        // 2. Deploy OTCVault
        address ccipRouter = vm.envOr("CCIP_ROUTER_SEPOLIA", address(0));
        console2.log("CCIP Router:", ccipRouter);
        otcVault = new OTCVault(keystoneForwarder, deployer, ccipRouter);
        console2.log("OTCVault deployed at:", address(otcVault));

        vm.stopBroadcast();

        // Print deployment summary
        console2.log("");
        console2.log("=== Deployment Summary ===");
        console2.log("Chain ID:", block.chainid);
        console2.log("OTCVault:", address(otcVault));
        console2.log("ComplianceRegistry:", address(complianceRegistry));
        console2.log("KeystoneForwarder:", keystoneForwarder);
        console2.log("Owner:", deployer);
        console2.log("=========================");
    }
}
