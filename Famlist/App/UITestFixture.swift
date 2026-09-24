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
 - Die Artikelnamen („Äpfel“, „Butter“ …) sind Teil des Test-Vertrags; beim Ändern die UI-Tests anpassen.

 📝 Last Change:
 - Aus der UI-Test-Kopie der Hybrid-Redesign-Session übernommen.
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
        vm.defaultList = ListModel(id: vm.listId, ownerId: UUID(), title: "My List", isDefault: true,
                                   createdAt: Date(), updatedAt: Date())
        for (name, category) in sampleItems {
            vm.addItem(ItemModel(name: name, units: 1, category: category.rawValue, listId: vm.listId.uuidString))
        }
        return vm
    }()

    static let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                             lists: PreviewListsRepository(), listViewModel: listVM)

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
