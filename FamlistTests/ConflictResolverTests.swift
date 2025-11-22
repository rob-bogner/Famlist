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
 - Initial test suite for CRDT conflict resolution
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
}

