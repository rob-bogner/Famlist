/*
 WatchWidgetStateTests.swift
 FamlistWatchTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Widget-Stand (Watch-Plan §6): Das ViewModel schreibt aktive Liste, offene und alle Artikel in die
   App Group; neu geladen wird nur bei Änderung; ohne Listen der leere Stand; Deep Links der Komplikationen.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 6).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import FamlistWatch

@MainActor
final class WatchWidgetStateTests: XCTestCase {
    private var defaults: UserDefaults!
    private var widgetDefaults: UserDefaults!
    private var directory: URL!
    private var reloads = 0

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "WatchWidgetStateTests.\(UUID().uuidString)")
        widgetDefaults = UserDefaults(suiteName: "WatchWidgetStateTests.group.\(UUID().uuidString)")
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        reloads = 0
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeSync() -> WatchSyncCoordinator {
        WatchSyncCoordinator(container: PersistenceController(inMemory: true).container,
                             itemsRepository: PreviewItemsRepository(), remote: nil,
                             catalog: OfflineItemCatalogRepository(remote: PreviewItemCatalogRepository(),
                                                                   store: CatalogLocalStore(directory: directory)),
                             transport: nil, hlcGenerator: HybridLogicalClockGenerator(nodeId: "widget-test"),
                             defaults: defaults, userId: { nil })
    }

    private func publisher() -> WatchWidgetPublisher {
        WatchWidgetPublisher(defaults: widgetDefaults) { [unowned self] in self.reloads += 1 }
    }

    func test_publisher_writesAndReloadsOnlyOnChange() {
        let sut = publisher()
        sut.publish(.placeholder)
        sut.publish(.placeholder)
        XCTAssertEqual(reloads, 1, "gleicher Stand → kein erneutes Zeichnen")
        XCTAssertEqual(WatchWidgetState.load(from: widgetDefaults), .placeholder)
        sut.publish(WatchWidgetState(listName: "My List", open: 3, total: 6))
        XCTAssertEqual(reloads, 2)
        XCTAssertEqual(WatchWidgetState.load(from: widgetDefaults)?.fraction ?? 0, 0.5, accuracy: 0.001)
    }

    func test_viewModel_publishesActiveList_andFollowsChecks() async throws {
        let sync = makeSync()
        let list = UUID()
        try sync.listStore.upsert(model: ListModel(id: list, ownerId: UUID(), title: "Wocheneinkauf", isDefault: true,
                                                    createdAt: Date(), updatedAt: Date()))
        let milk = ItemModel(id: UUID().uuidString, name: "Milch", units: 1, measure: "", listId: list.uuidString,
                             hlcTimestamp: 1, hlcCounter: 0, hlcNodeId: "phone")
        _ = try sync.itemStore.mergeRemote(milk)
        _ = try sync.itemStore.mergeRemote(ItemModel(id: UUID().uuidString, name: "Brot", units: 1, measure: "",
                                                     listId: list.uuidString, hlcTimestamp: 1, hlcCounter: 0,
                                                     hlcNodeId: "phone"))
        try sync.itemStore.save()

        let sut = WatchListViewModel(sync: sync, defaults: defaults, widgets: publisher())
        XCTAssertEqual(WatchWidgetState.load(from: widgetDefaults), WatchWidgetState(listName: "Wocheneinkauf", open: 2, total: 2))

        sut.toggle(milk.id)
        for _ in 0..<300 where WatchWidgetState.load(from: widgetDefaults)?.open != 1 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(WatchWidgetState.load(from: widgetDefaults)?.open, 1, "Abhaken aktualisiert die Komplikation")
    }

    func test_withoutLists_publishesEmptyState() {
        _ = WatchListViewModel(sync: makeSync(), defaults: defaults, widgets: publisher())
        XCTAssertEqual(WatchWidgetState.load(from: widgetDefaults), .empty)
    }

    func test_complicationDeepLinks() throws {
        XCTAssertEqual(WatchRoute.path(for: try XCTUnwrap(URL(string: "famlist://watch/list"))), [.list])
        XCTAssertEqual(WatchRoute.path(for: try XCTUnwrap(URL(string: "famlist://watch/add"))), [.list, .add])
        XCTAssertNil(WatchRoute.path(for: try XCTUnwrap(URL(string: "famlist://invite/abc"))))
    }
}
