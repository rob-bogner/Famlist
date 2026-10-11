/*
 ItemCreatedByTests.swift
 FamlistTests
 Created on: 11.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Geteilte Liste: „hinzugefügt von“ (items.created_by, Migration 037) kommt vom Server bis in die lokale
   Datenbank und bleibt bei späteren Änderungen erhalten.
 - Kommt ein Artikel zurück auf die Liste (gelöscht → wieder da, abgehakt → offen), gilt der Schreibende als
   derjenige, der ihn hinzugefügt hat (Migration 039). Lokal wird der bisherige Ersteller dann entfernt.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

final class ItemCreatedByTests: XCTestCase {
    func testDecodesCreatedBy() throws {
        let json = #"{"id":"6F1C2C1E-1B7B-4E5B-9B1A-0C7E2B2F3A10","name":"Äpfel","units":1,"measure":"kg","price":0,"isChecked":false,"created_by":"8b0e6a2c-5d1f-4c55-9e0a-1f2d3c4b5a69"}"#
        let item = try JSONDecoder().decode(ItemModel.self, from: Data(json.utf8))
        XCTAssertEqual(item.createdBy, "8b0e6a2c-5d1f-4c55-9e0a-1f2d3c4b5a69")
    }

    func testEntityKeepsCreatorWhenUpdateHasNone() {
        let listId = UUID().uuidString
        let creator = UUID().uuidString.lowercased()
        let entity = ItemEntity.make(from: ItemModel(name: "Äpfel", listId: listId, createdBy: creator))
        XCTAssertEqual(entity.toItemModel().createdBy, creator)
        // Lokale Änderung ohne created_by darf den Ersteller nicht löschen.
        entity.assignContent(from: ItemModel(name: "Äpfel rot", listId: listId))
        XCTAssertEqual(entity.createdBy, creator)
        XCTAssertEqual(entity.name, "Äpfel rot")
    }

    // MARK: - Eigene Änderung (SwiftDataItemStore.writeLocal)

    /// Artikel eines anderen Mitglieds im Speicher; `change` ist die eigene Änderung daran.
    @MainActor
    private func creatorAfterLocalWrite(seed: ItemModel, seedTombstone: Bool = false,
                                        change: (inout ItemModel) -> Void, tombstone: Bool = false) throws -> String? {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let store = SwiftDataItemStore(context: container.mainContext)
        let clock = HybridLogicalClockGenerator(nodeId: "t")
        let entity = ItemEntity.make(from: seed)
        entity.setTombstone(seedTombstone)
        container.mainContext.insert(entity)
        var edited = entity.toItemModel()
        change(&edited)
        return try store.writeLocal(edited, hlc: clock.tick(), tombstone: tombstone, modifiedBy: "t").createdBy
    }

    private func item(checked: Bool = false, creator: String) -> ItemModel {
        ItemModel(name: "Sahne", isChecked: checked, listId: UUID().uuidString, createdBy: creator)
    }

    @MainActor
    func testUncheckingRemovesPreviousCreator() throws {
        let other = UUID().uuidString.lowercased()
        XCTAssertNil(try creatorAfterLocalWrite(seed: item(checked: true, creator: other)) { $0.isChecked = false })
    }

    @MainActor
    func testReAddingDeletedItemRemovesPreviousCreator() throws {
        let other = UUID().uuidString.lowercased()
        XCTAssertNil(try creatorAfterLocalWrite(seed: item(creator: other), seedTombstone: true) { $0.units = 2 })
    }

    @MainActor
    func testOtherLocalChangesKeepCreator() throws {
        let other = UUID().uuidString.lowercased()
        XCTAssertEqual(try creatorAfterLocalWrite(seed: item(creator: other)) { $0.units = 3 }, other, "Menge ändern")
        XCTAssertEqual(try creatorAfterLocalWrite(seed: item(creator: other)) { $0.isChecked = true }, other, "abhaken")
        XCTAssertEqual(try creatorAfterLocalWrite(seed: item(creator: other), change: { _ in }, tombstone: true), other,
                       "löschen")
    }

    /// Ein anderes Mitglied bringt den Artikel zurück: Der Server liefert den neuen Wert, lokal wird er übernommen.
    func testRemoteReturnReplacesCreator() {
        let listId = UUID().uuidString
        let first = UUID().uuidString.lowercased(), second = UUID().uuidString.lowercased()
        let entity = ItemEntity.make(from: ItemModel(name: "Sahne", isChecked: true, listId: listId, createdBy: first))
        entity.apply(model: ItemModel(name: "Sahne", isChecked: false, listId: listId, createdBy: second))
        XCTAssertEqual(entity.createdBy, second)
    }
}
