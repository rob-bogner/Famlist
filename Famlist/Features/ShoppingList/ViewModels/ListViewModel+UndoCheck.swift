/*
 ListViewModel+UndoCheck.swift
 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abhaken mit Rückgängig: Nach dem Abhaken eines einzelnen Artikels zeigt die Liste 5 s lang den Toast
   „„Name“ abgehakt“ mit „Rückgängig“.

 🔰 Notes for Beginners:
 - `offerCheckUndo` merkt sich nur, welcher Artikel zuletzt abgehakt wurde. Der Haken selbst ist schon
   gespeichert (toggleItemChecked → SyncEngine, Offline-First).
 - `undoPendingCheck` entfernt den Haken über denselben Weg wie ein Tipp auf den Artikel. Ist der Artikel
   inzwischen nicht mehr abgehakt oder gelöscht, passiert nichts.
 - Ein neuer Haken ersetzt den Hinweis. Löschen, „Alle abhaken“/„Zurücksetzen“, Listenwechsel, Abmelden und
   der Wechsel in den Hintergrund blenden ihn aus (`dismissPendingCheck`).
 - Geteilte Liste: „Rückgängig“ zählt für den Server wie „Haken entfernt“. Wer es tippt, gilt danach als
   die Person, die den Artikel hinzugefügt hat (Migration 039, Regel 3).

 📝 Last Change:
 - Initial creation (Wunsch Robert 12.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension ListViewModel {
    /// Zeigt den Rückgängig-Toast für den gerade abgehakten Artikel und startet die 5 s.
    func offerCheckUndo(for item: ItemModel) {
        pendingCheckTask?.cancel()
        let pending = PendingItemCheck(listId: listId, itemId: item.id, name: item.name,
                                       deadline: Date().addingTimeInterval(PendingItemCheck.undoDuration))
        pendingCheck = pending
        pendingCheckTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(PendingItemCheck.undoDuration * 1_000_000_000))
            guard !Task.isCancelled, let self, self.pendingCheck?.id == pending.id else { return }
            withAnimation(.easeInOut(duration: 0.25)) { self.dismissPendingCheck() }
        }
    }

    /// „Rückgängig“: Haken wieder entfernen.
    func undoPendingCheck() {
        guard let pending = pendingCheck else { return }
        dismissPendingCheck()
        guard pending.listId == listId,
              let current = items.first(where: { $0.id == pending.itemId }), current.isChecked else { return }
        logVoid(params: (action: "undoPendingCheck", itemId: pending.itemId))
        toggleItemChecked(current)                    // meldet „Haken entfernt“ im Nutzer-Log
    }

    /// Blendet den Toast aus, ohne etwas zu ändern.
    func dismissPendingCheck() {
        pendingCheckTask?.cancel()
        pendingCheckTask = nil
        if pendingCheck != nil { pendingCheck = nil }
    }
}
