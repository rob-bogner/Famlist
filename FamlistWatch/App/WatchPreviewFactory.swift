/*
 WatchPreviewFactory.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nur DEBUG: Sitzung und ViewModel mit Beispieldaten im Arbeitsspeicher – für #Preview (kein Netz,
   kein Supabase, Projektregel).
 ------------------------------------------------------------------------
 */

#if DEBUG
import Foundation

@MainActor
enum WatchPreviewFactory {
    static func make() -> (session: WatchSessionManager, model: WatchListViewModel) {
        let transport = WatchConnectivityService()
        let session = WatchSessionManager(auth: nil, transport: transport)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("watch-preview-catalog")
        let sync = WatchSyncCoordinator(
            container: PersistenceController(inMemory: true).container, itemsRepository: PreviewItemsRepository(),
            remote: nil, catalog: OfflineItemCatalogRepository(remote: PreviewItemCatalogRepository(),
                                                                store: CatalogLocalStore(directory: directory)),
            transport: nil, hlcGenerator: HybridLogicalClockGenerator(nodeId: "preview"),
            defaults: UserDefaults(suiteName: "watch-preview") ?? .standard, userId: { nil })
        let list = ListModel(id: WatchSampleData.lists[0].id, ownerId: UUID(), title: "My List", isDefault: true,
                             createdAt: Date(), updatedAt: Date())
        _ = try? sync.listStore.upsert(model: list)
        for (name, units, checked) in [("Bananen", 6, false), ("Tomaten", 500, false), ("Äpfel", 1, true)] {
            _ = try? sync.itemStore.upsert(model: ItemModel(name: name, units: units, measure: name == "Tomaten" ? "g" : "",
                                                            isChecked: checked, category: "Obst & Gemüse",
                                                            listId: list.id.uuidString))
        }
        sync.bump()
        return (session, WatchListViewModel(sync: sync, defaults: UserDefaults(suiteName: "watch-preview") ?? .standard))
    }
}
#endif
