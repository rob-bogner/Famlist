/*
 ListViewModel+TestSeeding.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Test-Hilfe: legt einen Artikel direkt in SwiftData an (mit gewünschtem Sync-Status) und
   aktualisiert die Anzeige – ohne SyncEngine. Ersetzt das entfernte `storePendingChange`.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation
@testable import Famlist

extension ListViewModel {
    func storePendingChange(for item: ItemModel, status: ItemEntity.SyncStatus) {
        guard let entity = try? itemStore.upsert(model: item) else { return }
        entity.setSyncStatus(status)
        try? itemStore.save()
        refreshItemsFromStore()
    }
}
