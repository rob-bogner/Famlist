/*
 ListViewModelApplyItemsTests.swift
 FamlistTests
 Created on: 18.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression tests for the applyItems() position-stabilisation guard.
 - Covers the bug where pendingAnimatedItemIDs caused updated field values
   (e.g. units after duplicate-add merge) to be replaced with stale copies.

 📝 Last Change:
 - FAM-XX: Initial creation.
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

// MARK: - Tests

@MainActor
final class ListViewModelApplyItemsTests: XCTestCase {

    // MARK: - Setup

    private var container: ModelContainer!
    private var context: ModelContext!
    private var sut: ListViewModel!

    private let listId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    override func setUp() async throws {
        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        sut = ListViewModel(
            listId: listId,
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: context),
            listStore: SwiftDataListStore(context: context),
            startImmediately: false
        )
    }

    override func tearDown() async throws {
        sut = nil
        context = nil
        container = nil
    }

    // MARK: - Helpers

    private func makeItem(id: String = UUID().uuidString,
                          name: String,
                          units: Int = 1,
                          price: Double = 0,
                          listId: UUID? = nil) -> ItemModel {
        ItemModel(
            id: id,
            name: name,
            units: units,
            price: price,
            listId: (listId ?? self.listId).uuidString
        )
    }

    // MARK: - AC 1: Pending-Animation + Feldupdate → neue Werte sichtbar

    /// AC: Wenn pendingAnimatedItemIDs die ID eines Items enthält und applyItems()
    /// ein Item mit gleicher ID aber units=2 bekommt, muss self.items units=2 zeigen.
    func test_applyItems_pendingAnimation_updatesFieldValues() {
        // Given: item mit units=1 in self.items; ID in pendingAnimatedItemIDs
        let itemId = UUID().uuidString
        let staleItem = makeItem(id: itemId, name: "Milch", units: 1)
        sut.items = [staleItem]
        sut.pendingAnimatedItemIDs.insert(itemId)

        // When: neuer Snapshot mit units=2 eintrifft
        let updatedItem = makeItem(id: itemId, name: "Milch", units: 2)
        sut.applyItems([updatedItem])

        // Then: units=2 muss sichtbar sein
        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.units, 2,
                       "applyItems() darf units nicht auf den stale Wert zurücksetzen")
    }

    // MARK: - AC 2: Pending-Animation + Positionsstabilität

    /// AC: Wenn ein Item in pendingAnimatedItemIDs ist, muss applyItems() seine Position
    /// aus self.items beibehalten — auch wenn der Snapshot eine andere Reihenfolge hätte.
    func test_applyItems_pendingAnimation_preservesPosition() {
        // Given: [A, B, C] in self.items; B hat pending animation (Index 1)
        let idA = UUID().uuidString
        let idB = UUID().uuidString
        let idC = UUID().uuidString
        sut.items = [
            makeItem(id: idA, name: "A"),
            makeItem(id: idB, name: "B"),
            makeItem(id: idC, name: "C")
        ]
        sut.pendingAnimatedItemIDs.insert(idB)

        // When: Snapshot in anderer Reihenfolge [C, B, A]
        sut.applyItems([
            makeItem(id: idC, name: "C"),
            makeItem(id: idB, name: "B"),
            makeItem(id: idA, name: "A")
        ])

        // Then: B muss weiterhin an Position 1 stehen
        XCTAssertEqual(sut.items[1].id, idB,
                       "Position von B muss stabil bleiben trotz anderer Snapshot-Reihenfolge")
    }

    // MARK: - AC 3: Mehrere Feldänderungen gleichzeitig

    /// AC: Auch wenn units, price und name gleichzeitig im Snapshot geändert sind,
    /// müssen alle neuen Werte übernommen werden — nicht nur units.
    func test_applyItems_pendingAnimation_updatesMultipleFields() {
        // Given
        let itemId = UUID().uuidString
        sut.items = [makeItem(id: itemId, name: "Alt", units: 1, price: 0.0)]
        sut.pendingAnimatedItemIDs.insert(itemId)

        // When: Snapshot mit geänderten Feldern
        let updated = makeItem(id: itemId, name: "Neu", units: 5, price: 3.99)
        sut.applyItems([updated])

        // Then: alle Feldwerte aus dem Snapshot
        XCTAssertEqual(sut.items.first?.name, "Neu",  "name muss aktualisiert werden")
        XCTAssertEqual(sut.items.first?.units, 5,     "units muss aktualisiert werden")
        XCTAssertEqual(sut.items.first?.price ?? -1, 3.99, accuracy: 0.001,
                       "price muss aktualisiert werden")
    }

    // MARK: - AC 4: Kein pending animation state → unverändert korrekt

    /// AC: Wenn pendingAnimatedItemIDs leer ist, werden Items unverändert aus dem Snapshot übernommen.
    func test_applyItems_noPendingAnimation_passesSnapshotThrough() {
        // Given: kein pending state
        let itemId = UUID().uuidString
        sut.items = [makeItem(id: itemId, name: "Milch", units: 1)]
        // pendingAnimatedItemIDs bleibt leer

        // When
        sut.applyItems([makeItem(id: itemId, name: "Milch", units: 2)])

        // Then: units=2 direkt sichtbar
        XCTAssertEqual(sut.items.first?.units, 2,
                       "Ohne pending animation muss der Snapshot unverändert übernommen werden")
    }

    /// AC: Wenn das Item nicht in self.items existiert (neu), wird es einfach eingefügt.
    func test_applyItems_pendingAnimation_unknownId_itemInserted() {
        // Given: self.items leer; ID in pendingAnimatedItemIDs (Guard: guard let currentIndex → continue)
        let itemId = UUID().uuidString
        sut.items = []
        sut.pendingAnimatedItemIDs.insert(itemId)

        let newItem = makeItem(id: itemId, name: "Neu", units: 3)
        sut.applyItems([newItem])

        // Then: item wird trotzdem eingefügt (guard springt auf continue, kein Reinsert nötig)
        XCTAssertEqual(sut.items.first?.units, 3)
    }

    // MARK: - AC 5: Integrationstest Duplicate-Add

    /// AC: Nach Duplicate-Add muss units=2 sofort ohne Pull-to-Refresh sichtbar sein.
    /// Simuliert: storeLocally() schreibt units=2 in SwiftData → refreshItemsFromStore() →
    /// applyItems() mit pendingAnimatedItemIDs aktiv → units=2 in self.items.
    func test_duplicateAdd_unitsImmediatelyVisible() throws {
        // Given: "Milch" (units=1) in SwiftData und in self.items
        let store = SwiftDataItemStore(context: context)
        let itemId = UUID().uuidString
        let original = makeItem(id: itemId, name: "Milch", units: 1)
        let entity = try store.upsert(model: original)
        entity.setSyncStatus(.synced)
        try store.save()
        sut.refreshItemsFromStore()
        XCTAssertEqual(sut.items.first?.units, 1, "Precondition: units=1")

        // Simulates: duplicate-add animation started → ID in pendingAnimatedItemIDs
        sut.pendingAnimatedItemIDs.insert(itemId)

        // Simulates: storeLocally() writes units=2 to SwiftData (pendingUpdate)
        let incremented = makeItem(id: itemId, name: "Milch", units: 2)
        let updatedEntity = try store.upsert(model: incremented)
        updatedEntity.setSyncStatus(.pendingUpdate)
        try store.save()

        // Act: refreshItemsFromStore() (as called by storeLocally / SyncEngine)
        sut.refreshItemsFromStore()

        // Then: units=2 sichtbar, kein Pull-to-Refresh nötig
        XCTAssertEqual(sut.items.first?.units, 2,
                       "units=2 muss sofort nach Duplicate-Add sichtbar sein ohne Pull-to-Refresh")
    }
}
