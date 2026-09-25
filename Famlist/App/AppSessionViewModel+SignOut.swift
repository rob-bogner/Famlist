/*
 AppSessionViewModel+SignOut.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abmelden: offene Änderungen zuerst senden; bleiben welche übrig (z. B. offline), fragt die App nach,
   statt sie still zu verwerfen (Audit 2, Befund S4). Danach werden alle lokalen Daten des Kontos gelöscht.

 🔰 Notes for Beginners:
 - Nach dem Abmelden müssen die Daten des Kontos vom Gerät verschwinden (nächstes Konto darf nichts sehen).
   Ungesendetes lässt sich deshalb nicht „für später“ aufheben – nur senden oder bewusst verwerfen.
 - `unsentChangesBeforeSignOut` steuert die Rückfrage in den Einstellungen.

 📝 Last Change:
 - Aus AppSessionViewModel ausgelagert und um die Rückfrage ergänzt (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension AppSessionViewModel {
    /// Abmelden. `discardingUnsentChanges: true` nach bestätigter Rückfrage.
    func signOut(discardingUnsentChanges: Bool = false) {
        guard let authService else { return }
        if isLoading { return }
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            let unsent = await sendPendingChanges()
            if unsent > 0 && !discardingUnsentChanges {
                logVoid(params: (action: "signOut.blocked", unsent: unsent))
                unsentChangesBeforeSignOut = unsent
                return
            }
            unsentChangesBeforeSignOut = nil
            do {
                try await authService.signOut()
            } catch {
                logVoid(params: ["action": "signOut", "status": "remoteFailed", "message": (error as NSError).localizedDescription])
            }
            resetLocalState()
            UserLog.Auth.loggedOut()
            isAuthenticated = false
            errorMessage = nil
        }
    }

    /// Sendet, was geht, und wartet online höchstens 3 s darauf. Rückgabe: Zahl der noch offenen Änderungen.
    func sendPendingChanges() async -> Int {
        await listViewModel.commitPendingDeletion()?.value
        await (lists as? OfflineListsRepository)?.flush()
        await (listViewModel.catalogRepository as? OfflineItemCatalogRepository)?.flush()
        await listViewModel.syncEngine?.resumeSync()
        let deadline = Date().addingTimeInterval(3)
        while unsentChangeCount() > 0, Date() < deadline, ConnectivityMonitor.shared.isOnline {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await listViewModel.syncEngine?.resumeSync()
        }
        return unsentChangeCount()
    }

    /// Artikel-Warteschlange + Listen-Aufträge + Artikelstamm + registrierte Zähler (Preise, Kategorien).
    func unsentChangeCount() -> Int {
        let items = listViewModel.syncEngine?.pendingOperations ?? 0
        let lists = (self.lists as? OfflineListsRepository)?.store.outbox.count ?? 0
        let catalog = (listViewModel.catalogRepository as? OfflineItemCatalogRepository)?.pendingCount ?? 0
        return items + lists + catalog + unsentChangeCounters.reduce(0) { $0 + $1() }
    }
}
