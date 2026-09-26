/*
 WatchSyncCoordinator.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Die Uhr als eigener Sync-Knoten (Watch-Plan §2): eigener SwiftData-Speicher, dieselbe SyncEngine wie
   das iPhone (eigene HLC-Geräte-ID), Abfrage aller Listen alle 10 s bei sichtbarer App, Sofort-Weg zum
   iPhone, Zurücksetzen beim Abmelden.

 🛠 Includes:
 - setActive: Abfrage-Takt und Senden starten/anhalten (App sichtbar / nicht sichtbar).
 - mergeFromPhone: Artikel vom iPhone nur per HLC übernehmen (nicht erneut senden).
 - reset: Speicher, Warteschlangen und Merker des Kontos löschen.
 - Abfrage (Listen, Favorit, Kategorien, Artikel) → WatchSyncCoordinator+Pull.swift.

 🔰 Notes for Beginners:
 - `revision` zählt jede sichtbare Änderung hoch; die ViewModels bauen daraufhin ihre Anzeige neu.
 - Ohne Sitzung (userId == nil) sendet und fragt die Uhr nichts; die Warteschlange bleibt liegen.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation
import SwiftData

@MainActor
final class WatchSyncCoordinator: ObservableObject {
    /// Zählt jede sichtbare Datenänderung hoch (Listen, Artikel, Favorit, Kategorien).
    @Published private(set) var revision = 0
    @Published var favoriteListId: UUID?
    @Published var categories: [CategoryDefinition] = CategoryDefinition.defaults

    let container: ModelContainer
    let itemStore: SwiftDataItemStore
    let listStore: SwiftDataListStore
    let engine: SyncEngine
    let catalog: OfflineItemCatalogRepository
    let itemsRepository: ItemsRepository
    let remote: WatchRemoteSource?
    let transport: WatchTransport?
    let defaults: UserDefaults
    let userId: @MainActor () -> UUID?
    var marks: WatchDeltaMarks { WatchDeltaMarks(defaults: defaults) }

    /// Abfrage-Takt bei sichtbarer App (Watch-Plan §2).
    static let pollInterval: UInt64 = 10_000_000_000
    private var pollTask: Task<Void, Never>?
    var isPulling = false
    var lastCatalogRefresh: Date?

    static let favoriteKey = "watch.favoriteListId"
    static let categoriesKey = "watch.categories"

    init(container: ModelContainer, itemsRepository: ItemsRepository, remote: WatchRemoteSource?,
         catalog: OfflineItemCatalogRepository, transport: WatchTransport?, hlcGenerator: HybridLogicalClockGenerator,
         defaults: UserDefaults = .standard, imageStorage: ImageStorage? = nil,
         userId: @escaping @MainActor () -> UUID?) {
        self.container = container
        itemStore = SwiftDataItemStore(context: container.mainContext)
        listStore = SwiftDataListStore(context: container.mainContext)
        self.itemsRepository = itemsRepository
        self.remote = remote
        self.catalog = catalog
        self.transport = transport
        self.defaults = defaults
        self.userId = userId
        engine = SyncEngine(repository: itemsRepository, itemStore: itemStore,
                            operationQueue: SyncOperationQueue(context: container.mainContext),
                            hlcGenerator: hlcGenerator, imageStorage: imageStorage,
                            isOnline: { userId() != nil })
        loadCachedSettings()
        engine.setLocalWriteObserver { [weak self] in self?.bump() }
        engine.setWrittenItemsObserver { [weak self] items in self?.forwardToPhone(items) }
    }

    // MARK: - Lebenszyklus

    /// App sichtbar: sofort abfragen und senden, danach alle 10 s. Nicht sichtbar: anhalten.
    func setActive(_ active: Bool) {
        pollTask?.cancel()
        pollTask = nil
        guard active else { engine.pause(); return }
        engine.resume()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pull()
                try? await Task.sleep(nanoseconds: Self.pollInterval)
            }
        }
    }

    /// Sichtbare Änderung melden (ViewModels bauen neu).
    func bump() {
        revision += 1
    }

    // MARK: - Sofort-Weg

    /// Eigene Änderungen sofort an das iPhone (ohne Fotos), falls erreichbar.
    private func forwardToPhone(_ items: [ItemModel]) {
        guard let transport, transport.isReachable else { return }
        WatchMessage.itemBatches(items).forEach { transport.send($0, reply: nil) }
    }

    /// Artikel vom iPhone: nur übernehmen, wenn ihre HLC neuer ist. Nicht einreihen (das iPhone sendet selbst).
    func mergeFromPhone(_ items: [ItemModel]) {
        var changed = false
        for item in items {
            let result = (try? itemStore.mergeRemote(item, legacyImageKnown: false)) ?? .ignored
            if result != .ignored { changed = true }
        }
        guard changed else { return }
        try? itemStore.save()
        bump()
    }

    // MARK: - Abmelden

    /// Alles des Kontos von der Uhr löschen: Artikel, Listen, Warteschlangen, Artikelstamm, Merker.
    func reset() {
        pollTask?.cancel()
        pollTask = nil
        engine.resetForSignOut()
        try? itemStore.deleteAll()
        try? listStore.deleteAll()
        try? listStore.save()
        catalog.clearLocalData()
        marks.clear()
        defaults.removeObject(forKey: Self.favoriteKey)
        defaults.removeObject(forKey: Self.categoriesKey)
        favoriteListId = nil
        categories = CategoryDefinition.defaults
        lastCatalogRefresh = nil
        bump()
        logVoid(params: ["action": "watchSync.reset"])
    }

    // MARK: - Zwischenspeicher

    private func loadCachedSettings() {
        favoriteListId = defaults.string(forKey: Self.favoriteKey).flatMap(UUID.init(uuidString:))
        if let data = defaults.data(forKey: Self.categoriesKey),
           let cached = try? JSONDecoder().decode([CategoryDefinition].self, from: data), !cached.isEmpty {
            categories = cached
        }
    }
}
