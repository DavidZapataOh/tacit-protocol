// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {OTCVaultReceiver} from "../src/OTCVaultReceiver.sol";

/// @title UpdateAllowedSender
/// @notice Updates the allowed sender on OTCVaultReceiver (Arbitrum Sepolia)
/// @dev Use when OTCVault is re-deployed on Sepolia and the address changes.
///   Usage: forge script script/UpdateAllowedSender.s.sol --rpc-url arbitrum_sepolia --broadcast -vvv
contract UpdateAllowedSender is Script {
    /// @notice Sepolia chain selector
    uint64 constant SEPOLIA_CHAIN_SELECTOR = 16_015_286_601_757_825_753;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address receiverAddress = vm.envAddress("OTC_VAULT_RECEIVER_ARBITRUM");
        address newOtcVaultSepolia = vm.envAddress("OTC_VAULT_SEPOLIA");

        console2.log("=== Update Allowed Sender (Arbitrum Sepolia) ===");
        console2.log("Deployer:", deployer);
        console2.log("Receiver:", receiverAddress);
        console2.log("New OTCVault Sepolia:", newOtcVaultSepolia);
        console2.log("");

        vm.startBroadcast(deployerPrivateKey);

        OTCVaultReceiver receiver = OTCVaultReceiver(payable(receiverAddress));
        receiver.setAllowedSender(SEPOLIA_CHAIN_SELECTOR, newOtcVaultSepolia);

        vm.stopBroadcast();

        console2.log("Allowed sender updated successfully");
        console2.log("  Chain selector (Sepolia):", SEPOLIA_CHAIN_SELECTOR);
        console2.log("  Sender:", newOtcVaultSepolia);
    }
}
