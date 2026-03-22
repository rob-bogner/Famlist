/*
 BulkDeleteRemoteReceiverTests.swift
 FamlistTests

 Famlist
 Created on: 2026-03-21

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für das Remote-Receiver-Verhalten bei Bulk-Delete-Operationen.
 - Deckt die zwei identifizierten Bugs ab:
   Bug A: Sequentielle UI-Updates auf empfangendem Gerät (iPad) statt atomarem Zustandswechsel.
   Bug B: Ein Artikel bleibt nach Bulk-Delete übrig (verlorenes Realtime-Event).

 🛠 Includes:
 - Lifecycle-Tests für `reconciliationSyncTask`
 - Debounce-Semantik: mehrere rapidé Aufrufe → ein Task
 - Integration: Stream-Handler setzt reconciliation nach Remote-Deletion
 - Negative Fälle: kein reconciliation bei Hinzufügen / unverändertem Stand
 - Bulk-Delete-Guard-Invarianten (pendingBulkDeleteIDs, isBulkMutationActive)

 🔰 Notes for Beginners:
 - Alle Tests sind @MainActor für Thread-Sicherheit mit dem ViewModel.
 - `scheduleReconciliationSync()` ist `internal` → direkt aufrufbar via @testable import.
 - Die async-Integrationstests nutzen `Task.sleep` um Async-Scheduling abzuwarten.

 📝 Last Change:
 - Initial creation (BulkDelete Remote-Receiver Fix).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

// MARK: - Tests

@MainActor
final class BulkDeleteRemoteReceiverTests: XCTestCase {

    // MARK: - Setup

    private var container: ModelContainer!
    private var context: ModelContext!
    private var sut: ListViewModel!
    private let testListId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    override func setUp() async throws {
        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        sut = ListViewModel(
            listId: testListId,
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: context),
            listStore: SwiftDataListStore(context: context),
            startImmediately: false
        )
    }

    override func tearDown() async throws {
        sut.reconciliationSyncTask?.cancel()
        sut = nil
        context = nil
        container = nil
    }

    // MARK: - Helpers

    private func makeItem(id: String = UUID().uuidString, name: String) -> ItemModel {
        ItemModel(
            id: id,
            name: name,
            units: 1,
            measure: "Stück",
            listId: testListId.uuidString
        )
    }

    // MARK: - reconciliationSyncTask Lifecycle

    /// AC: `scheduleReconciliationSync()` erzeugt einen nicht-nil Task.
    func test_scheduleReconciliationSync_createsTask() {
        XCTAssertNil(sut.reconciliationSyncTask, "Vorbedingung: kein Task vorhanden")
        sut.scheduleReconciliationSync()
        XCTAssertNotNil(sut.reconciliationSyncTask)
    }

    /// AC: Zweiter Aufruf cancelt den ersten Task (Debounce-Semantik).
    func test_scheduleReconciliationSync_cancelsPreviousTask() {
        sut.scheduleReconciliationSync()
        let firstTask = sut.reconciliationSyncTask
        XCTAssertNotNil(firstTask)

        sut.scheduleReconciliationSync()

        XCTAssertTrue(firstTask?.isCancelled ?? false,
                      "Erster Task muss gecancelt sein, wenn ein neuer gestartet wird")
        XCTAssertNotNil(sut.reconciliationSyncTask, "Neuer Task muss vorhanden sein")
        // Task ist ein Struct (kein Referenztyp), daher kein === Vergleich möglich.
        // Korrektheit wird durch isCancelled des ersten Tasks geprüft.
        XCTAssertFalse(sut.reconciliationSyncTask?.isCancelled ?? true,
                       "Neuer Task darf nicht gecancelt sein")
    }

    /// AC: `clearForSignOut()` cancelt und entfernt den reconciliation Task.
    func test_clearForSignOut_cancelsReconciliationSyncTask() {
        sut.scheduleReconciliationSync()
        XCTAssertNotNil(sut.reconciliationSyncTask)

        sut.clearForSignOut()

        XCTAssertNil(sut.reconciliationSyncTask,
                     "clearForSignOut muss reconciliationSyncTask auf nil setzen")
    }

    /// AC: `switchList(to:)` cancelt den reconciliation Task und setzt ihn auf nil.
    func test_switchList_cancelsReconciliationSyncTask() {
        sut.scheduleReconciliationSync()
        let taskBeforeSwitch = sut.reconciliationSyncTask
        XCTAssertNotNil(taskBeforeSwitch)

        sut.switchList(to: UUID())

        XCTAssertNil(sut.reconciliationSyncTask,
                     "switchList muss reconciliationSyncTask auf nil setzen")
        XCTAssertTrue(taskBeforeSwitch?.isCancelled ?? false,
                      "Alter Task muss gecancelt sein")
    }

    // MARK: - Stream Handler Integration

    /// AC: Wenn der Stream weniger Items liefert als zuvor sichtbar (Remote-Deletion),
    /// wird `reconciliationSyncTask` gesetzt — Safety Net für verlorene Realtime-Events.
    func test_streamHandler_schedulesReconciliation_whenItemsRemovedViaStream() async throws {
        // Given: PreviewItemsRepository mit 3 Items befüllen
        let repo = PreviewItemsRepository()
        _ = try await repo.createItem(makeItem(id: "A", name: "Äpfel"))
        _ = try await repo.createItem(makeItem(id: "B", name: "Brot"))
        _ = try await repo.createItem(makeItem(id: "C", name: "Chips"))

        // ViewModel mit der kontrollierten Repo starten
        let vm = ListViewModel(
            listId: testListId,
            repository: repo,
            itemStore: SwiftDataItemStore(context: context),
            listStore: SwiftDataListStore(context: context),
            startImmediately: true  // startet Realtime-Beobachtung
        )
        defer { vm.reconciliationSyncTask?.cancel() }

        // Warte, bis der Stream-Handler den initialen Snapshot (3 Items) verarbeitet hat
        try await Task.sleep(nanoseconds: 100_000_000)  // 100 ms
        XCTAssertEqual(vm.items.count, 3, "Vorbedingung: 3 Items sichtbar")
        XCTAssertNil(vm.reconciliationSyncTask, "Kein reconciliation bei erstem Snapshot")

        // When: Remote-Delete von 1 Item (simuliert Realtime-Event vom anderen Gerät)
        try await repo.deleteItem(id: "A", listId: testListId)

        // Then: Stream-Handler erkennt Rückgang und setzt reconciliationSyncTask
        try await Task.sleep(nanoseconds: 100_000_000)  // 100 ms — Zeit für async stream handler
        XCTAssertEqual(vm.items.count, 2, "Nur 2 Items sollen noch sichtbar sein")
        XCTAssertNotNil(vm.reconciliationSyncTask,
                        "reconciliationSyncTask muss nach Remote-Deletion gesetzt sein (Safety Net für verlorene Events)")
    }

    /// AC: Bei Hinzufügen eines Remote-Items wird KEIN reconciliation geplant.
    func test_streamHandler_doesNotScheduleReconciliation_whenItemsAdded() async throws {
        let repo = PreviewItemsRepository()
        _ = try await repo.createItem(makeItem(id: "A", name: "Äpfel"))

        let vm = ListViewModel(
            listId: testListId,
            repository: repo,
            itemStore: SwiftDataItemStore(context: context),
            listStore: SwiftDataListStore(context: context),
            startImmediately: true
        )
        defer { vm.reconciliationSyncTask?.cancel() }

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.items.count, 1)
        XCTAssertNil(vm.reconciliationSyncTask)

        // Neues Item hinzufügen → kein reconciliation nötig
        _ = try await repo.createItem(makeItem(id: "B", name: "Bananen"))

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertNil(vm.reconciliationSyncTask,
                     "Bei Remote-Add darf kein reconciliation geplant werden")
    }

    /// AC: Bei gleichbleibendem Item-Count (Update statt Delete) kein reconciliation.
    func test_streamHandler_doesNotScheduleReconciliation_whenItemsUpdated() async throws {
        let repo = PreviewItemsRepository()
        _ = try await repo.createItem(makeItem(id: "A", name: "Äpfel"))
        _ = try await repo.createItem(makeItem(id: "B", name: "Brot"))

        let vm = ListViewModel(
            listId: testListId,
            repository: repo,
            itemStore: SwiftDataItemStore(context: context),
            listStore: SwiftDataListStore(context: context),
            startImmediately: true
        )
        defer { vm.reconciliationSyncTask?.cancel() }

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertNil(vm.reconciliationSyncTask)

        // Update statt Delete: Count unverändert
        var updated = makeItem(id: "A", name: "Äpfel Granny Smith")
        updated.units = 3
        try await repo.updateItem(updated)

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertNil(vm.reconciliationSyncTask,
                     "Bei Remote-Update ohne Löschung darf kein reconciliation geplant werden")
    }

    // MARK: - Bulk Delete Guard Invarianten (Sender-Seite)

    /// AC: Nach `deleteAllItems()` ist `isBulkMutationActive` false (Gate wieder offen).
    func test_deleteAll_isBulkMutationActiveIsFalseAfterCompletion() {
        addItem(name: "Milch")
        addItem(name: "Butter")
        sut.deleteAllItems()
        XCTAssertFalse(sut.isBulkMutationActive,
                       "isBulkMutationActive muss nach deleteAllItems() wieder false sein")
    }

    /// AC: `pendingBulkDeleteIDs` enthält vor dem Löschen alle Artikel-IDs.
    func test_deleteAll_pendingBulkDeleteIDsFilterOutDeletedItems() {
        let item = addItem(name: "Käse")
        // Nach deleteAllItems() müssen Items aus der UI-Liste gefiltert werden.
        // Wir prüfen, dass `items` nach dem Aufruf leer ist (pendingBulkDeleteIDs wirkt als Filter).
        sut.deleteAllItems()
        XCTAssertFalse(sut.items.contains(where: { $0.id == item.id }),
                       "Gelöschte Items dürfen nicht mehr in items erscheinen")
    }

    /// AC: Bulk-Delete bei 44 Items leert die Liste vollständig (Smoke-Test für große Listen).
    func test_deleteAll_44Items_listIsEmptyAfterwards() {
        for i in 1...44 {
            addItem(name: "Artikel\(i)")
        }
        XCTAssertEqual(sut.items.count, 44, "Vorbedingung: 44 Items vorhanden")
        sut.deleteAllItems()
        XCTAssertTrue(sut.items.isEmpty,
                      "Nach deleteAllItems() auf 44 Artikeln muss die Liste leer sein")
    }

    // MARK: - Private helpers

    @discardableResult
    private func addItem(name: String) -> ItemModel {
        let item = ItemModel(
            id: UUID().uuidString,
            name: name,
            units: 1,
            measure: "Stück",
            isChecked: false,
            listId: testListId.uuidString,
            ownerPublicId: "owner"
        )
        sut.storePendingChange(for: item, status: .pendingCreate)
        return item
    }
}
