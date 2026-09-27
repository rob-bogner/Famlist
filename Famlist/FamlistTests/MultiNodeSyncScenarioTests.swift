/*
 MultiNodeSyncScenarioTests.swift
 FamlistTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sync-Szenarien Uhr ↔ iPhone (Watch-Plan §7): zwei SyncEngines mit VERSCHIEDENEN HLC-Geräte-IDs teilen
   einen Test-Server, der wie die RPC upsert_items_lww entscheidet (neuere HLC gewinnt).
   (1) Uhr offline, 3 Änderungen; wieder online kommen alle an, das iPhone sieht sie nach der Delta-Abfrage.
   (2) iPhone ändert, während die Uhr offline ist; die Uhr übernimmt fremde Änderungen, ihre eigene
       NEUERE ungesendete Änderung bleibt stehen und gewinnt.
   (3) Beide ändern denselben Artikel gleichzeitig; beide landen beim selben Endstand (höhere HLC).

 🔰 Notes for Beginners:
 - Zwischen zwei Änderungen liegen einige Millisekunden, damit die HLC-Reihenfolge der Wanduhr folgt.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftData
import XCTest
@testable import Famlist

/// Server wie upsert_items_lww: schreibt nur neuere HLC, vergibt updated_at, liefert Deltas.
@MainActor
private final class LWWServer: ItemsRepository {
    private(set) var rows: [String: ItemModel] = [:]
    private var clock = Date(timeIntervalSince1970: 1_800_000_000)

    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] {
        requests.map { request in
            var item = request.item
            if let existing = rows[item.id], !(existing.hlc < item.hlc) {
                return ItemUpsertResult(id: item.id, status: .stale, item: existing, message: nil)
            }
            clock = clock.addingTimeInterval(0.001)
            item.updatedAt = clock
            rows[item.id] = item
            return ItemUpsertResult(id: item.id, status: .applied, item: item, message: nil)
        }
    }

    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        rows.values.filter { $0.listId == listId.uuidString && ($0.updatedAt ?? .distantPast) > since }
    }

    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { AsyncStream { _ in } }
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] { [] }
}

/// Netz an/aus für ein Gerät.
@MainActor
private final class Link {
    var online = true
}

/// Ein Gerät: eigener Speicher, eigene Warteschlange, eigene HLC-Geräte-ID.
@MainActor
private final class Node {
    let store: SwiftDataItemStore
    let queue: SyncOperationQueue
    let engine: SyncEngine
    let link = Link()
    private let server: LWWServer
    private var mark = Date.distantPast

    init(server: LWWServer, nodeId: String) throws {
        let container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        self.server = server
        store = SwiftDataItemStore(context: context)
        queue = SyncOperationQueue(context: context)
        let link = self.link
        engine = SyncEngine(repository: server, itemStore: store, operationQueue: queue,
                            hlcGenerator: HybridLogicalClockGenerator(nodeId: nodeId), isOnline: { link.online })
    }

    /// Delta-Abfrage wie auf beiden Geräten: nur per HLC übernehmen.
    func pull(_ listId: UUID) async throws {
        let rows = try await server.fetchItemsSince(listId: listId, since: mark)
        for row in rows { _ = try store.mergeRemote(row, legacyImageKnown: false) }
        try store.save()
        mark = rows.compactMap(\.updatedAt).max().map { max($0, mark) } ?? mark
    }

    func model(_ id: String) throws -> ItemModel? {
        try UUID(uuidString: id).flatMap { try store.fetchItem(id: $0)?.toItemModel() }
    }
}

@MainActor
final class MultiNodeSyncScenarioTests: XCTestCase {
    private let listId = UUID()
    private var server: LWWServer!
    private var phone: Node!
    private var watch: Node!

    override func setUp() async throws {
        server = LWWServer()
        phone = try Node(server: server, nodeId: "phone-\(UUID().uuidString.prefix(4))")
        watch = try Node(server: server, nodeId: "watch-\(UUID().uuidString.prefix(4))")
    }

    private func tick() async throws { try await Task.sleep(nanoseconds: 5_000_000) }

    private func newItem(_ name: String, units: Double = 1) -> ItemModel {
        ItemModel(name: name, units: units, measure: "", listId: listId.uuidString)
    }

    /// Legt einen Artikel auf dem iPhone an, sendet ihn und lässt die Uhr ihn abholen.
    private func sharedItem(_ name: String) async throws -> ItemModel {
        await phone.engine.createItem(newItem(name))
        try await watch.pull(listId)
        return try XCTUnwrap(server.rows.values.first { $0.name == name })
    }

    func test_watchOffline_threeChanges_arriveAfterReconnect_andReachPhone() async throws {
        watch.link.online = false
        for name in ["Milch", "Brot", "Eier"] {
            await watch.engine.createItem(newItem(name))
            try await tick()
        }
        XCTAssertEqual(watch.queue.count, 3, "offline: alle drei warten")
        XCTAssertTrue(server.rows.isEmpty)

        watch.link.online = true
        await watch.engine.resumeSync()
        XCTAssertEqual(watch.queue.count, 0)
        XCTAssertEqual(Set(server.rows.values.map(\.name)), ["Milch", "Brot", "Eier"])

        try await phone.pull(listId)
        XCTAssertEqual(Set(try phone.store.fetchItems(listId: listId).map(\.name)), ["Milch", "Brot", "Eier"])
    }

    func test_phoneChangesWhileWatchOffline_watchTakesThem_butItsNewerUnsentChangeWins() async throws {
        let milk = try await sharedItem("Milch")
        let bread = try await sharedItem("Brot")
        watch.link.online = false

        var phoneMilk = try XCTUnwrap(try phone.model(milk.id)); phoneMilk.units = 5
        await phone.engine.updateItem(phoneMilk)                      // iPhone: Milch 5 (gesendet)
        var phoneBread = try XCTUnwrap(try phone.model(bread.id)); phoneBread.units = 2
        await phone.engine.updateItem(phoneBread)                     // iPhone: Brot 2 (nur iPhone ändert)
        try await tick()
        var watchMilk = try XCTUnwrap(try watch.model(milk.id)); watchMilk.units = 9
        await watch.engine.updateItem(watchMilk)                      // Uhr: Milch 9, NEUER, offline
        XCTAssertEqual(watch.queue.count, 1)

        watch.link.online = true
        try await watch.pull(listId)                                  // erst abholen, dann senden
        XCTAssertEqual(try watch.model(bread.id)?.units, 2, "fremde Änderung übernommen")
        XCTAssertEqual(try watch.model(milk.id)?.units, 9, "eigene neuere ungesendete Änderung bleibt")
        await watch.engine.resumeSync()
        try await phone.pull(listId)

        XCTAssertEqual(server.rows[milk.id]?.units, 9, "neuere HLC gewinnt auf dem Server")
        XCTAssertEqual(try phone.model(milk.id)?.units, 9, "iPhone sieht den Stand der Uhr")
    }

    func test_concurrentChangeOfSameItem_bothConvergeToHigherHLC() async throws {
        let milk = try await sharedItem("Milch")
        phone.link.online = false
        watch.link.online = false

        var onPhone = try XCTUnwrap(try phone.model(milk.id)); onPhone.units = 2
        await phone.engine.updateItem(onPhone)
        try await tick()
        var onWatch = try XCTUnwrap(try watch.model(milk.id)); onWatch.isChecked = true; onWatch.units = 3
        await watch.engine.updateItem(onWatch)

        // Die Uhr sendet zuerst, das iPhone danach – Reihenfolge des Eintreffens darf nichts entscheiden.
        watch.link.online = true
        await watch.engine.resumeSync()
        phone.link.online = true
        await phone.engine.resumeSync()
        try await phone.pull(listId)
        try await watch.pull(listId)

        let winner = try XCTUnwrap(server.rows[milk.id])
        XCTAssertEqual(winner.units, 3, "höhere HLC (Uhr, später geändert) gewinnt")
        XCTAssertTrue(winner.isChecked)
        for node in [phone!, watch!] {
            let local = try XCTUnwrap(try node.model(milk.id))
            XCTAssertEqual(local.units, winner.units)
            XCTAssertEqual(local.isChecked, winner.isChecked)
            XCTAssertEqual(local.hlc, winner.hlc, "beide Geräte beim selben Endstand")
        }
    }
}
