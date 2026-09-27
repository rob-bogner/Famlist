/*
 AppSessionViewModel+Archive.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Konto-Archiv (Migrationen 027/028): gelöschtes Konto erkennen, wiederherstellen, sofort endgültig löschen,
   Ereignisse des Kanals `user:<id>` und Hinweise „Mitglied hat sein Konto gelöscht“.

 🔰 Notes for Beginners:
 - „Konto löschen“ archiviert das Konto 60 Tage. Wer sich in dieser Zeit anmeldet, landet auf RestoreAccountView
   (RootView prüft `archivedAccount`). Bis dahin lädt die App keine Listen und legt nichts an.
 - Wird das Konto auf einem anderen Gerät gelöscht, meldet sich dieses Gerät ab (Ereignis account_archived).
 - Hinweise für Listenbesitzer kommen per Realtime und werden beim Start nachgeladen (falls man offline war).
 - Alle Server-Aufrufe hier brauchen Netz; ohne Verbindung bleibt alles, wie es ist.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3/4).
 ------------------------------------------------------------------------
 */

import Foundation

extension AppSessionViewModel {
    // MARK: - Erkennen

    /// Fragt den Archivzustand ab. Archiviert → Restore-Screen, Rückgabe true. Offline/Fehler → false (normaler Start).
    func enterArchiveIfNeeded() async -> Bool {
        guard let accounts, ConnectivityMonitor.shared.isOnline else { return false }
        do {
            guard let status = try await accounts.status() else { return false }
            showArchived(status)
            return true
        } catch {
            logVoid(params: (action: "archiveStatus.error", error: (error as NSError).localizedDescription))
            return false
        }
    }

    /// Start aus der lokalen Kopie lief schon: Ist das Konto inzwischen gelöscht, lokale Daten verwerfen.
    func checkArchiveInBackground() async {
        guard let accounts, ConnectivityMonitor.shared.isOnline,
              let status = try? await accounts.status() else { return }
        resetLocalState()
        showArchived(status)
    }

    private func showArchived(_ status: AccountArchiveStatus) {
        archivedAccount = status
        isAuthenticated = true
        UserLog.Auth.archivedAccountFound(purgeDate: Self.archiveDateText(status.purgeAfter))
    }

    /// Datum wie im Design: 26.11.2026.
    static func archiveDateText(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(Locale(identifier: "de_DE")))
    }

    // MARK: - Wiederherstellen / endgültig löschen

    /// „Konto wiederherstellen“: danach normaler Start. Liefert false bei Fehler (Konto bleibt archiviert).
    func restoreArchivedAccount() async -> Bool {
        guard let accounts else { return false }
        do {
            _ = try await accounts.restore()
            UserLog.Auth.accountRestored()
            archivedAccount = nil
            await handleAuthCompletion()
            return true
        } catch {
            UserLog.Auth.accountRestoreFailed(reason: UserFacingError.message(for: error))
            logVoid(params: (action: "restore.error", error: (error as NSError).localizedDescription))
            return false
        }
    }

    /// „Jetzt endgültig löschen“: löscht sofort alles (Edge Function purge-my-account) und meldet ab.
    func purgeArchivedAccount() async -> Bool {
        guard let accounts else { return false }
        do {
            try await accounts.purge()
        } catch {
            logVoid(params: (action: "purge.error", error: (error as NSError).localizedDescription))
            return false
        }
        UserLog.Auth.accountPurged()
        try? await authService?.signOut()
        resetLocalState()
        isAuthenticated = false
        return true
    }

    // MARK: - Ereignisse des Kanals user:<id>

    func handleUserEvent(_ event: UserChannelEvent) {
        switch event {
        case .accountArchived:
            guard !isDeletingAccount else { return }
            Task { await signOutAfterRemoteArchive() }
        case .memberRestored:
            if let me = currentProfile { listViewModel.loadAllLists(ownerId: me.id) }
        case .memberArchived(let notice):
            if !accountNotices.contains(where: { $0.id == notice.id }) { accountNotices.append(notice) }
        case .memberRemoved:
            break                                               // erledigt das ListViewModel
        }
    }

    /// Konto wurde auf einem anderen Gerät gelöscht: abmelden, lokale Daten entfernen.
    private func signOutAfterRemoteArchive() async {
        logVoid(params: ["action": "remoteArchive"])
        try? await authService?.signOut()
        resetLocalState()
        isAuthenticated = false
        errorMessage = "Dein Konto wurde auf einem anderen Gerät gelöscht. Melde dich an, um es wiederherzustellen."
    }

    // MARK: - Hinweise für Listenbesitzer

    func loadAccountNotices() async {
        guard let accounts, let notices = try? await accounts.unseenNotices() else { return }
        for notice in notices where !accountNotices.contains(where: { $0.id == notice.id }) {
            accountNotices.append(notice)
        }
    }

    /// Hinweis wurde gezeigt: entfernen und beim Server als gesehen markieren (nur einmal anzeigen).
    func markNoticeSeen(_ notice: AccountNotice) {
        accountNotices.removeAll { $0.id == notice.id }
        UserLog.Data.memberDeletedAccountShown(name: notice.subjectName)
        guard let accounts else { return }
        Task { try? await accounts.markNoticeSeen(notice.id) }
    }
}
