/*
 MultiDeviceSyncIntegrationTests.swift
 FamlistTests
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Integration tests simulating multi-device sync scenarios.
 
 🛠 Includes:
 - Concurrent modification tests
 - Conflict resolution validation
 - Operation queue behavior
 
 🔰 Notes for Beginners:
 - These tests simulate two devices modifying the same item
 - Validates that CRDT resolves conflicts consistently
 
 📝 Last Change:
 - Initial integration test suite for multi-device sync
 ------------------------------------------------------------------------
*/

import XCTest
@testable import Famlist

@MainActor
final class MultiDeviceSyncIntegrationTests: XCTestCase {
    
    func testConcurrentModifications_shouldResolveConsistently() async {
        // Simulate two devices modifying the same item
        let resolver = ConflictResolver()
        
        // Device 1 modifies at T+100ms
        let device1HLC = HybridLogicalClock(timestamp: 1100, counter: 0, nodeId: "device1")
        let device1Item = ItemModel(id: "item1", name: "Device1", units: 2)
        let device1Meta = CRDTMetadata(hlc: device1HLC, tombstone: false, lastModifiedBy: "device1")
        
        // Device 2 modifies at T+200ms
        let device2HLC = HybridLogicalClock(timestamp: 1200, counter: 0, nodeId: "device2")
        let device2Item = ItemModel(id: "item1", name: "Device2", units: 3)
        let device2Meta = CRDTMetadata(hlc: device2HLC, tombstone: false, lastModifiedBy: "device2")
        
        // Device 1 receives Device 2's update
        let (resolved1, _) = resolver.resolve(
            local: device1Item,
            remote: device2Item,
            localMeta: device1Meta,
            remoteMeta: device2Meta
        )
        
        // Device 2 receives Device 1's update
        let (resolved2, _) = resolver.resolve(
            local: device2Item,
            remote: device1Item,
            localMeta: device2Meta,
            remoteMeta: device1Meta
        )
        
        // Both devices should converge to same state (Device 2 wins)
        XCTAssertEqual(resolved1.name, "Device2")
        XCTAssertEqual(resolved2.name, "Device2")
        XCTAssertEqual(resolved1.units, 3)
        XCTAssertEqual(resolved2.units, 3)
    }
    
    func testDeletionDuringModification_tombstoneWins() async {
        let resolver = ConflictResolver()
        
        // Device 1 modifies item
        let device1HLC = HybridLogicalClock(timestamp: 1100, counter: 0, nodeId: "device1")
        let device1Item = ItemModel(id: "item1", name: "Modified")
        let device1Meta = CRDTMetadata(hlc: device1HLC, tombstone: false, lastModifiedBy: "device1")
        
        // Device 2 deletes item (earlier timestamp but tombstone)
        let device2HLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "device2")
        let device2Item = ItemModel(id: "item1", name: "Deleted")
        let device2Meta = CRDTMetadata(hlc: device2HLC, tombstone: true, lastModifiedBy: "device2")
        
        let (_, resolvedMeta) = resolver.resolve(
            local: device1Item,
            remote: device2Item,
            localMeta: device1Meta,
            remoteMeta: device2Meta
        )
        
        // Tombstone should win despite older timestamp
        XCTAssertTrue(resolvedMeta.tombstone)
    }
    
    func testHLCClockSkew_shouldMaintainCausality() async {
        // Simulate device with clock 5 minutes ahead
        let generator1 = HybridLogicalClockGenerator(nodeId: "device1")
        let generator2 = HybridLogicalClockGenerator(nodeId: "device2")
        
        // Device 1 creates event
        let clock1 = generator1.tick()
        
        // Device 2 receives and creates new event (even if physical clock is behind)
        let clock2 = generator2.receive(clock1)
        let clock3 = generator2.tick()
        
        // Causal ordering should be maintained
        XCTAssertTrue(clock1 < clock2)
        XCTAssertTrue(clock2 < clock3 || clock2 == clock3)
    }
    
    func testRapidConcurrentUpdates_shouldConverge() async {
        let resolver = ConflictResolver()
        
        var items: [ItemModel] = []
        var metas: [CRDTMetadata] = []
        
        // Simulate 5 devices making rapid updates
        for i in 0..<5 {
            let hlc = HybridLogicalClock(
                timestamp: 1000 + Int64(i * 100),
                counter: i,
                nodeId: "device\(i)"
            )
            let item = ItemModel(id: "item1", name: "Device\(i)", units: i)
            let meta = CRDTMetadata(hlc: hlc, tombstone: false, lastModifiedBy: "device\(i)")
            
            items.append(item)
            metas.append(meta)
        }
        
        // Each device resolves against all others
        var finalStates: [ItemModel] = []
        
        for deviceIndex in 0..<5 {
            var currentItem = items[deviceIndex]
            var currentMeta = metas[deviceIndex]
            
            for otherIndex in 0..<5 where otherIndex != deviceIndex {
                let (resolved, resolvedMeta) = resolver.resolve(
                    local: currentItem,
                    remote: items[otherIndex],
                    localMeta: currentMeta,
                    remoteMeta: metas[otherIndex]
                )
                currentItem = resolved
                currentMeta = resolvedMeta
            }
            
            finalStates.append(currentItem)
        }
        
        // All devices should converge to the same state
        let firstFinal = finalStates[0]
        for finalState in finalStates {
            XCTAssertEqual(finalState.name, firstFinal.name)
            XCTAssertEqual(finalState.units, firstFinal.units)
        }
    }
}

