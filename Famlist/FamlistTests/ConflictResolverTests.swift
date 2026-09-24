/*
 ConflictResolverTests.swift
 FamlistTests
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for CRDT conflict resolution logic.
 
 🛠 Includes:
 - Last-Write-Wins tests
 - Tombstone priority tests
 - Concurrent modification tests
 
 🔰 Notes for Beginners:
 - Tests ensure consistent conflict resolution across devices
 - Tombstones must always win to ensure deletions propagate
 
 📝 Last Change:
 - FAM-68: Added testShouldApplyRemote_localTombstoneProtected (was a bug)
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
    
    func testResolve_newerRemoteWins() {
        let localHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")
        
        let localItem = ItemModel(id: "item1", name: "Local Name")
        let remoteItem = ItemModel(id: "item1", name: "Remote Name")
        
        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")
        
        let (resolved, _) = resolver.resolve(
            local: localItem,
            remote: remoteItem,
            localMeta: localMeta,
            remoteMeta: remoteMeta
        )
        
        XCTAssertEqual(resolved.name, "Remote Name")
    }
    
    func testResolve_newerLocalWins() {
        let localHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")
        
        let localItem = ItemModel(id: "item1", name: "Local Name")
        let remoteItem = ItemModel(id: "item1", name: "Remote Name")
        
        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")
        
        let (resolved, _) = resolver.resolve(
            local: localItem,
            remote: remoteItem,
            localMeta: localMeta,
            remoteMeta: remoteMeta
        )
        
        XCTAssertEqual(resolved.name, "Local Name")
    }
    
    func testResolve_tombstoneAlwaysWins() {
        let localHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")
        
        let localItem = ItemModel(id: "item1", name: "Local Name")
        let remoteItem = ItemModel(id: "item1", name: "Remote Name")
        
        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: true, lastModifiedBy: "node2")
        
        let (_, resolvedMeta) = resolver.resolve(
            local: localItem,
            remote: remoteItem,
            localMeta: localMeta,
            remoteMeta: remoteMeta
        )
        
        XCTAssertTrue(resolvedMeta.tombstone)
    }
    
    func testResolve_localTombstoneWins() {
        let localHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")
        
        let localItem = ItemModel(id: "item1", name: "Local Name")
        let remoteItem = ItemModel(id: "item1", name: "Remote Name")
        
        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")
        
        let (_, resolvedMeta) = resolver.resolve(
            local: localItem,
            remote: remoteItem,
            localMeta: localMeta,
            remoteMeta: remoteMeta
        )
        
        XCTAssertTrue(resolvedMeta.tombstone)
    }
    
    func testShouldApplyRemote_newerRemote() {
        let localHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")
        
        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")
        
        XCTAssertTrue(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }
    
    func testShouldApplyRemote_olderRemote() {
        let localHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")
        
        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")
        
        XCTAssertFalse(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }
    
    func testShouldApplyRemote_tombstoneAlwaysApplies() {
        let localHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: false, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: true, lastModifiedBy: "node2")

        XCTAssertTrue(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    // FAM-68: Regression test for tombstone-protection bug.
    // Old shouldApplyRemote() would return true here (remote wins via HLC),
    // incorrectly un-deleting an item that was locally tombstoned.
    func testShouldApplyRemote_localTombstoneProtectedAgainstNewerRemote() {
        let localHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")

        let localMeta = CRDTMetadata(hlc: localHLC, tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: false, lastModifiedBy: "node2")

        XCTAssertFalse(resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta))
    }

    // FAM-68: Both sides tombstoned — causally later tombstone wins.
    func testResolve_bothTombstones_newerLocalWins() {
        let localHLC  = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")

        let localItem  = ItemModel(id: "item1", name: "Local Deleted")
        let remoteItem = ItemModel(id: "item1", name: "Remote Deleted")

        let localMeta  = CRDTMetadata(hlc: localHLC,  tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: true, lastModifiedBy: "node2")

        let (winning, winningMeta) = resolver.resolve(
            local: localItem, remote: remoteItem,
            localMeta: localMeta, remoteMeta: remoteMeta
        )
        XCTAssertTrue(winningMeta.tombstone)
        XCTAssertEqual(winning.name, "Local Deleted")
    }

    func testResolve_bothTombstones_newerRemoteWins() {
        let localHLC  = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let remoteHLC = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node2")

        let localItem  = ItemModel(id: "item1", name: "Local Deleted")
        let remoteItem = ItemModel(id: "item1", name: "Remote Deleted")

        let localMeta  = CRDTMetadata(hlc: localHLC,  tombstone: true, lastModifiedBy: "node1")
        let remoteMeta = CRDTMetadata(hlc: remoteHLC, tombstone: true, lastModifiedBy: "node2")

        let (winning, winningMeta) = resolver.resolve(
            local: localItem, remote: remoteItem,
            localMeta: localMeta, remoteMeta: remoteMeta
        )
        XCTAssertTrue(winningMeta.tombstone)
        XCTAssertEqual(winning.name, "Remote Deleted")
    }

    // FAM-68: Architectural proof — resolve() and shouldApplyRemote() must always agree.
    // Verifies the single merge decision point (winner()) is used by both public methods.
    func testResolveAndShouldApplyRemote_consistency_remoteNewer() {
        let localMeta  = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "n1"), tombstone: false, lastModifiedBy: "n1")
        let remoteMeta = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "n2"), tombstone: false, lastModifiedBy: "n2")
        let local  = ItemModel(id: "i1", name: "Local")
        let remote = ItemModel(id: "i1", name: "Remote")

        let (_, winningMeta) = resolver.resolve(local: local, remote: remote, localMeta: localMeta, remoteMeta: remoteMeta)
        let shouldApply = resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta)

        XCTAssertEqual(winningMeta == remoteMeta, shouldApply, "resolve() and shouldApplyRemote() must agree")
    }

    func testResolveAndShouldApplyRemote_consistency_localNewer() {
        let localMeta  = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "n1"), tombstone: false, lastModifiedBy: "n1")
        let remoteMeta = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "n2"), tombstone: false, lastModifiedBy: "n2")
        let local  = ItemModel(id: "i1", name: "Local")
        let remote = ItemModel(id: "i1", name: "Remote")

        let (_, winningMeta) = resolver.resolve(local: local, remote: remote, localMeta: localMeta, remoteMeta: remoteMeta)
        let shouldApply = resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta)

        XCTAssertEqual(winningMeta == remoteMeta, shouldApply, "resolve() and shouldApplyRemote() must agree")
    }

    func testResolveAndShouldApplyRemote_consistency_localTombstone() {
        let localMeta  = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "n1"), tombstone: true,  lastModifiedBy: "n1")
        let remoteMeta = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "n2"), tombstone: false, lastModifiedBy: "n2")
        let local  = ItemModel(id: "i1", name: "Local")
        let remote = ItemModel(id: "i1", name: "Remote")

        let (_, winningMeta) = resolver.resolve(local: local, remote: remote, localMeta: localMeta, remoteMeta: remoteMeta)
        let shouldApply = resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta)

        XCTAssertEqual(winningMeta == remoteMeta, shouldApply, "resolve() and shouldApplyRemote() must agree")
        XCTAssertFalse(shouldApply, "local tombstone must be protected")
    }

    func testResolveAndShouldApplyRemote_consistency_remoteTombstone() {
        let localMeta  = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "n1"), tombstone: false, lastModifiedBy: "n1")
        let remoteMeta = CRDTMetadata(hlc: HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "n2"), tombstone: true,  lastModifiedBy: "n2")
        let local  = ItemModel(id: "i1", name: "Local")
        let remote = ItemModel(id: "i1", name: "Remote")

        let (_, winningMeta) = resolver.resolve(local: local, remote: remote, localMeta: localMeta, remoteMeta: remoteMeta)
        let shouldApply = resolver.shouldApplyRemote(localMeta: localMeta, remoteMeta: remoteMeta)

        XCTAssertEqual(winningMeta == remoteMeta, shouldApply, "resolve() and shouldApplyRemote() must agree")
        XCTAssertTrue(shouldApply, "remote tombstone must always apply")
    }
}

