/*
 WatchListViewModelTests.swift
 FamlistWatchTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Uhr-ViewModel mit echtem Speicher und echter SyncEngine (ohne Sitzung → Aufträge bleiben in der
   Warteschlange und lassen sich zählen):
   aktive Liste, Reihenfolge und Status der Listen, Abhaken + Haptik, Hinzufügen (Menge +1, wieder öffnen,
   neu mit Vorlage aus dem Artikelstamm, Zählen), alle abhaken / zurücksetzen, Menge 0,01…9999 mit Kommazahlen, Abschnitte.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 5).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import FamlistWatch

@MainActor
final class WatchListViewModelTests: XCTestCase {
    private var sync: WatchSyncCoordinator!
    private var defaults: UserDefaults!
    private var directory: URL!
    private let listA = UUID(), listB = UUID(), listC = UUID()

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "WatchListViewModelTests.\(UUID().uuidString)")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let catalog = OfflineItemCatalogRepository(remote: PreviewItemCatalogRepository(),
                                                   store: CatalogLocalStore(directory: directory))
        sync = WatchSyncCoordinator(container: PersistenceController(inMemory: true).container,
                                    itemsRepository: PreviewItemsRepository(), remote: nil, catalog: catalog,
                                    transport: nil, hlcGenerator: HybridLogicalClockGenerator(nodeId: "watch-vm"),
                                    defaults: defaults, userId: { nil })
        try addList(listA, "Wocheneinkauf", isDefault: true)
        try addList(listB, "Drogerie")
        try addList(listC, "Baumarkt")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func addList(_ id: UUID, _ title: String, isDefault: Bool = false) throws {
        try sync.listStore.upsert(model: ListModel(id: id, ownerId: UUID(), title: title, isDefault: isDefault,
                                                    createdAt: Date(), updatedAt: Date()))
    }

    @discardableResult
    private func addItem(_ list: UUID, _ name: String, units: Double = 1, checked: Bool = false,
                         category: String? = nil, measure: String = "") throws -> ItemModel {
        let model = ItemModel(id: UUID().uuidString, name: name, units: units, measure: measure, isChecked: checked,
                              category: category, listId: list.uuidString, hlcTimestamp: 1_000, hlcCounter: 0,
                              hlcNodeId: "phone")
        _ = try sync.itemStore.mergeRemote(model)
        try sync.itemStore.save()
        return model
    }

    private func makeSUT() -> WatchListViewModel {
        WatchListViewModel(sync: sync, defaults: defaults)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<300 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    // MARK: - Listen

    func test_activeList_favoriteBeatsDefault_selectionBeatsBoth() {
        sync.favoriteListId = listB
        let sut = makeSUT()
        XCTAssertEqual(sut.activeListId, listB, "erster Start: Favorit")
        sut.select(listC)
        XCTAssertEqual(sut.activeListId, listC)
        XCTAssertEqual(makeSUT().activeListId, listC, "gemerkt (je Gerät)")
    }

    func test_activeList_withoutFavorite_isDefaultList() {
        XCTAssertEqual(makeSUT().activeListId, listA)
    }

    func test_lists_favoriteFirst_thenAlphabetical_withStatus() throws {
        sync.favoriteListId = listC
        try addItem(listA, "Milch")
        try addItem(listA, "Brot", checked: true)
        try addItem(listB, "Seife", checked: true)
        let sut = makeSUT()
        XCTAssertEqual(sut.lists.map(\.name), ["Baumarkt", "Drogerie", "Wocheneinkauf"])
        XCTAssertEqual(sut.lists.map(\.status), ["Keine Artikel", "erledigt", "1 von 2 offen"])
        XCTAssertEqual(sut.lists.first?.isFavorite, true)
        XCTAssertEqual(sut.lists.last?.fraction ?? 0, 0.5, accuracy: 0.001)
    }

    // MARK: - Abhaken

    func test_toggle_checksLocallyAtOnce_queuesForServer_andTriggersHaptic() async throws {
        let milk = try addItem(listA, "Milch")
        let sut = makeSUT()
        sut.toggle(milk.id)
        await waitUntil { sut.checkedCount == 1 }
        XCTAssertEqual(sut.checkedCount, 1, "sofort lokal sichtbar")
        XCTAssertEqual(sut.checkFeedback, 1)
        XCTAssertEqual(sync.engine.operationQueue.count, 1, "wartet auf Sitzung/Netz, geht nicht verloren")
    }

    func test_checkAll_thenReset() async throws {
        try addItem(listA, "Milch")
        try addItem(listA, "Brot")
        let sut = makeSUT()
        sut.checkAll()
        await waitUntil { sut.isAllDone }
        XCTAssertTrue(sut.isAllDone, "→ Screen „Alles erledigt“")
        sut.resetAll()
        await waitUntil { sut.checkedCount == 0 }
        XCTAssertEqual(sut.checkedCount, 0)
    }

    func test_setUnits_isClamped() async throws {
        let milk = try addItem(listA, "Milch", units: 2)
        let sut = makeSUT()
        sut.setUnits(milk.id, to: 20_000)
        await waitUntil { sut.detail(for: milk.id)?.units == 9999 }
        XCTAssertEqual(sut.detail(for: milk.id)?.units, 9999)
    }

    /// Grammangaben und Kommazahlen bleiben erhalten (vorher Grenze 99).
    func test_setUnits_keepsGramsAndDecimals() async throws {
        let hack = try addItem(listA, "Hack", units: 500, measure: "g")
        let sut = makeSUT()
        XCTAssertEqual(sut.detail(for: hack.id)?.step, 50)
        sut.setUnits(hack.id, to: 1.25)
        await waitUntil { sut.detail(for: hack.id)?.units == 1.25 }
        XCTAssertEqual(sut.detail(for: hack.id)?.units, 1.25)
    }

    /// Erneut hinzufügen = eine Stufe mehr: 500 g → 550 g (vorher wurden daraus 99).
    func test_addExistingOpenName_withGrams_addsOneStep() async throws {
        let hack = try addItem(listA, "Hack", units: 500, measure: "g")
        let sut = makeSUT()
        sut.add(name: "Hack")
        await waitUntil { sut.detail(for: hack.id)?.units == 550 }
        XCTAssertEqual(sut.detail(for: hack.id)?.units, 550)
    }

    // MARK: - Hinzufügen

    func test_addExistingOpenName_incrementsUnits() async throws {
        try addItem(listA, "Milch", units: 2)
        let sut = makeSUT()
        sut.add(name: "  milch ")
        await waitUntil { sut.sections.flatMap(\.items).first?.quantity == "3" }
        XCTAssertEqual(sut.totalCount, 1, "kein zweiter Eintrag")
        XCTAssertEqual(sut.sections.flatMap(\.items).first?.quantity, "3")
    }

    /// kg: erneut hinzufügen = grober Schritt (1,5 kg → 2 kg), nicht 0,1.
    func test_addExistingOpenName_withKilogram_addsCoarseStep() async throws {
        let hack = try addItem(listA, "Hackfleisch", units: 1.5, measure: "kg")
        let sut = makeSUT()
        XCTAssertEqual(sut.detail(for: hack.id)?.step, 0.1)
        XCTAssertEqual(sut.detail(for: hack.id)?.coarseStep, 1)
        sut.add(name: "Hackfleisch")
        await waitUntil { sut.detail(for: hack.id)?.units == 2 }
        XCTAssertEqual(sut.detail(for: hack.id)?.units, 2)
    }

    func test_addCheckedName_reopensSameItem() async throws {
        let bread = try addItem(listA, "Brot", checked: true)
        let sut = makeSUT()
        sut.add(name: "Brot")
        await waitUntil { sut.checkedCount == 0 }
        XCTAssertEqual(sut.totalCount, 1)
        XCTAssertEqual(sut.sections.flatMap(\.items).first?.id, bread.id, "gleiche ID wie auf dem iPhone")
    }

    func test_addNewName_usesCatalogTemplate_andCountsUse() async throws {
        try await sync.catalog.save(ItemCatalogEntry(id: "c1", ownerPublicId: "me", name: "Hafermilch", brand: nil,
                                                    category: "Milchprodukte", productDescription: nil,
                                                    measure: "l", price: 0, imageData: nil))
        _ = try await sync.catalog.fetchAll()                              // lokale Kopie anlegen
        let sut = makeSUT()
        sut.add(name: "hafermilch")
        await waitUntil { sut.totalCount == 1 && !sut.frequent.isEmpty }
        XCTAssertEqual(sut.sections.map(\.title), ["Milchprodukte"], "Kategorie aus dem Artikelstamm")
        XCTAssertEqual(sut.frequent.map(\.name), ["Hafermilch"], "zählt sofort für „Oft gekauft“")
        XCTAssertEqual(sut.frequent.first?.detail, "Milchprodukte")
    }

    // MARK: - Abschnitte

    func test_sections_followStoreRoute_andKeepCheckedItemsInPlace() throws {
        try addItem(listA, "Seife", category: "Haushalt")
        try addItem(listA, "Äpfel", checked: true, category: "Obst & Gemüse")
        try addItem(listA, "Bananen", category: "Obst & Gemüse")
        try addItem(listA, "Schrauben", category: "Unbekannt")
        let sut = makeSUT()
        XCTAssertEqual(sut.sections.map(\.title), ["Obst & Gemüse", "Haushalt", "Sonstiges"])
        XCTAssertEqual(sut.sections.first?.items.map(\.name), ["Äpfel", "Bananen"], "erledigt bleibt im Abschnitt")
    }
}
