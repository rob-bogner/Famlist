/*
 SupabaseListsRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Supabase-backed implementation of ListsRepository.
 🛠 Includes: List CRUD operations and default list management using Supabase client.
 🔰 Notes for Beginners: Isolates Supabase-specific logic from UI/ViewModels.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID, Date.
import Supabase // Brings in Supabase types for queries and builders.

/// Supabase-backed lists repository.
final class SupabaseListsRepository: ListsRepository {
    let client: SupabaseClienting // Facade client.
    
    init(client: SupabaseClienting) {
        self.client = client
    }

    func ensureDefaultListExists(for owner: UUID) async throws -> List {
        // Fetch
        let fetched: [List] = try await client
            .from("lists")
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .eq("owner_id", value: owner.uuidString)
            .eq("is_default", value: true)
            .limit(1)
            .execute()
            .value
        if let row = fetched.first {
            return logResult(params: (owner: owner, hit: true), result: row)
        }
        // Insert when none exists - explicitly set owner_id to avoid RLS violations
        struct NewList: Codable {
            let owner_id: String
            let title: String
            let is_default: Bool
        }
        let insert = NewList(owner_id: owner.uuidString, title: "My List", is_default: true)
        let inserted: List = try await client
            .from("lists")
            .insert(insert)
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .single()
            .execute()
            .value
        return logResult(params: (owner: owner, created: true), result: inserted)
    }

    /// Fetches the default list as an app-level ListModel; creates it if missing.
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel {
        // Row mapping for precise column selection
        struct ListRow: Codable {
            let id: UUID
            let owner_id: UUID
            let title: String
            let is_default: Bool
            let created_at: Date
            let updated_at: Date?
        }
        // Helper to map DB row -> ListModel with updatedAt fallback
        func map(_ r: ListRow) -> ListModel {
            ListModel(
                id: r.id,
                ownerId: r.owner_id,
                title: r.title,
                isDefault: r.is_default,
                createdAt: r.created_at,
                updatedAt: r.updated_at ?? r.created_at
            )
        }
        // 1) Try fetch default for owner
        let fetched: [ListRow] = try await client
            .from("lists")
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .eq("owner_id", value: ownerId.uuidString)
            .eq("is_default", value: true)
            .limit(1)
            .execute()
            .value
        if let row = fetched.first {
            let result = map(row)
            let finalResult = logResult(params: (ownerId: ownerId, hit: true), result: result)
            UserLog.Data.listLoaded(name: result.title, itemCount: 0)
            return finalResult
        }
        
        UserLog.Data.loadingList()
        // 2) Not found -> insert default with explicit owner_id to avoid RLS violations.
        struct NewList: Codable {
            let owner_id: String
            let title: String
            let is_default: Bool
        }
        let payload = NewList(owner_id: ownerId.uuidString, title: "My List", is_default: true)
        let inserted: ListRow = try await client
            .from("lists")
            .insert(payload)
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .single()
            .execute()
            .value
        let result = map(inserted)
        let finalResult = logResult(params: (ownerId: ownerId, created: true), result: result)
        UserLog.Data.listLoaded(name: result.title, itemCount: 0)
        return finalResult
    }

    func observeLists(for owner: UUID) -> AsyncStream<[List]> {
        let stream = AsyncStream { continuation in
            Task {
                let rows: [List] = try await client
                    .from("lists")
                    .select()
                    .eq("owner_id", value: owner.uuidString)
                    .order("created_at")
                    .execute()
                    .value
                continuation.yield(rows)
                continuation.finish()
            }
        }
        return logResult(params: ["owner": owner], result: stream)
    }

    func createList(for owner: UUID, title: String) async throws -> List {
        struct NewList: Codable {
            let owner_id: UUID
            let title: String
        }
        let value: List = try await client
            .from("lists")
            .insert(NewList(owner_id: owner, title: title))
            .select()
            .single()
            .execute()
            .value
        let result = logResult(params: (owner: owner, title: title), result: value)
        UserLog.Data.listCreated(name: title)
        return result
    }

    func addMember(listId: UUID, profileId: UUID) async throws {
        struct LM: Codable {
            let list_id: UUID
            let profile_id: UUID
        }
        _ = try await client
            .from("list_members")
            .insert(LM(list_id: listId, profile_id: profileId))
            .execute()
        logVoid(params: (listId: listId, profileId: profileId))
    }

    func removeMember(listId: UUID, profileId: UUID) async throws {
        _ = try await client
            .from("list_members")
            .delete()
            .eq("list_id", value: listId.uuidString)
            .eq("profile_id", value: profileId.uuidString)
            .execute()
        logVoid(params: (listId: listId, profileId: profileId))
    }
}

