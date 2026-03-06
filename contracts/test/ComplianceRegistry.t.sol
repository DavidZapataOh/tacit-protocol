// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ComplianceRegistry} from "../src/ComplianceRegistry.sol";
import {IComplianceRegistry} from "../src/interfaces/IComplianceRegistry.sol";
import {MockKeystoneForwarder} from "./mocks/MockKeystoneForwarder.sol";

contract ComplianceRegistryTest is Test {
    ComplianceRegistry public registry;
    MockKeystoneForwarder public forwarder;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    bytes32 public tradeId1 = keccak256("trade-001");
    bytes32 public tradeId2 = keccak256("trade-002");
    bytes32 public tradeId3 = keccak256("trade-003");
    bytes public emptyMetadata = "";

    function setUp() public {
        forwarder = new MockKeystoneForwarder();
        registry = new ComplianceRegistry(address(forwarder), owner);
    }

    // ============ Helpers ============

    function _recordAttestation(bytes32 tid, bool result, uint256 timestamp) internal {
        bytes memory report = abi.encode(tid, result, timestamp);
        forwarder.deliverReport(address(registry), emptyMetadata, report);
    }

    // ============ Constructor ============

    function test_Constructor_Deployed() public view {
        assertEq(registry.KEYSTONE_FORWARDER(), address(forwarder));
        assertEq(registry.owner(), owner);
        assertEq(registry.attestationCount(), 0);
    }

    function test_RevertIf_Constructor_ZeroForwarder() public {
        vm.expectRevert(IComplianceRegistry.OnlyForwarder.selector);
        new ComplianceRegistry(address(0), owner);
    }

    // ============ onReport — Record Attestation ============

    function test_OnReport_RecordPassAttestation() public {
        uint256 timestamp = block.timestamp;
        _recordAttestation(tradeId1, true, timestamp);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId1);
        assertEq(att.verified, true);
        assertEq(att.exists, true);
        assertEq(att.timestamp, timestamp);
        assertEq(registry.attestationCount(), 1);
    }

    function test_OnReport_RecordFailAttestation() public {
        uint256 timestamp = block.timestamp;
        _recordAttestation(tradeId1, false, timestamp);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId1);
        assertEq(att.verified, false);
        assertEq(att.exists, true);
        assertEq(att.timestamp, timestamp);
    }

    function test_OnReport_EmitsComplianceVerified() public {
        uint256 timestamp = block.timestamp;

        vm.expectEmit(true, true, true, true);
        emit IComplianceRegistry.ComplianceVerified(tradeId1, true, timestamp);

        _recordAttestation(tradeId1, true, timestamp);
    }

    function test_OnReport_MultipleAttestations() public {
        _recordAttestation(tradeId1, true, block.timestamp);
        _recordAttestation(tradeId2, false, block.timestamp);
        _recordAttestation(tradeId3, true, block.timestamp);

        assertEq(registry.attestationCount(), 3);
        assertEq(registry.hasAttestation(tradeId1), true);
        assertEq(registry.hasAttestation(tradeId2), true);
        assertEq(registry.hasAttestation(tradeId3), true);
    }

    function test_OnReport_IncrementsCount() public {
        assertEq(registry.attestationCount(), 0);

        _recordAttestation(tradeId1, true, block.timestamp);
        assertEq(registry.attestationCount(), 1);

        _recordAttestation(tradeId2, false, block.timestamp);
        assertEq(registry.attestationCount(), 2);
    }

    // ============ onReport — Access Control ============

    function test_RevertIf_OnReport_NotForwarder() public {
        bytes memory report = abi.encode(tradeId1, true, block.timestamp);

        vm.prank(alice);
        vm.expectRevert(IComplianceRegistry.OnlyForwarder.selector);
        registry.onReport(emptyMetadata, report);
    }

    function test_RevertIf_OnReport_DuplicateAttestation() public {
        _recordAttestation(tradeId1, true, block.timestamp);

        bytes memory report = abi.encode(tradeId1, true, block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IComplianceRegistry.AttestationAlreadyExists.selector, tradeId1));
        forwarder.deliverReport(address(registry), emptyMetadata, report);
    }

    function test_RevertIf_OnReport_DuplicateEvenDifferentResult() public {
        _recordAttestation(tradeId1, true, block.timestamp);

        // Even with different result, duplicate trade ID reverts
        bytes memory report = abi.encode(tradeId1, false, block.timestamp + 100);
        vm.expectRevert(abi.encodeWithSelector(IComplianceRegistry.AttestationAlreadyExists.selector, tradeId1));
        forwarder.deliverReport(address(registry), emptyMetadata, report);
    }

    // ============ View Functions — getAttestation ============

    function test_GetAttestation_Success() public {
        uint256 ts = 1_700_000_000;
        _recordAttestation(tradeId1, true, ts);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId1);
        assertEq(att.verified, true);
        assertEq(att.exists, true);
        assertEq(att.timestamp, ts);
    }

    function test_RevertIf_GetAttestation_NotFound() public {
        bytes32 fake = keccak256("nonexistent");
        vm.expectRevert(abi.encodeWithSelector(IComplianceRegistry.AttestationNotFound.selector, fake));
        registry.getAttestation(fake);
    }

    // ============ View Functions — hasAttestation ============

    function test_HasAttestation_True() public {
        _recordAttestation(tradeId1, true, block.timestamp);
        assertEq(registry.hasAttestation(tradeId1), true);
    }

    function test_HasAttestation_False() public view {
        assertEq(registry.hasAttestation(keccak256("nonexistent")), false);
    }

    // ============ View Functions — getAttestedTradeIds (pagination) ============

    function test_GetAttestedTradeIds_AllInOnePage() public {
        _recordAttestation(tradeId1, true, block.timestamp);
        _recordAttestation(tradeId2, false, block.timestamp);

        bytes32[] memory ids = registry.getAttestedTradeIds(0, 10);
        assertEq(ids.length, 2);
        assertEq(ids[0], tradeId1);
        assertEq(ids[1], tradeId2);
    }

    function test_GetAttestedTradeIds_Pagination() public {
        // Create 5 attestations
        for (uint256 i = 0; i < 5; i++) {
            bytes32 tid = keccak256(abi.encodePacked("trade-", i));
            _recordAttestation(tid, true, block.timestamp);
        }

        // Get first 3
        bytes32[] memory page1 = registry.getAttestedTradeIds(0, 3);
        assertEq(page1.length, 3);

        // Get remaining 2
        bytes32[] memory page2 = registry.getAttestedTradeIds(3, 3);
        assertEq(page2.length, 2);

        // Out of bounds returns empty
        bytes32[] memory page3 = registry.getAttestedTradeIds(10, 3);
        assertEq(page3.length, 0);
    }

    function test_GetAttestedTradeIds_OffsetAtExactLength() public {
        _recordAttestation(tradeId1, true, block.timestamp);

        bytes32[] memory ids = registry.getAttestedTradeIds(1, 10);
        assertEq(ids.length, 0);
    }

    function test_GetAttestedTradeIds_EmptyRegistry() public view {
        bytes32[] memory ids = registry.getAttestedTradeIds(0, 10);
        assertEq(ids.length, 0);
    }

    // ============ View Functions — getAttestationsBatch ============

    function test_GetAttestationsBatch_Success() public {
        _recordAttestation(tradeId1, true, block.timestamp);
        _recordAttestation(tradeId2, false, block.timestamp + 100);

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = tradeId1;
        ids[1] = tradeId2;

        IComplianceRegistry.Attestation[] memory atts = registry.getAttestationsBatch(ids);
        assertEq(atts.length, 2);
        assertEq(atts[0].verified, true);
        assertEq(atts[0].exists, true);
        assertEq(atts[1].verified, false);
        assertEq(atts[1].exists, true);
    }

    function test_GetAttestationsBatch_NonExistentReturnsDefault() public {
        _recordAttestation(tradeId1, true, block.timestamp);

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = tradeId1;
        ids[1] = keccak256("nonexistent");

        IComplianceRegistry.Attestation[] memory atts = registry.getAttestationsBatch(ids);
        assertEq(atts.length, 2);
        assertEq(atts[0].exists, true);
        assertEq(atts[1].exists, false); // Default struct: exists=false
        assertEq(atts[1].verified, false);
        assertEq(atts[1].timestamp, 0);
    }

    function test_GetAttestationsBatch_EmptyArray() public view {
        bytes32[] memory ids = new bytes32[](0);
        IComplianceRegistry.Attestation[] memory atts = registry.getAttestationsBatch(ids);
        assertEq(atts.length, 0);
    }

    // ============ Fuzz Tests ============

    function testFuzz_OnReport_AnyTradeId(bytes32 tid) public {
        _recordAttestation(tid, true, block.timestamp);
        assertEq(registry.hasAttestation(tid), true);
    }

    function testFuzz_OnReport_AnyTimestamp(uint256 timestamp) public {
        timestamp = bound(timestamp, 0, type(uint48).max);
        _recordAttestation(tradeId1, true, timestamp);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId1);
        assertEq(att.timestamp, timestamp);
    }

    function testFuzz_OnReport_ResultPreserved(bool result) public {
        _recordAttestation(tradeId1, result, block.timestamp);

        IComplianceRegistry.Attestation memory att = registry.getAttestation(tradeId1);
        assertEq(att.verified, result);
    }

    function testFuzz_Pagination_OffsetAndLimit(uint256 offset, uint256 limit) public {
        // Create exactly 10 attestations
        for (uint256 i = 0; i < 10; i++) {
            bytes32 tid = keccak256(abi.encodePacked(i));
            _recordAttestation(tid, true, block.timestamp);
        }

        offset = bound(offset, 0, 20);
        limit = bound(limit, 0, 20);

        bytes32[] memory ids = registry.getAttestedTradeIds(offset, limit);

        if (offset >= 10) {
            assertEq(ids.length, 0);
        } else {
            uint256 expectedLength = offset + limit > 10 ? 10 - offset : limit;
            assertEq(ids.length, expectedLength);
        }
    }
}
