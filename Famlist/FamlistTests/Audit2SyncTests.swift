/*
 Audit2SyncTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sync-Befunde aus Audit-Runde 2: Abgleich nach langer Pause (endgültig gelöschte Artikel), Uhr in der
   Zukunft, Unicode-Normalisierung der Artikel-ID, Storage-Fehler, Foto-Vorlader, Abmelden mit
   ungesendeten Änderungen.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
import Supabase
@testable import Famlist

@MainActor
final class Audit2SyncTests: XCTestCase {
    private var container: ModelContainer!      // muss leben, solange der Test den Kontext nutzt
    private var store: SwiftDataItemStore!
    private var list: ListViewModel!
    private let listId = UUID()

    override func setUp() async throws {
        container = PersistenceController(inMemory: true).container
        store = SwiftDataItemStore(context: container.mainContext)
        list = ListViewModel(listId: listId, repository: PreviewItemsRepository(), itemStore: store,
                             listStore: SwiftDataListStore(context: container.mainContext), startImmediately: false)
    }

    override func tearDown() async throws {
        list = nil
        store = nil
        container = nil
    }

    private func add(_ name: String, status: ItemEntity.SyncStatus) throws -> UUID {
        let id = UUID()
        try store.writeLocal(ItemModel(id: id.uuidString, name: name, listId: listId.uuidString),
                             hlc: HybridLogicalClockGenerator(nodeId: "t").tick(), tombstone: false, modifiedBy: "t")
        try store.fetchItem(id: id)?.syncStatus = status
        try store.save()
        return id
    }

    // MARK: - S3 Abgleich nach langer Pause

    func test_reconcile_removesSyncedItemsMissingOnServer_keepsPendingOnes() throws {
        let kept = try add("Brot", status: .synced)
        let ghost = try add("Milch", status: .synced)          // auf dem Server endgültig gelöscht
        let unsent = try add("Eier", status: .pendingCreate)   // eigene, noch nicht gesendete Änderung

        let removed = try list.removeVanishedItems(listId: listId, serverIds: [kept.uuidString])

        XCTAssertEqual(removed, 1)
        XCTAssertNil(try store.fetchItem(id: ghost), "Geister-Artikel entfernt")
        XCTAssertNotNil(try store.fetchItem(id: kept))
        XCTAssertNotNil(try store.fetchItem(id: unsent), "Ungesendetes bleibt")
    }

    // MARK: - S6 Uhr in der Zukunft

    func test_hlc_storedStateFarInFuture_isDiscardedOnStart() throws {
        let suite = "Audit2SyncTests.hlc"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        defaults.set(NSNumber(value: now + 365 * 86_400_000), forKey: "famlist.hlc.lastTimestamp")   // +1 Jahr

        let next = HybridLogicalClockGenerator(nodeId: "n", defaults: defaults).tick()

        XCTAssertLessThan(next.timestamp, now + HybridLogicalClock.maxFutureDrift, "wieder echte Zeit")
    }

    func test_hlc_storedStateSlightlyAhead_isKept() throws {
        let suite = "Audit2SyncTests.hlc2"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let ahead = Int64(Date().timeIntervalSince1970 * 1000) + 60_000                                   // +1 Minute
        defaults.set(NSNumber(value: ahead), forKey: "famlist.hlc.lastTimestamp")

        let next = HybridLogicalClockGenerator(nodeId: "n", defaults: defaults).tick()

        XCTAssertGreaterThanOrEqual(next.timestamp, ahead, "monoton über Neustarts")
    }

    // MARK: - S14 Unicode

    func test_deterministicId_sameForComposedAndDecomposedName() {
        let composed = "M\u{00FC}sli"            // ü als ein Zeichen
        let decomposed = "Mu\u{0308}sli"         // u + Trema
        XCTAssertEqual(UUID.deterministicItemID(listId: listId, name: composed),
                       UUID.deterministicItemID(listId: listId, name: decomposed))
    }

    // MARK: - S11 Storage-Fehler

    func test_storageError_tooLarge_isPermanent_serverError_isTransient() {
        XCTAssertEqual(SyncErrorClassifier.classify(StorageError(statusCode: "413", message: "too large")), .permanent)
        XCTAssertEqual(SyncErrorClassifier.classify(StorageError(statusCode: "503", message: "busy")), .transient)
        XCTAssertEqual(SyncErrorClassifier.classify(StorageError(message: "ohne Status")), .transient)
    }

    // MARK: - S10 Foto-Vorlader

    func test_itemsMissingImage_skipsExcluded() throws {
        var ids: [UUID] = []
        for name in ["A", "B", "C"] {
            let id = try add(name, status: .synced)
            try store.fetchItem(id: id)?.imagePath = "\(listId)/\(name).jpg"
            ids.append(id)
        }
        try store.save()
        let next = try store.itemsMissingImage(limit: 2, excluding: [ids[0], ids[1]])
        XCTAssertEqual(next.map(\.id), [ids[2]], "nach Fehlschlägen kommen andere Artikel dran")
    }

    // MARK: - S4 Abmelden

    func test_unsentChangeCount_includesRegisteredCounters() {
        let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                          lists: PreviewListsRepository(), listViewModel: list)
        XCTAssertEqual(session.unsentChangeCount(), 0)
        session.countUnsentChanges { 2 }       // z. B. zwei ungesendete Preise
        XCTAssertEqual(session.unsentChangeCount(), 2)
    }
}
