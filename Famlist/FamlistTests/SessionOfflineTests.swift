/*
 SessionOfflineTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sitzung offline (Audit K6/H5): Profil-Kopie, Abmelden löscht alle Kontodaten, Geräte-Einstellungen
   bleiben. Der eigentliche Offline-Start läuft als UI-Test (OfflineStartUITests).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class SessionOfflineTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SessionOfflineTests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
    }

    private func profile(_ id: UUID = UUID(), username: String? = "rob") -> Profile {
        Profile(id: id, publicId: "pub1", username: username, fullName: "Rob", avatarUrl: nil,
                createdAt: nil, updatedAt: nil, favoriteListId: UUID())
    }

    func test_profileCache_roundTrip_andClear() {
        let me = profile()
        ProfileCache.save(me, defaults: defaults)
        XCTAssertEqual(ProfileCache.load(userId: me.id, defaults: defaults), me)
        ProfileCache.clearAll(defaults: defaults)
        XCTAssertNil(ProfileCache.load(userId: me.id, defaults: defaults))
    }

    func test_localAccountData_removesListKeys_keepsDeviceSettings() {
        let list = UUID().uuidString
        for key in ["listSortSettings.\(list)", "manualItemOrder.\(list)", "fam24_last_sync_ts_\(list)",
                    "fam24_pagination_cursor_\(list)", "categoryDefinitions.\(list)"] {
            defaults.set("x", forKey: key)
        }
        defaults.set("dark", forKey: "appearanceChoice")
        defaults.set("node", forKey: "famlist.hlc.nodeId")

        LocalAccountData.removeListPreferences(defaults: defaults)

        XCTAssertNil(defaults.string(forKey: "listSortSettings.\(list)"))
        XCTAssertNil(defaults.string(forKey: "fam24_pagination_cursor_\(list)"))
        XCTAssertNil(defaults.string(forKey: "categoryDefinitions.\(list)"))
        XCTAssertEqual(defaults.string(forKey: "appearanceChoice"), "dark", "Geräte-Einstellung bleibt")
        XCTAssertEqual(defaults.string(forKey: "famlist.hlc.nodeId"), "node", "Geräte-ID bleibt")
    }

    func test_resetLocalState_clearsItemsListsProfileAndCallsHandlers() throws {
        let container = PersistenceController(inMemory: true).container
        let itemStore = SwiftDataItemStore(context: container.mainContext)
        let listStore = SwiftDataListStore(context: container.mainContext)
        let listId = UUID()
        let listVM = ListViewModel(listId: listId, repository: PreviewItemsRepository(), itemStore: itemStore,
                                   listStore: listStore, startImmediately: false)
        try itemStore.upsert(model: ItemModel(imageData: "YWJj", name: "Privat", listId: listId.uuidString))
        _ = try listStore.upsert(model: ListModel(id: listId, ownerId: UUID(), title: "Meine", isDefault: true,
                                                  createdAt: Date(), updatedAt: Date()))
        try itemStore.save()

        let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                          lists: PreviewListsRepository(), listViewModel: listVM)
        session.currentProfile = profile()
        session.pendingInvite = .init(token: "t", listTitle: "WG")
        var handlerCalls = 0
        session.onSignOut { handlerCalls += 1 }

        session.resetLocalState()

        XCTAssertTrue(try itemStore.fetchItems(listId: listId, includeDeleted: true).isEmpty)
        XCTAssertTrue(try listStore.fetchLists().isEmpty)
        XCTAssertNil(session.currentProfile)
        XCTAssertNil(session.pendingInvite)
        XCTAssertEqual(handlerCalls, 1)
    }
}
