/*
 ConflictResolverTests.swift
 FamlistTests
 Created on: 22.11.2025
 Last updated on: 22.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for CRDT conflict resolution logic.

 🛠 Includes:
 - Last-Write-Wins tests via shouldApplyRemote()
 - Tombstone priority tests
 - Concurrent modification tests

 🔰 Notes for Beginners:
 - Tests ensure consistent conflict resolution across devices
 - Tombstones must always win to ensure deletions propagate

 📝 Last Change:
 - Migrated all tests from removed resolve() to shouldApplyRemote()
 ------------------------------------------------------------------------
*/

import XCTest
@testable import Famlist

@MainActor
final class ConflictResolverTests: XCTestCase {

    var resolver: ConflictResolver!

    override func setUp() async throws {
        resolver = ConflictResolver()
    }

    func testShouldApplyRemote_newerRemoteWins() {
        let localHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")

        XCTAssertTrue(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    func testShouldApplyRemote_newerLocalWins() {
        let localHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")

        XCTAssertFalse(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    func testShouldApplyRemote_remoteTombstoneAlwaysWins() {
        let localHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: true, lastModifiedBy: "node2")

        XCTAssertTrue(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    func testShouldApplyRemote_localTombstoneWins() {
        let localHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")

        XCTAssertFalse(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    func testShouldApplyRemote_olderRemote() {
        let localHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")

        XCTAssertFalse(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    // FAM-68: Regression test for tombstone-protection bug.
    func testShouldApplyRemote_localTombstoneProtectedAgainstNewerRemote() {
        let localHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")

        XCTAssertFalse(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    // FAM-68: Both sides tombstoned — causally later tombstone wins.
    func testShouldApplyRemote_bothTombstones_newerLocalWins() {
        let localHLC  = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")

        let localMeta  = CRDTMetadata(hlc: localHLC,  tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: true, lastModifiedBy: "node2")

        XCTAssertFalse(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    func testShouldApplyRemote_bothTombstones_newerRemoteWins() {
        let localHLC  = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")

        let localMeta  = CRDTMetadata(hlc: localHLC,  tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: true, lastModifiedBy: "node2")

        XCTAssertTrue(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }
}
