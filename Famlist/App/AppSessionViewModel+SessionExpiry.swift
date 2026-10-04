/*
 AppSessionViewModel+SessionExpiry.swift
 Famlist
 Created on: 04.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Erkennt eine Anmeldung, die auf dem Server ungültig geworden ist (Konto gelöscht, auf einem anderen
   Gerät überall abgemeldet), und schickt zur Anmeldung zurück – mit Hinweis und ohne die offene Einladung
   zu verlieren.

 🔰 Notes for Beginners:
 - Das SDK (supabase-swift 2.55.3) löscht die gespeicherte Anmeldung selbst, wenn der Server beim Erneuern
   `refresh_token_not_found`, `session_not_found` o. Ä. meldet, und sendet `.signedOut`. Vorher hat die App
   diese Meldung nur protokolliert und blieb „angemeldet“: Jede Anfrage lief dann ohne Anmeldung und
   scheiterte (Meldung von Robert 04.10.2026: Einladung ließ sich nicht annehmen).
 - Die lokalen Daten bleiben erhalten, damit ungesendete Änderungen nach erneuter Anmeldung desselben Kontos
   noch ankommen. Meldet sich ein anderes Konto an, werden sie vorher gelöscht (Merker in LocalAccountData).
 - Ein Abmelden aus der App löst ebenfalls `.signedOut` aus; AuthService markiert es, damit hier kein
   Hinweis „Anmeldung abgelaufen“ erscheint.

 📝 Last Change:
 - Initial creation (04.10.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension AppSessionViewModel {
    /// Hört auf die Anmelde-Ereignisse des SDK. Ohne Client (Vorschauen, Tests) passiert nichts.
    func startObservingAuthState() {
        guard let authService else { return }
        let changes = authService.client.auth.authStateChanges
        authStateTask = Task { [weak self] in
            for await change in changes where change.event == .signedOut {
                self?.handleSignedOutBySDK()
            }
        }
    }

    /// Das SDK hat die Anmeldung gelöscht. Kam das nicht von einem Abmelden in der App, ist sie abgelaufen.
    func handleSignedOutBySDK() {
        if authService?.consumeExpectedSignOut() == true { return }
        guard isAuthenticated else { return }
        markSessionExpired(userId: currentProfile?.id)
        pendingInviteStorage = pendingInvite ?? pendingInviteStorage
        pendingInvite = nil
        invitePreview = nil
        isAuthenticated = false
    }

    /// Hinweis zeigen und das Konto merken, dessen Daten noch auf dem Gerät liegen.
    func markSessionExpired(userId: UUID?) {
        if let userId { LocalAccountData.setExpiredSessionUserId(userId) }
        errorMessage = UserFacingError.sessionExpired
        UserLog.Auth.sessionExpired()
        logVoid(params: (action: "sessionExpired", hasUserId: userId != nil))
    }

    /// Vor dem Laden nach einer Anmeldung: Gehören die Daten auf dem Gerät einem anderen Konto, weg damit.
    /// Die offene Einladung bleibt erhalten.
    func discardDataOfExpiredSession() {
        guard let expired = LocalAccountData.expiredSessionUserId() else { return }
        LocalAccountData.setExpiredSessionUserId(nil)
        guard expired != authService?.currentUserId else { return }
        let invite = pendingInviteStorage
        resetLocalState()
        pendingInviteStorage = invite
        logVoid(params: ["action": "discardDataOfExpiredSession"])
    }
}
