/*
 Profile.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: User profile model representing a row from the profiles table.
 🛠 Includes: Profile struct with Codable, Identifiable, Hashable conformance.
 🔰 Notes for Beginners: Used by ProfilesRepository to represent authenticated user profiles.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID, Date, and Codable support.

/// Represents a user profile from the profiles table.
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    let publicId: String
    let username: String?
    let fullName: String?
    /// Pfad im privaten Storage-Bucket `avatars` („<uid>/avatar.jpg“), nicht die öffentliche URL.
    let avatarUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    /// Favorit „öffnet beim App-Start“ (Migration 009).
    let favoriteListId: UUID?
    /// Einstellungen → Benachrichtigungen (Migration 009); nil = Standard „an“.
    let notifySharedLists: Bool?
    let notifyInvites: Bool?

    init(id: UUID, publicId: String, username: String?, fullName: String?, avatarUrl: String?,
         createdAt: Date?, updatedAt: Date?, favoriteListId: UUID? = nil,
         notifySharedLists: Bool? = nil, notifyInvites: Bool? = nil) {
        self.id = id
        self.publicId = publicId
        self.username = username
        self.fullName = fullName
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.favoriteListId = favoriteListId
        self.notifySharedLists = notifySharedLists
        self.notifyInvites = notifyInvites
    }

    enum CodingKeys: String, CodingKey {
        case id
        case publicId = "public_id"
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case favoriteListId = "favorite_list_id"
        case notifySharedLists = "notify_shared_lists"
        case notifyInvites = "notify_invites"
    }

    /// Anzeigename: voller Name, sonst Benutzername, sonst öffentliche ID.
    var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        if let username, !username.isEmpty { return username }
        return publicId
    }

    /// Initiale für den Avatar.
    var initial: String { String(displayName.prefix(1)).uppercased() }
}

extension Profile {
    /// Kopie mit geänderten Feldern (Profile ist unveränderlich).
    func with(username: String?? = nil, fullName: String?? = nil, avatarUrl: String?? = nil,
              favoriteListId: UUID?? = nil, notifySharedLists: Bool?? = nil, notifyInvites: Bool?? = nil) -> Profile {
        Profile(id: id, publicId: publicId,
                username: username ?? self.username,
                fullName: fullName ?? self.fullName,
                avatarUrl: avatarUrl ?? self.avatarUrl,
                createdAt: createdAt, updatedAt: Date(),
                favoriteListId: favoriteListId ?? self.favoriteListId,
                notifySharedLists: notifySharedLists ?? self.notifySharedLists,
                notifyInvites: notifyInvites ?? self.notifyInvites)
    }
}
