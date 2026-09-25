/*
 AppSessionViewModel+Account.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Konto-Aktionen für Einstellungen, Profil bearbeiten, Profil anlegen und Listen-Optionen:
   Favorit, Profil speichern, Benutzername prüfen, Profilfoto, Benachrichtigungen, Konto löschen.

 🔰 Notes for Beginners:
 - Favorit = profiles.favorite_list_id (pro Nutzer). Ohne Favorit gilt die Standard-Liste (is_default).
 - Profilfotos liegen im privaten Bucket `avatars`; angezeigt werden sie über signierte Links.
 - Konto löschen ruft delete_my_account() auf (Migration 009) und meldet danach lokal ab.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UserNotifications

extension AppSessionViewModel {
    /// Ergebnis der Live-Prüfung des Benutzernamens (Profil anlegen / bearbeiten).
    enum UsernameCheck: Equatable {
        case empty
        case invalid
        case checking
        case available
        case taken
        case unknown          // offline / Fehler
    }

    // MARK: - Start-Liste

    /// Favorit, sonst Standard-Liste (wird beim Start geöffnet).
    func startList(for me: Profile) async throws -> ListModel {
        if let favoriteId = me.favoriteListId,
           let all = try? await lists.fetchAllLists(for: me.id),
           let favorite = all.first(where: { $0.id == favoriteId }) {
            return favorite
        }
        return try await lists.fetchDefaultList(for: me.id)
    }

    // MARK: - Favorit

    func isFavorite(_ list: ListModel) -> Bool {
        if let favorite = currentProfile?.favoriteListId { return favorite == list.id }
        return list.isDefault && list.ownerId == currentProfile?.id
    }

    /// Listen-Optionen „Als Favorit markieren“ / „Favorit entfernen“ (optimistisch, Rücknahme bei Fehler).
    func toggleFavorite(_ list: ListModel) {
        guard let me = currentProfile else { return }
        let newValue: UUID? = isFavorite(list) ? nil : list.id
        setFavorite(newValue, profile: me, listTitle: list.title)
    }

    func setFavorite(_ listId: UUID?, profile me: Profile, listTitle: String) {
        currentProfile = me.with(favoriteListId: .some(listId))
        UserLog.Data.listSetDefault(name: listId == nil ? "–" : listTitle)
        // Nacheinander senden: Zwei schnelle Tipps dürfen beim Server nicht vertauscht ankommen.
        let previous = favoriteWriteTask
        favoriteWriteTask = Task {
            await previous?.value
            do {
                try await profiles.setFavoriteList(listId)
            } catch {
                currentProfile = me
                errorMessage = "Favorit konnte nicht gespeichert werden."
            }
        }
    }

    // MARK: - Profil

    /// Benutzername: 3–30 Zeichen, nur Buchstaben, Zahlen und _ (Hinweis im Design).
    static func isValidUsername(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z0-9_]{3,30}$", options: .regularExpression) != nil
    }

    func checkUsername(_ raw: String) async -> UsernameCheck {
        let name = raw.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return .empty }
        guard Self.isValidUsername(name) else { return .invalid }
        if name.caseInsensitiveCompare(currentProfile?.username ?? "") == .orderedSame { return .available }
        do {
            return try await profiles.isUsernameAvailable(name) ? .available : .taken
        } catch {
            return .unknown
        }
    }

    /// Speichert Benutzername und Namen. Liefert false bei Fehler (z. B. Name inzwischen vergeben).
    func saveProfile(username: String, fullName: String) async -> Bool {
        guard let me = currentProfile, Self.isValidUsername(username) else { return false }
        do {
            try await profiles.updateProfile(username: username, fullName: fullName)
            let trimmed = fullName.trimmingCharacters(in: .whitespaces)
            currentProfile = me.with(username: .some(username), fullName: .some(trimmed.isEmpty ? nil : trimmed))
            UserLog.Auth.profileUpdated(username: username)
            return true
        } catch {
            errorMessage = "Profil konnte nicht gespeichert werden."
            return false
        }
    }

    /// Profilfoto: auf 512 px verkleinern, als JPEG hochladen, sofort anzeigen.
    func uploadAvatar(_ image: UIImage) {
        guard let me = currentProfile, let jpeg = image.famlistAvatarJPEG() else { return }
        let previous = avatarImage
        avatarImage = UIImage(data: jpeg)
        Task {
            do {
                let path = try await profiles.uploadAvatar(jpeg)
                currentProfile = me.with(avatarUrl: .some(path))
                UserLog.Auth.avatarUpdated()
            } catch {
                avatarImage = previous
                errorMessage = "Foto konnte nicht hochgeladen werden."
            }
        }
    }

    /// Lädt das Profilfoto über einen signierten Link.
    func loadAvatar() async {
        guard let path = currentProfile?.avatarUrl, !path.isEmpty,
              let url = try? await profiles.avatarURL(path: path),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        avatarImage = UIImage(data: data)
    }

    // MARK: - Benachrichtigungen

    func updateNotifications(sharedLists: Bool, invites: Bool) {
        guard let me = currentProfile else { return }
        currentProfile = me.with(notifySharedLists: .some(sharedLists), notifyInvites: .some(invites))
        if sharedLists || invites {
            // Beim Einschalten die Systemberechtigung anfragen (einmalig; danach entscheidet iOS).
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
        Task {
            do {
                try await profiles.updateNotifications(sharedLists: sharedLists, invites: invites)
            } catch {
                currentProfile = me
                errorMessage = "Einstellung konnte nicht gespeichert werden."
            }
        }
    }

    // MARK: - Konto löschen

    /// Löscht alle eigenen Daten im Backend und meldet ab. Liefert false bei Fehler.
    func deleteAccount() async -> Bool {
        do {
            try await profiles.deleteAccount()
            UserLog.Auth.accountDeleted()
            try? await authService?.signOut()
            listViewModel.clearForSignOut()
            currentProfile = nil
            avatarImage = nil
            isAuthenticated = false
            return true
        } catch {
            errorMessage = "Konto konnte nicht gelöscht werden. Bitte versuche es erneut."
            logVoid(params: (action: "deleteAccount.error", error: (error as NSError).localizedDescription))
            return false
        }
    }
}

private extension UIImage {
    /// Quadratisch zugeschnitten, 512 × 512, JPEG 0,8.
    func famlistAvatarJPEG() -> Data? {
        let side = min(size.width, size.height)
        let crop = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
        let target = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: target)
        let scaled = renderer.image { _ in
            draw(in: CGRect(x: -crop.minX * target.width / side, y: -crop.minY * target.height / side,
                            width: size.width * target.width / side, height: size.height * target.height / side))
        }
        return scaled.jpegData(compressionQuality: 0.8)
    }
}
