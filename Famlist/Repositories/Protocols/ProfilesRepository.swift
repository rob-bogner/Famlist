/*
 ProfilesRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Protocol defining profile-related repository operations.
 🛠 Includes: ProfilesRepository protocol with upsert, fetch, and lookup methods.
 🔰 Notes for Beginners: Allows swapping between Supabase and preview implementations.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.

/// Profile-related operations.
protocol ProfilesRepository {
    /// Create or update current profile.
    /// - Parameters:
    ///   - authUserId: The authenticated user's UUID.
    ///   - publicId: The public identifier for sharing.
    func upsertProfile(authUserId: UUID, publicId: String) async throws
    
    /// Fetch current profile.
    /// - Returns: The current user's profile.
    /// - Throws: AuthError.unauthenticated if no user is logged in.
    func myProfile() async throws -> Profile
    
    /// Profil über die ID (z. B. Eigentümer einer geteilten Liste).
    func profile(id: UUID) async throws -> Profile?

    /// Profil bearbeiten / anlegen: Benutzername und optional voller Name.
    func updateProfile(username: String, fullName: String?) async throws

    /// Live-Prüfung „frei“: true, wenn kein ANDERES Profil diesen Benutzernamen trägt.
    func isUsernameAvailable(_ username: String) async throws -> Bool

    /// Favorit „öffnet beim App-Start“ setzen (nil = kein Favorit).
    func setFavoriteList(_ listId: UUID?) async throws

    /// Einstellungen → Benachrichtigungen.
    func updateNotifications(sharedLists: Bool, invites: Bool) async throws

    /// Profilfoto hochladen (JPEG); liefert den Pfad im Bucket `avatars`.
    func uploadAvatar(_ jpeg: Data) async throws -> String

    /// Signierter Link zum Profilfoto (1 h gültig).
    func avatarURL(path: String) async throws -> URL?

    /// Konto löschen: Profilfoto entfernen, dann RPC delete_my_account (App-Store-Pflicht).
    func deleteAccount() async throws
}

extension ProfilesRepository {
    // Standard-Implementierungen, damit Test-Doubles und Vorschauen nur das Nötige überschreiben.
    func profile(id: UUID) async throws -> Profile? { nil }
    func updateProfile(username: String, fullName: String?) async throws {}
    func isUsernameAvailable(_ username: String) async throws -> Bool { true }
    func setFavoriteList(_ listId: UUID?) async throws {}
    func updateNotifications(sharedLists: Bool, invites: Bool) async throws {}
    func uploadAvatar(_ jpeg: Data) async throws -> String { "" }
    func avatarURL(path: String) async throws -> URL? { nil }
    func deleteAccount() async throws {}
}

