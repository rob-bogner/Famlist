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
    
    init(client: SupabaseClienting) {
        self.client = client
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
                .select("id, public_id, created_at")
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
            .select("id, public_id, created_at")
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
}

