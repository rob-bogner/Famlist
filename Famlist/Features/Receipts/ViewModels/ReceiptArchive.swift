/*
 ReceiptArchive.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kassenzettel-Archiv: Bons mit Fotos speichern (offline zuerst), anzeigen und löschen.

 🔰 Notes for Beginners:
 - Offline-First: `archive` schreibt die Fotos sofort als Dateien und legt einen Auftrag in die
   Warteschlange. Der Bon erscheint gleich im Archiv (`isPending`); hochgeladen wird im Hintergrund,
   bei fehlendem Netz später (Reconnect wie PriceBook). Siehe ReceiptArchive+Sync.swift.
 - Schalter „Fotos der Bons speichern“ aus → `archive` tut nichts (ReceiptArchiveSetting).
 - Löschen entfernt Fotos und Eintrag; Preispunkte (PriceBook) sind davon unabhängig und bleiben.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Combine
import UIKit

@MainActor
final class ReceiptArchive: ObservableObject {
    static let maxPhotos = 10
    static let maxFailures = 5

    /// Sichtbare Bons: Server-Stand plus wartende neue, ohne wartende gelöschte; neueste zuerst.
    @Published private(set) var receipts: [ArchivedReceipt] = []
    @Published private(set) var isLoading = false

    let repository: ReceiptsRepository?
    let store: ReceiptArchiveLocalStore
    private let defaults: UserDefaults
    var flushTask: Task<Void, Never>?
    private var reconnectSubscription: AnyCancellable?

    init(repository: ReceiptsRepository?, store: ReceiptArchiveLocalStore = ReceiptArchiveLocalStore(),
         defaults: UserDefaults = .standard, reconnect: AnyPublisher<Bool, Never>? = nil) {
        self.repository = repository
        self.store = store
        self.defaults = defaults
        reconnectSubscription = reconnect?
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in Task { await self?.flush() } }
        publish()
    }

    var isEnabled: Bool { ReceiptArchiveSetting.isEnabled(defaults) }
    var totalBytes: Int { receipts.reduce(0) { $0 + $1.bytes } }
    /// Ungesendete Aufträge (Rückfrage beim Abmelden).
    var pendingCount: Int { store.outbox.count }

    // MARK: - Speichern

    /// „Preise speichern“: Bon mit Fotos ins Archiv. nil, wenn der Schalter aus ist oder nichts kodierbar war.
    @discardableResult
    func archive(_ draft: ReceiptArchiveDraft) async -> ArchivedReceipt? {
        guard isEnabled, !draft.pages.isEmpty else { return nil }
        let pages = Array(draft.pages.prefix(Self.maxPhotos))
        let encoded = await Task.detached(priority: .userInitiated) {
            pages.compactMap(ReceiptPhotoCodec.jpeg(from:))
        }.value
        guard !encoded.isEmpty else { return nil }
        let id = UUID()
        let paths = encoded.indices.map { ArchivedReceipt.photoPath(listId: draft.listId, receiptId: id, index: $0 + 1) }
        do {
            for (data, path) in zip(encoded, paths) { try store.writePendingPhoto(data, path: path) }
        } catch {
            store.removePhotos(paths: paths)
            logVoid(params: (action: "receiptArchive.writeFailed", error: (error as NSError).localizedDescription))
            return nil
        }
        let receipt = Self.receipt(id: id, draft: draft, paths: paths, bytes: encoded.reduce(0) { $0 + $1.count })
        store.enqueue(.create(receipt))
        publish()
        UserLog.Data.receiptArchived(store: receipt.storeName, photos: paths.count)
        Task { await flush() }
        return receipt
    }

    private static func receipt(id: UUID, draft: ReceiptArchiveDraft, paths: [String], bytes: Int) -> ArchivedReceipt {
        ArchivedReceipt(id: id, listId: draft.listId, listTitle: draft.listTitle, createdBy: draft.createdBy,
                        creatorName: draft.creatorName, storeName: draft.storeName, purchasedAt: draft.purchasedAt,
                        total: draft.total, lineCount: draft.lineCount, savedPriceCount: draft.savedPriceCount,
                        photoPaths: paths, bytes: bytes, createdAt: Date(), isPending: true)
    }

    // MARK: - Laden

    /// Archiv öffnen: erst Warteschlange senden, dann Server-Stand laden. Ohne Netz bleibt der letzte Stand.
    func refresh() async {
        guard let repository else { return }
        isLoading = true
        defer { isLoading = false }
        await flush()
        do {
            store.setCache(try await repository.fetchAll())
            publish()
        } catch {
            logVoid(params: (action: "receiptArchive.refreshFailed", error: (error as NSError).localizedDescription))
        }
    }

    /// Foto-Daten: lokal (Warteschlange oder Cache), sonst vom Server laden und zwischenspeichern.
    func photoData(path: String) async -> Data? {
        if let local = store.photo(path: path) { return local }
        guard let repository, let data = try? await repository.downloadPhoto(path: path) else { return nil }
        store.cachePhoto(data, path: path)
        return data
    }

    // MARK: - Löschen

    /// Löscht Fotos und Eintrag. Noch nicht hochgeladene Bons verschwinden nur lokal.
    func delete(_ receipt: ArchivedReceipt) async {
        let create = ReceiptArchiveLocalStore.Operation.create(receipt.withPending(true))
        let wasQueued = store.outbox.contains { $0.operation == create }
        store.remove(create)
        // Läuft gerade ein Upload, könnte er den Bon noch anlegen → Löschauftrag trotzdem einreihen.
        if !wasQueued || flushTask != nil { store.enqueue(.delete(receipt.withPending(false))) }
        if wasQueued && flushTask == nil { store.removePhotos(paths: receipt.photoPaths) }
        store.removeFromCache(id: receipt.id)
        publish()
        UserLog.Data.receiptArchiveDeleted(store: receipt.storeName)
        await flush()
    }

    /// Abmelden: alles Lokale löschen.
    func clearLocal() {
        flushTask?.cancel()
        store.clear()
        publish()
    }

    // MARK: - Anzeige

    func publish() {
        var visible = store.cache
        for pending in store.outbox {
            switch pending.operation {
            case .create(let receipt):
                if !visible.contains(where: { $0.id == receipt.id }) { visible.append(receipt) }
            case .delete(let receipt):
                visible.removeAll { $0.id == receipt.id }
            }
        }
        receipts = visible.sorted { ($0.purchasedAt, $0.createdAt) > ($1.purchasedAt, $1.createdAt) }
    }
}

private extension ArchivedReceipt {
    func withPending(_ pending: Bool) -> ArchivedReceipt {
        var copy = self
        copy.isPending = pending
        return copy
    }
}
