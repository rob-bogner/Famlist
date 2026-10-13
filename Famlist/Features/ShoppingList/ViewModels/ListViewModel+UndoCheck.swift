/*
 ListViewModel+UndoCheck.swift
 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abhaken mit Rückgängig: Nach dem Abhaken zeigt die Liste 5 s lang den Toast „„Name“ abgehakt“ bzw.
   „n Artikel abgehakt“ mit „Rückgängig“. Gilt für einen einzelnen Artikel und für „Alle abhaken“
   (Dock und Abschnittskopf).

 🔰 Notes for Beginners:
 - `offerCheckUndo` merkt sich nur, welche Artikel die letzte Aktion abgehakt hat. Die Haken selbst sind
   schon gespeichert (SyncEngine, Offline-First).
 - `undoPendingCheck` entfernt genau diese Haken wieder. Artikel, die schon vorher abgehakt waren, bleiben
   abgehakt. Ist ein Artikel inzwischen nicht mehr abgehakt oder gelöscht, wird er übersprungen.
 - Ein neuer Haken ersetzt den Hinweis. Löschen, „Zurücksetzen“, Listenwechsel, Abmelden und der Wechsel
   in den Hintergrund blenden ihn aus (`dismissPendingCheck`).
 - „Einkauf erledigt“ wartet, bis der Hinweis weg ist (ShoppingListView.offerShoppingDone).
 - Geteilte Liste: „Rückgängig“ zählt für den Server wie „Haken entfernt“. Wer es tippt, gilt danach als
   die Person, die den Artikel hinzugefügt hat (Migration 039, Regel 3).

 📝 Last Change:
 - Auch für „Alle abhaken“ im Dock und im Abschnittskopf (Wunsch Robert 12.10.2026).
 - Initial creation (Wunsch Robert 12.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension ListViewModel {
    /// Zeigt den Rückgängig-Toast für die gerade abgehakten Artikel und startet die 5 s.
    func offerCheckUndo(for checked: [ItemModel]) {
        guard !checked.isEmpty else { return }
        pendingCheckTask?.cancel()
        let pending = PendingItemCheck(listId: listId, items: checked,
                                       deadline: Date().addingTimeInterval(PendingItemCheck.undoDuration))
        withAnimation(.easeInOut(duration: 0.3)) { pendingCheck = pending }
        pendingCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(PendingItemCheck.undoDuration * 1_000_000_000))
            guard !Task.isCancelled, let self, self.pendingCheck?.id == pending.id else { return }
            withAnimation(.easeInOut(duration: 0.25)) { self.dismissPendingCheck() }
        }
    }

    /// „Rückgängig“: die Haken dieser Aktion wieder entfernen.
    func undoPendingCheck() {
        guard let pending = pendingCheck else { return }
        dismissPendingCheck()
        guard pending.listId == listId else { return }
        let ids = Set(pending.itemIds)
        let targets = items.filter { ids.contains($0.id) && $0.isChecked }
        logVoid(params: (action: "undoPendingCheck", count: targets.count))
        if targets.count == 1 {
            toggleItemChecked(targets[0])             // meldet „Haken entfernt“ im Nutzer-Log
        } else if !targets.isEmpty {
            uncheckTogether(targets)
        }
    }

    /// Mehrere Haken auf einmal entfernen: Anzeige sofort, Speichern gebündelt über die SyncEngine
    /// (wie „Alle abhaken“ im Abschnittskopf).
    private func uncheckTogether(_ targets: [ItemModel]) {
        UserLog.Data.checkUndone(count: targets.count)
        let ids = Set(targets.map(\.id))
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isChecked = false
        }
        items = ListViewModel.currentSortOrder.apply(to: items)
        let changed = items.filter { ids.contains($0.id) }
        guard let syncEngine else { return }
        Task { await syncEngine.applyLocalChanges(changed) }
    }

    /// Blendet den Toast aus, ohne etwas zu ändern.
    func dismissPendingCheck() {
        pendingCheckTask?.cancel()
        pendingCheckTask = nil
        if pendingCheck != nil { pendingCheck = nil }
    }
}
