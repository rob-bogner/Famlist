/*
 HybridLogicalClockTests.swift
 FamlistTests
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for Hybrid Logical Clock implementation.
 
 🛠 Includes:
 - Monotonicity tests
 - Causal ordering tests
 - Clock synchronization tests
 - Comparison operator tests
 
 🔰 Notes for Beginners:
 - These tests validate core CRDT properties
 - HLC must maintain causal consistency even with clock drift
 
 📝 Last Change:
 - Initial test suite for CRDT foundation
 ------------------------------------------------------------------------
*/

import XCTest
@testable import Famlist

@MainActor
final class HybridLogicalClockTests: XCTestCase {
    
    func testClockTick_shouldBeMonotonic() {
        let generator = HybridLogicalClockGenerator(nodeId: "node1")
        
        let clock1 = generator.tick()
        let clock2 = generator.tick()
        let clock3 = generator.tick()
        
        XCTAssertTrue(clock1 < clock2)
        XCTAssertTrue(clock2 < clock3)
    }
    
    func testClockReceive_shouldAdvanceBeyondRemote() {
        let generator1 = HybridLogicalClockGenerator(nodeId: "node1")
        let generator2 = HybridLogicalClockGenerator(nodeId: "node2")
        
        let clock1 = generator1.tick()
        let clock2 = generator2.receive(clock1)
        
        XCTAssertTrue(clock1 < clock2)
    }
    
    func testClockComparison_withDifferentTimestamps() {
        let clock1 = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let clock2 = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        
        XCTAssertTrue(clock1 < clock2)
        XCTAssertFalse(clock2 < clock1)
    }
    
    func testClockComparison_withSameTimestampDifferentCounters() {
        let clock1 = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let clock2 = HybridLogicalClock(timestamp: 1000, counter: 1, nodeId: "node1")
        
        XCTAssertTrue(clock1 < clock2)
        XCTAssertFalse(clock2 < clock1)
    }
    
    func testClockComparison_withSameTimestampAndCounterDifferentNodes() {
        let clock1 = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let clock2 = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node2")
        
        // Should be deterministic based on nodeId
        XCTAssertTrue(clock1 < clock2)
        XCTAssertFalse(clock2 < clock1)
    }
    
    func testClockEquality() {
        let clock1 = HybridLogicalClock(timestamp: 1000, counter: 5, nodeId: "node1")
        let clock2 = HybridLogicalClock(timestamp: 1000, counter: 5, nodeId: "node1")
        
        XCTAssertEqual(clock1, clock2)
    }
    
    func testClockMax_shouldReturnLaterClock() {
        let clock1 = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let clock2 = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        
        let maxClock = HybridLogicalClock.max(clock1, clock2)
        XCTAssertEqual(maxClock, clock2)
    }
    
    func testClockGenerator_shouldHandleMultipleReceives() {
        let generator = HybridLogicalClockGenerator(nodeId: "node1")
        
        let remoteClock1 = HybridLogicalClock(timestamp: 5000, counter: 0, nodeId: "node2")
        let remoteClock2 = HybridLogicalClock(timestamp: 6000, counter: 0, nodeId: "node3")
        
        let clock1 = generator.receive(remoteClock1)
        let clock2 = generator.receive(remoteClock2)
        
        XCTAssertTrue(clock1 < clock2)
        XCTAssertTrue(remoteClock1 < clock1)
        XCTAssertTrue(remoteClock2 < clock2)
    }
    
    func testHappenedBefore() {
        let clock1 = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "node1")
        let clock2 = HybridLogicalClock(timestamp: 2000, counter: 0, nodeId: "node1")
        
        XCTAssertTrue(clock1.happenedBefore(clock2))
        XCTAssertFalse(clock2.happenedBefore(clock1))
    }
}

