/*
 WatchHybridLogicalClockTests.swift
 FamlistWatchTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Prüft, dass die geteilte HLC-Datei auf der Uhr läuft: eigene, dauerhafte Geräte-ID und
   streng wachsende Zeitstempel (Grundlage für LWW zwischen Uhr und iPhone).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import FamlistWatch

@MainActor
final class WatchHybridLogicalClockTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "WatchHybridLogicalClockTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_nodeId_isStableAcrossRestarts() {
        let first = HybridLogicalClockGenerator(defaults: defaults)
        let second = HybridLogicalClockGenerator(defaults: defaults)
        XCTAssertEqual(first.nodeId, second.nodeId)
    }

    func test_tick_isStrictlyIncreasing() {
        let generator = HybridLogicalClockGenerator(defaults: defaults)
        let a = generator.tick()
        let b = generator.tick()
        XCTAssertTrue(a < b)
    }

    func test_receive_isAfterRemoteClock() {
        let generator = HybridLogicalClockGenerator(defaults: defaults)
        let remote = HybridLogicalClock(timestamp: generator.tick().timestamp + 5_000, counter: 3, nodeId: "iphone")
        XCTAssertTrue(remote < generator.receive(remote))
    }
}
