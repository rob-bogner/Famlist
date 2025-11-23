/*
 SupabaseCategoriesRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Supabase-backed implementation of CategoriesRepository.
 🛠 Includes: Category CRUD operations using Supabase client.
 🔰 Notes for Beginners: Isolates Supabase-specific logic from UI/ViewModels.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.
import Supabase // Brings in Supabase types for queries and builders.

/// Supabase-backed categories repository.
final class SupabaseCategoriesRepository: CategoriesRepository {
    let client: SupabaseClienting // Facade client.
    
    init(client: SupabaseClienting) {
        self.client = client
    }

    func all(for profileId: UUID?) async throws -> [Category] {
        var query = client.from("categories").select()
        if let profileId {
            query = query.or("profile_id.eq.\(profileId.uuidString),profile_id.is.null")
        }
        let result: [Category] = try await query
            .order("name", ascending: true)
            .execute()
            .value
        return logResult(params: ["profileId": profileId as Any], result: result)
    }

    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category {
        struct New: Codable {
            let name: String
            let emoji: String?
            let color_hex: String?
        }
        let result: Category = try await client
            .from("categories")
            .insert(New(name: name, emoji: emoji, color_hex: colorHex))
            .select()
            .single()
            .execute()
            .value
        return logResult(params: (name: name, emoji: emoji as Any, colorHex: colorHex as Any), result: result)
    }
}

