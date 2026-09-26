/*
 ListViewModel+Configuration.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nachträgliches Einsetzen der Abhängigkeiten (Listen-Repository, Netzstatus, SyncEngine, Foto-Speicher, Artikelstamm, Seitenlader).

 📝 Last Change:
 - Aus ListViewModel.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation
import Combine

extension ListViewModel {
    // MARK: - Configuration
    
    /// Injects a ListsRepository used to fetch/create the user's default list.
    /// - Parameter listsRepository: Concrete implementation (Supabase or Preview) resolving default list rows.
    func configure(listsRepository: ListsRepository) {
        self.listsRepository = listsRepository
        if let offline = listsRepository as? OfflineListsRepository {
            // Liste auf dem Server weg (gelöscht/entfernt) → lokale Daten löschen.
            offline.onListsVanished = { [weak self] ids in
                guard let self else { return }
                ids.forEach { self.handleMembershipRemoval(listId: $0) }
            }
            // Neue Liste angelegt → wartende Artikel dieser Liste jetzt senden.
            offline.onFlushed = { [weak self] in
                Task { await self?.syncEngine?.resumeSync() }
            }
        }
    }
    
    /// Injects the connectivity monitor so the view model can resume realtime sync when the device comes back online.
    /// - Parameter connectivityMonitor: Shared monitor publishing online/offline state.
    func configure(connectivityMonitor: ConnectivityMonitor) {
        connectivityCancellable?.cancel() // Cancel previous subscription if configure gets called again.
        connectivityCancellable = connectivityMonitor.$isOnline
            .removeDuplicates()
            .sink { [weak self] isOnline in
                guard let self else { return }
                if isOnline {
                    self.prefetchImages()
                    self.resumeRealtimeSync(trigger: .connectivity)
                    // Also resume sync engine if available
                    Task {
                        await self.syncEngine?.resumeSync()
                    }
                }
            }
    }
    
    /// Injects the sync engine for CRDT-based operations.
    /// Pass `SyncEngine` in production, `PreviewSyncEngine` in previews.
    func configure(syncEngine: any SyncEngineProtocol) {
        self.syncEngine = syncEngine
        // Offline-First: nach jedem lokalen Schreiben sofort aus SwiftData neu lesen (nicht erst nach dem Netzwerk).
        syncEngine.setLocalWriteObserver { [weak self] in self?.refreshItemsFromStore() }
        // Nutzer-Logs zum Sync entstehen hier im ViewModel (Projektregel), nicht in der SyncEngine.
        syncEngine.setSyncEventObserver { event in
            switch event {
            case .started(let count):
                if count > 0 { UserLog.Sync.syncing(itemCount: count) }
            case .completed(let count, _):
                if count > 0 { UserLog.Sync.completed(itemCount: count) }
            case .itemFailed(let item):
                UserLog.Sync.itemSyncFailed(name: item.name, units: item.units, measure: item.measure)
            }
        }
    }

    /// Fotos in Supabase Storage (Migration 016): Herunterladen für die Offline-Anzeige.
    func configure(imageStorage: ImageStorage) {
        imagePrefetcher = ItemImagePrefetcher(store: itemStore, storage: imageStorage) { [weak self] in
            self?.refreshItemsFromStore()
        }
    }

    /// Fehlende Fotos im Hintergrund laden (alle Listen).
    internal func prefetchImages() {
        guard let imagePrefetcher else { return }
        Task { await imagePrefetcher.prefetchMissing() }
    }

    /// Injects the personal item catalog repository for smart search support.
    /// - Parameter catalogRepository: Repository that saves/searches the user's item catalog.
    func configure(catalogRepository: any ItemCatalogRepository) {
        self.catalogRepository = catalogRepository
    }

    /// Injects the global OpenFoodFacts catalog repository for extended product search.
    /// - Parameter globalCatalogRepository: Read-only repository for the global OFF DACH catalog.
    func configure(globalCatalogRepository: any GlobalProductCatalogRepository) {
        self.globalCatalogRepository = globalCatalogRepository
    }

    /// Injects the SyncOrchestrator and PageLoader for cursor-based pagination (FAM-79/FAM-40).
    func configure(syncOrchestrator: SyncOrchestrator, pageLoader: PageLoader) {
        self.syncOrchestrator = syncOrchestrator
        self.pageLoader = pageLoader
        syncOrchestrator.onBudgetExceeded = { [weak self] in
            guard let self else { return }
            Task { await self.runIncrementalSync() }
        }
    }
}
