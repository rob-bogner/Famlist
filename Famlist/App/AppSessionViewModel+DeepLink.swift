/*
 AppSessionViewModel+DeepLink.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Verarbeitet geöffnete Links: Einladungen (famlist://invite) und Supabase-Anmeldelinks.

 📝 Last Change:
 - Aus AppSessionViewModel.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension AppSessionViewModel {
    // MARK: - Deep Link Handler

    /// Handles an incoming deep link URL (invite or Supabase magic-link).
    /// - Parameter url: The URL opened by the system.
    func handleOpenURL(_ url: URL) {
        // Invite: famlist://invite?token=T&listTitle=Z
        if url.scheme == "famlist", url.host == "invite" {
            let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            guard let token = q?.first(where: { $0.name == "token" })?.value, !token.isEmpty else {
                // Alte Links im Format ?listId=… sind seit Migration 014 ungültig.
                logVoid(params: ["action": "handleOpenURL.invite.invalidParams"])
                errorMessage = InviteError.invalidOrExpired.errorDescription
                return
            }
            let listTitle = q?.first(where: { $0.name == "listTitle" })?.value ?? ""
            let invite = InvitePayload(token: token, listTitle: listTitle)
            if isAuthenticated { pendingInvite = invite }
            else { pendingInviteStorage = invite }
            return
        }

        // Auth magic link (existing path)
        guard let authService else { return }
        Task {
            do {
                try await authService.handleOpenURL(url)
                await self.handleAuthCompletion()
            } catch {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}
