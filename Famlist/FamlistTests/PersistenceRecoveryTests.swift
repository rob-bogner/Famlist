/*
 PersistenceRecoveryTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Beschädigte Datenbank: Sie wird beiseitegelegt, eine neue Datenbank auf dem Gerät entsteht, und
   danach Gespeichertes übersteht einen Neustart (vorher: stiller Rückfall auf den Arbeitsspeicher).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class PersistenceRecoveryTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func test_corruptStore_isMovedAside_andNewStorePersists() throws {
        let url = directory.appendingPathComponent("Default.store")
        try Data("keine SQLite-Datei".utf8).write(to: url)

        let first = PersistenceController(storeURL: url)
        let store = SwiftDataItemStore(context: first.container.mainContext)
        let listId = UUID()
        try store.upsert(model: ItemModel(name: "Milch", listId: listId.uuidString))
        try store.save()

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("Default.store.broken-") }
        XCTAssertFalse(backups.isEmpty, "Beschädigte Datei bleibt für die Fehlersuche erhalten")

        let reopened = PersistenceController(storeURL: url)
        let items = try SwiftDataItemStore(context: reopened.container.mainContext).fetchItems(listId: listId)
        XCTAssertEqual(items.map(\.name), ["Milch"], "Neue Datenbank liegt auf dem Gerät, nicht im Arbeitsspeicher")
    }

    func test_healthyStore_isNotMoved() throws {
        let url = directory.appendingPathComponent("Default.store")
        _ = PersistenceController(storeURL: url)
        _ = PersistenceController(storeURL: url)
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.contains(".broken-") }
        XCTAssertTrue(backups.isEmpty)
    }
}
