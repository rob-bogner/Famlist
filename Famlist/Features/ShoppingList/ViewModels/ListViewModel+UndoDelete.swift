/*
 ListViewModel+UndoDelete.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Löschen aus dem Dock und per Wisch-Aktion mit Rückgängig: sofort ausblenden, nach 5 s wirklich löschen.

 🔰 Notes for Beginners:
 - `stageDeletion` blendet die Artikel über `pendingBulkDeleteIDs` aus (derselbe Schutz, der
   Realtime-Snapshots am Wiedereinfügen hindert). In SwiftData und Supabase bleibt alles unverändert.
 - `undoPendingDeletion` holt die Artikel zurück, ohne dass je ein Tombstone geschrieben wurde.
 - `commitPendingDeletion` schreibt die Löschung über die normalen Wege (SyncEngine, Offline-First).
   Das passiert nach Ablauf des Toasts, bei einer neuen Löschung, beim Listenwechsel,
   beim Abmelden und wenn die App in den Hintergrund geht.

 📝 Last Change:
 - Festschreiben gebündelt und abwartbar (Audit 25.09.2026, H2).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension ListViewModel {
    /// Welche Artikel die Dock-Löschung betrifft.
    enum DeletionScope {
        case checked
        case all
    }

    /// Blendet die Artikel sofort aus und startet den 5-s-Rückgängig-Zeitraum.
    func stageDeletion(_ scope: DeletionScope) {
        stageDeletion(of: scope == .checked ? items.filter(\.isChecked) : items, scope: "\(scope)")
    }

    /// Einzelner Artikel (Wisch-Aktion „Löschen“): ebenfalls mit Rückgängig-Toast statt sofortigem Löschen.
    func stageDeletion(of item: ItemModel) {
        stageDeletion(of: [item], scope: "single")
    }

    /// Gemeinsamer Weg für Dock- und Einzel-Löschung.
    func stageDeletion(of targetsIn: [ItemModel], scope: String) {
        commitPendingDeletion()
        let targets = targetsIn
        guard !targets.isEmpty else { return }
        logVoid(params: (action: "stageDeletion", scope: scope, count: targets.count))
        UserLog.Data.itemsDeletedWithUndo(count: targets.count)

        let ids = Set(targets.map(\.id))
        pendingBulkDeleteIDs.formUnion(ids)
        withAnimation(.easeInOut(duration: 0.3)) {
            items.removeAll { ids.contains($0.id) }
            pendingDeletion = PendingItemDeletion(listId: listId, items: targets,
                                                  deadline: Date().addingTimeInterval(PendingItemDeletion.undoDuration))
        }
        let deletionId = pendingDeletion?.id
        pendingDeletionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(PendingItemDeletion.undoDuration * 1_000_000_000))
            guard !Task.isCancelled, let self, self.pendingDeletion?.id == deletionId else { return }
            self.commitPendingDeletion()
        }
    }

    /// „Rückgängig“: Artikel wieder einblenden, nichts wurde gelöscht.
    func undoPendingDeletion() {
        guard let pending = pendingDeletion else { return }
        pendingDeletionTask?.cancel()
        pendingDeletionTask = nil
        logVoid(params: (action: "undoPendingDeletion", count: pending.count))
        UserLog.Data.deletionUndone(count: pending.count)
        pendingBulkDeleteIDs.subtract(pending.items.map(\.id))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            pendingDeletion = nil
            refreshItemsFromStore()
        }
    }

    /// Schreibt eine offene Löschung fest (Tombstones über die SyncEngine, gebündelt).
    /// - Returns: Aufgabe, die nach dem lokalen Schreiben endet (addItem wartet darauf, damit ein
    ///   sofortiges Neu-Anlegen desselben Artikels die neuere HLC bekommt).
    @discardableResult
    func commitPendingDeletion() -> Task<Void, Never>? {
        guard let pending = pendingDeletion else { return nil }
        pendingDeletionTask?.cancel()
        pendingDeletionTask = nil
        withAnimation(.easeInOut(duration: 0.25)) { pendingDeletion = nil }
        guard let engine = syncEngine else { return nil }
        let targets = pending.items
        let isActiveList = pending.listId == listId
        return Task {
            await engine.deleteItems(targets)
            if isActiveList {
                self.pendingBulkDeleteIDs.subtract(targets.map(\.id))
                self.refreshItemsFromStore()
            }
        }
    }
}
