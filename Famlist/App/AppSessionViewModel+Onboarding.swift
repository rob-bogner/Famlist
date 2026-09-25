/*
 AppSessionViewModel+Onboarding.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstieg: Anmeldelink per E-Mail (Magic Link), Mit Apple anmelden, Profil anlegen und Einladung annehmen.

 🔰 Notes for Beginners:
 - Reihenfolge nach dem Öffnen eines Einladungslinks ohne Konto (SPEC §3.8):
   Anmelden → Profil anlegen → Einladung annehmen oder ablehnen → geteilte Liste öffnet sich.
 - „Profil anlegen“ erscheint, solange das Profil noch keinen Benutzernamen hat (`needsProfileSetup`).
 - Passwort-Anmeldung gibt es in der Oberfläche nicht mehr (Roberts Entscheidung F2); nur die
   Simulator-Testkonten nutzen sie noch (DEBUG).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

extension AppSessionViewModel {
    // MARK: - Anmelden

    /// „Weiter mit E-Mail“: Anmeldelink senden. Liefert false bei ungültiger Adresse oder Fehler.
    func sendMagicLink(to raw: String) async -> Bool {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil else {
            errorMessage = "Bitte gib eine gültige E-Mail-Adresse ein."
            return false
        }
        guard let authService else {
            errorMessage = String(localized: "auth.error.noClient")
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.signInWithEmailOTP(email: email)
            errorMessage = nil
            magicLinkSentTo = email
            UserLog.Auth.magicLinkSent(email: email)
            return true
        } catch {
            UserLog.Error.general(message: "Anmeldelink konnte nicht gesendet werden")
            errorMessage = "Der Anmeldelink konnte nicht gesendet werden. Prüfe deine Verbindung."
            return false
        }
    }

    /// „Mit Apple anmelden“: ID-Token an Supabase, danach wie jede Anmeldung weiter.
    func signInWithApple(idToken: String, nonce: String) async {
        guard let authService else { return }
        isLoading = true
        do {
            try await authService.signInWithApple(idToken: idToken, nonce: nonce)
            UserLog.Auth.appleSignIn()
            isLoading = false
            await handleAuthCompletion()
        } catch {
            isLoading = false
            errorMessage = "Anmeldung mit Apple ist fehlgeschlagen."
            logVoid(params: (action: "signInWithApple.error", error: (error as NSError).localizedDescription))
        }
    }

    // MARK: - Profil anlegen

    /// true, solange das Profil noch keinen Benutzernamen hat (neues Konto oder Konto aus der Zeit vor dem Redesign).
    var needsProfileSetup: Bool {
        guard isAuthenticated, let profile = currentProfile else { return false }
        return (profile.username ?? "").isEmpty
    }

    /// Vorschlag für den Benutzernamen aus der E-Mail-Adresse („robert.bogner@…“ → „robert_bogner“).
    var suggestedUsername: String {
        let local = (currentUserEmail ?? "").split(separator: "@").first.map(String.init) ?? ""
        let cleaned = local.lowercased().map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        let ascii = cleaned.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false) ?? cleaned
        let filtered = ascii.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
        return String(filtered.prefix(30))
    }

    // MARK: - Einladung

    /// Lädt Einladenden und Listendaten für „Einladung annehmen“ (RPC invite_preview_by_token).
    /// Ohne Verbindung bleibt der Titel aus dem Link stehen, und die Chips entfallen.
    func loadInvitePreview(_ invite: InvitePayload) async {
        do {
            guard let row = try await lists.invitePreview(token: invite.token) else {
                errorMessage = InviteError.invalidOrExpired.errorDescription
                invitePreview = InvitePreviewInfo(token: invite.token, listId: nil, inviterName: nil,
                                                  listName: invite.listTitle, itemCount: nil, memberCount: nil)
                return
            }
            invitePreview = InvitePreviewInfo(token: invite.token, listId: row.listId, inviterName: row.inviterName,
                                              listName: row.title, itemCount: row.itemCount, memberCount: row.memberCount)
        } catch {
            invitePreview = InvitePreviewInfo(token: invite.token, listId: nil, inviterName: nil,
                                              listName: invite.listTitle, itemCount: nil, memberCount: nil)
        }
    }

    /// „Einladung annehmen“: Mitglied werden und die Liste sofort öffnen.
    func acceptInviteAndOpen(_ invite: InvitePayload) async {
        guard let me = currentProfile else { return }
        let listId: UUID
        do {
            listId = try await lists.acceptInvite(token: invite.token)
            UserLog.Data.listJoined()
        } catch {
            errorMessage = (InviteError.from(error) ?? .acceptFailed).errorDescription
            return
        }
        if let all = try? await lists.fetchAllLists(for: me.id) {
            listViewModel.allLists = all
            if let joined = all.first(where: { $0.id == listId }) { listViewModel.switchToList(joined) }
        }
        pendingInvite = nil
        invitePreview = nil
    }

    func declineInvite() {
        logVoid(params: (action: "declineInvite", hasInvite: pendingInvite != nil))
        pendingInvite = nil
        invitePreview = nil
    }
}
