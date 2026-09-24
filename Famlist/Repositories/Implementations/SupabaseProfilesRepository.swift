/*
 SupabaseProfilesRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Supabase-backed implementation of ProfilesRepository.
 🛠 Includes: Profile CRUD operations using Supabase client.
 🔰 Notes for Beginners: Isolates Supabase-specific logic from UI/ViewModels.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.
import Supabase // Brings in Supabase types for queries and builders.

/// Supabase-backed profiles repository.
final class SupabaseProfilesRepository: ProfilesRepository {
    let client: SupabaseClienting // Facade client used for queries.
    
    /// Spalten, die die App braucht (Migration 009 ergänzt Favorit und Benachrichtigungen).
    static let columns = "id, public_id, username, full_name, avatar_url, created_at, updated_at, favorite_list_id, notify_shared_lists, notify_invites"

    init(client: SupabaseClienting) {
        self.client = client
    }

    private func myId() async throws -> UUID {
        if let id = client.auth.currentUser?.id { return id }
        return try await client.auth.session.user.id
    }

    func upsertProfile(authUserId: UUID, publicId: String) async throws {
        struct Row: Codable {
            let id: UUID
            let public_id: String
        }
        let row = Row(id: authUserId, public_id: publicId)
        _ = try await client.from("profiles").upsert(row).execute()
        logVoid(params: (authUserId: authUserId, publicId: publicId))
    }

    func myProfile() async throws -> Profile {
        UserLog.Auth.loadingProfile() // User-Log einmalig am Anfang
        
        // Resolve authenticated user id from the in-memory user or by awaiting the active session
        if let currentId = client.auth.currentUser?.id {
            let profile: Profile = try await client
                .from("profiles")
                .select(Self.columns)
                .eq("id", value: currentId.uuidString)
                .single()
                .execute()
                .value
            let result = logResult(params: ["source": "currentUser"], result: profile)
            UserLog.Auth.profileLoaded(publicId: profile.publicId)
            return result
        }
        // Fallback: try to read/restore session asynchronously and use its user id
        guard let session = try? await client.auth.session else {
            throw AuthError.unauthenticated
        }
        let uid = session.user.id
        let profile: Profile = try await client
            .from("profiles")
            .select(Self.columns)
            .eq("id", value: uid.uuidString)
            .single()
            .execute()
            .value
        let result = logResult(params: ["source": "session"], result: profile)
        UserLog.Auth.profileLoaded(publicId: profile.publicId)
        return result
    }

    func profileByPublicId(_ publicId: String) async throws -> Profile? {
        let rows: [Profile] = try await client
            .from("profiles")
            .select()
            .eq("public_id", value: publicId)
            .limit(1)
            .execute()
            .value
        let result = rows.first
        return logResult(params: ["publicId": publicId], result: result)
    }

    func profile(id: UUID) async throws -> Profile? {
        let rows: [Profile] = try await client.from("profiles").select(Self.columns)
            .eq("id", value: id.uuidString).limit(1).execute().value
        return rows.first
    }

    func updateProfile(username: String, fullName: String?) async throws {
        struct Row: Encodable {
            let username: String
            let full_name: String?
            let updated_at: Date
        }
        let id = try await myId()
        let name = fullName?.trimmingCharacters(in: .whitespaces)
        try await client.from("profiles")
            .update(Row(username: username, full_name: (name?.isEmpty ?? true) ? nil : name, updated_at: Date()))
            .eq("id", value: id.uuidString).execute()
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        struct Row: Decodable { let id: UUID }
        let id = try await myId()
        let rows: [Row] = try await client.from("profiles").select("id")
            .ilike("username", pattern: username).limit(2).execute().value
        return rows.allSatisfy { $0.id == id }
    }

    func setFavoriteList(_ listId: UUID?) async throws {
        struct Row: Encodable {
            let favorite_list_id: UUID?
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(favorite_list_id, forKey: .favorite_list_id)     // explizit null
            }
            enum CodingKeys: String, CodingKey { case favorite_list_id }
        }
        let id = try await myId()
        try await client.from("profiles").update(Row(favorite_list_id: listId))
            .eq("id", value: id.uuidString).execute()
    }

    func updateNotifications(sharedLists: Bool, invites: Bool) async throws {
        struct Row: Encodable {
            let notify_shared_lists: Bool
            let notify_invites: Bool
        }
        let id = try await myId()
        try await client.from("profiles").update(Row(notify_shared_lists: sharedLists, notify_invites: invites))
            .eq("id", value: id.uuidString).execute()
    }

    func uploadAvatar(_ jpeg: Data) async throws -> String {
        struct Row: Encodable { let avatar_url: String }
        let id = try await myId()
        let path = "\(id.uuidString.lowercased())/avatar.jpg"
        try await client.storageUpload(bucket: "avatars", path: path, data: jpeg, contentType: "image/jpeg")
        try await client.from("profiles").update(Row(avatar_url: path)).eq("id", value: id.uuidString).execute()
        return path
    }

    func avatarURL(path: String) async throws -> URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: try await client.storageCreateSignedURL(bucket: "avatars", path: path, expiresIn: 3600))
    }

    func deleteAccount() async throws {
        let id = try await myId()
        // Storage-Dateien zuerst über die Storage-API (direktes SQL-DELETE auf storage.objects ist gesperrt).
        try? await client.storageRemove(bucket: "avatars", paths: ["\(id.uuidString.lowercased())/avatar.jpg"])
        try await client.rpc("delete_my_account")
    }
}
