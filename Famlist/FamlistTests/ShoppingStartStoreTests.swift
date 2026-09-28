/*
 ShoppingStartStoreTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für ShoppingStartStore (Einkaufsbeginn laut Liste). Anbindung an ListViewModel: ShoppingCompletionTests.

 🔰 Notes for Beginners:
 - Eigene UserDefaults-Suite; wird vor und nach jedem Test geleert.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ShoppingStartStoreTests: XCTestCase {
    private let suite = "ShoppingStartStoreTests"
    private var defaults: UserDefaults!
    private let listId = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    func test_firstCheck_remembersStart() {
        ShoppingStartStore.noteCheck(listId: listId, now: t0, defaults: defaults)
        XCTAssertEqual(ShoppingStartStore.start(listId: listId, defaults: defaults), t0)
    }

    func test_furtherChecksWithin4h_keepFirstStart() {
        ShoppingStartStore.noteCheck(listId: listId, now: t0, defaults: defaults)
        ShoppingStartStore.noteCheck(listId: listId, now: t0 + 1800, defaults: defaults)
        XCTAssertEqual(ShoppingStartStore.start(listId: listId, defaults: defaults), t0)
    }

    /// Ein nie abgeschlossener Einkauf von gestern zählt nicht als Beginn des heutigen.
    func test_staleStart_isReplaced() {
        ShoppingStartStore.noteCheck(listId: listId, now: t0, defaults: defaults)
        ShoppingStartStore.noteCheck(listId: listId, now: t0 + 5 * 3600, defaults: defaults)
        XCTAssertEqual(ShoppingStartStore.start(listId: listId, defaults: defaults), t0 + 5 * 3600)
    }

    func test_reset_clearsStart_perList() {
        let other = UUID()
        ShoppingStartStore.noteCheck(listId: listId, now: t0, defaults: defaults)
        ShoppingStartStore.noteCheck(listId: other, now: t0, defaults: defaults)
        ShoppingStartStore.reset(listId: listId, defaults: defaults)
        XCTAssertNil(ShoppingStartStore.start(listId: listId, defaults: defaults))
        XCTAssertEqual(ShoppingStartStore.start(listId: other, defaults: defaults), t0)
    }

    func test_plausibleStart() {
        XCTAssertEqual(ShoppingStartStore.plausibleStart(t0, end: t0 + 1380), t0)
        XCTAssertNil(ShoppingStartStore.plausibleStart(t0 + 60, end: t0), "Beginn nach dem Ende")
        XCTAssertNil(ShoppingStartStore.plausibleStart(t0, end: t0 + 4 * 3600 + 1), "länger als 4 Stunden")
        XCTAssertNil(ShoppingStartStore.plausibleStart(nil, end: t0))
        XCTAssertNil(ShoppingStartStore.plausibleStart(t0, end: nil))
    }
}
