/*
 UITestFixture.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Startmodus für UI-Tests: Mit dem Launch-Argument `-uiTestFixture` zeigt die App direkt den echten
   ShoppingListView mit 16 In-Memory-Artikeln – ohne Anmeldung und ohne Supabase.

 🔰 Notes for Beginners:
 - Nur in DEBUG-Builds enthalten; Release-Builds kennen diesen Typ nicht.
 - Genutzt von FamlistUITests/SwipeUITests (Wischgeste auf Gerät oder Simulator).
 - Die Artikelnamen („Äpfel“, „Butter“ …) und Listen („My List“, „Drogerie“, geteilte „WG-Einkauf“)
   sind Teil des Test-Vertrags; beim Ändern die UI-Tests anpassen.

 📝 Last Change:
 - Drei Listen und ein angemeldetes Testprofil für das Sheet „Meine Listen“.
 ------------------------------------------------------------------------
 */

#if DEBUG
import SwiftUI

/// In-memory list and session for UI tests (launch argument `-uiTestFixture`).
@MainActor
enum UITestFixture {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-uiTestFixture")

    static let listVM: ListViewModel = {
        let repo = PreviewItemsRepository()
        let container = PersistenceController.preview.container
        let vm = ListViewModel(listId: UUID(), repository: repo,
                               itemStore: SwiftDataItemStore(context: container.mainContext),
                               listStore: SwiftDataListStore(context: container.mainContext))
        vm.configure(syncEngine: PreviewSyncEngine(repository: repo))
        let active = ListModel(id: vm.listId, ownerId: ownerId, title: "My List", isDefault: true,
                               createdAt: Date(), updatedAt: Date())
        vm.defaultList = active
        vm.allLists = [active,
                       ListModel(id: UUID(), ownerId: ownerId, title: "Drogerie", isDefault: false,
                                 createdAt: Date(), updatedAt: Date()),
                       ListModel(id: UUID(), ownerId: UUID(), title: "WG-Einkauf", isDefault: false,
                                 createdAt: Date(), updatedAt: Date())]
        for (name, category) in sampleItems {
            vm.addItem(ItemModel(name: name, units: 1, category: category.rawValue, listId: vm.listId.uuidString))
        }
        vm.listItemCounts = Dictionary(uniqueKeysWithValues: vm.allLists.map { ($0.id, $0.id == vm.listId ? sampleItems.count : 2) })
        return vm
    }()

    /// Owner of "My List" and "Drogerie"; "WG-Einkauf" belongs to someone else (shared list).
    private static let ownerId = UUID()

    static let session: AppSessionViewModel = {
        let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                          lists: PreviewListsRepository(), listViewModel: listVM)
        session.currentProfile = Profile(id: ownerId, publicId: "ui-test", username: "uitest", fullName: "UI Test",
                                         avatarUrl: nil, createdAt: nil, updatedAt: nil)
        return session
    }()

    private static let sampleItems: [(String, ItemCategory)] = [
        ("Butter", .milch), ("Joghurt", .milch), ("Käse", .milch),
        ("Äpfel", .obstGemuese), ("Bananen", .obstGemuese), ("Tomaten", .obstGemuese),
        ("Brot", .backwaren), ("Brötchen", .backwaren),
        ("Wasser", .getraenke), ("Saft", .getraenke),
        ("Spülmittel", .haushalt), ("Pizza", .tiefkuehl),
        ("Hähnchen", .fleisch), ("Lachs", .fleisch),
        ("Batterien", .sonstiges), ("Kerzen", .sonstiges)
    ]
}
#endif
