// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OTCVault} from "../src/OTCVault.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";

/// @title ConfigurePermissions
/// @notice Post-deploy script to verify and log configuration
/// @dev Since KeystoneForwarder is immutable, this script primarily verifies the deploy.
///      If ownership needs to be transferred, it handles Ownable2Step transfer.
/// Usage: forge script script/ConfigurePermissions.s.sol --rpc-url sepolia --broadcast
contract ConfigurePermissions is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address otcVaultAddr = vm.envAddress("OTC_VAULT_ADDRESS");
        address registryAddr = vm.envAddress("COMPLIANCE_REGISTRY_ADDRESS");

        OTCVault vault = OTCVault(payable(otcVaultAddr));
        ComplianceRegistry registry = ComplianceRegistry(registryAddr);

        console2.log("=== Configuration Verification ===");
        console2.log("OTCVault:", otcVaultAddr);
        console2.log("  KeystoneForwarder:", vault.KEYSTONE_FORWARDER());
        console2.log("  Owner:", vault.owner());
        console2.log("");
        console2.log("ComplianceRegistry:", registryAddr);
        console2.log("  KeystoneForwarder:", registry.KEYSTONE_FORWARDER());
        console2.log("  Owner:", registry.owner());
        console2.log("  Attestation Count:", registry.attestationCount());

        // Optional: transfer ownership if needed
        address newOwner = vm.envOr("NEW_OWNER", address(0));
        if (newOwner != address(0)) {
            vm.startBroadcast(deployerPrivateKey);

            console2.log("");
            console2.log("Transferring ownership to:", newOwner);

            vault.transferOwnership(newOwner);
            registry.transferOwnership(newOwner);

            console2.log("Ownership transfer initiated (pending acceptance via Ownable2Step)");

            vm.stopBroadcast();
        }
    }
}
