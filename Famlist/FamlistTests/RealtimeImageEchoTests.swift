/*
 RealtimeImageEchoTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression: Ein Realtime-UPDATE ohne Feld `imagedata` (Postgres lässt große, unveränderte Werte weg)
   darf das lokale Foto nicht löschen. Ein ausdrückliches `null` löscht es.

 🔰 Notes for Beginners:
 - Gerätefehler 25.09.2026: Nach „Milch“ erneut hinzufügen verschwand das Foto, weil das Echo des
   Servers ohne `imagedata` ankam und die App das als „kein Foto“ übernahm.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class RealtimeImageEchoTests: XCTestCase {
    private var store: SwiftDataItemStore!
    private var sut: RealtimeEventProcessor!
    private let listId = UUID()
    private let itemId = UUID()

    override func setUp() async throws {
        let container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        store = SwiftDataItemStore(context: ModelContext(container))
        sut = RealtimeEventProcessor(conflictResolver: ConflictResolver(), itemStore: store)
        let entity = try store.upsert(model: ItemModel(id: itemId.uuidString, imageData: "FOTO", name: "Milch",
                                                       units: 4, measure: "pack", listId: listId.uuidString))
        entity.hlcTimestamp = 1_000
        entity.hlcCounter = 0
        entity.hlcNodeId = "node"
        entity.setSyncStatus(.synced)
        try store.save()
    }

    /// Echo wie im Gerätelog: Menge 5, neuere HLC, KEIN Feld „imagedata“.
    private func payload(imagedata: Any?? = .none) -> [String: Any] {
        var record: [String: Any] = [
            "id": itemId.uuidString.lowercased(), "list_id": listId.uuidString.lowercased(),
            "name": "Milch", "units": 5, "measure": "pack", "price": 1.19, "isChecked": false,
            "tombstone": false, "hlc_timestamp": Int64(2_000), "hlc_counter": 0, "hlc_node_id": "node"
        ]
        if case .some(let value) = imagedata { record["imagedata"] = value ?? NSNull() }
        return ["record": record]
    }

    func test_updateWithoutImageField_keepsLocalImage_andTakesUnits() async throws {
        await sut.processUpdate(payload(), listId: listId)
        let entity = try XCTUnwrap(store.fetchItem(id: itemId))
        XCTAssertEqual(entity.units, 5, "Menge vom Server übernommen")
        XCTAssertEqual(entity.imageData, "FOTO", "fehlendes Feld löscht das Foto nicht")
    }

    func test_updateWithExplicitNullImage_clearsImage() async throws {
        await sut.processUpdate(payload(imagedata: .some(nil)), listId: listId)
        let entity = try XCTUnwrap(store.fetchItem(id: itemId))
        XCTAssertNil(entity.imageData, "ausdrückliches null = Foto entfernt")
    }

    func test_updateWithNewImage_replacesImage() async throws {
        await sut.processUpdate(payload(imagedata: .some("NEU")), listId: listId)
        let entity = try XCTUnwrap(store.fetchItem(id: itemId))
        XCTAssertEqual(entity.imageData, "NEU")
    }
}
