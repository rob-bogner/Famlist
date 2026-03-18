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
                do {
                    let rows: [List] = try await client
                        .from("lists")
                        .select()
                        .eq("owner_id", value: owner.uuidString)
                        .order("created_at")
                        .execute()
                        .value
                    continuation.yield(rows)
                } catch {
                    logVoid(params: (action: "observeLists.error", owner: owner, error: error.localizedDescription))
                }
                // finish() wird immer aufgerufen – verhindert hängenden Stream bei Fehler.
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

    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel] {
        struct ListRow: Codable {
            let id: UUID
            let owner_id: UUID
            let title: String
            let is_default: Bool
            let created_at: Date
            let updated_at: Date?
        }
        let rows: [ListRow] = try await client
            .from("lists")
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .order("created_at")   // RLS filtert automatisch: owned + member lists
            .execute()
            .value
        let result = rows.map { r in
            ListModel(
                id: r.id,
                ownerId: r.owner_id,
                title: r.title,
                isDefault: r.is_default,
                createdAt: r.created_at,
                updatedAt: r.updated_at ?? r.created_at
            )
        }
        return logResult(params: (ownerId: ownerId, count: result.count), result: result)
    }

    func renameList(listId: UUID, title: String) async throws -> ListModel {
        struct Patch: Codable { let title: String; let updated_at: Date }
        struct ListRow: Codable {
            let id: UUID; let owner_id: UUID; let title: String
            let is_default: Bool; let created_at: Date; let updated_at: Date?
        }
        let row: ListRow = try await client
            .from("lists")
            .update(Patch(title: title, updated_at: Date()))
            .eq("id", value: listId.uuidString)
            .select("id, owner_id, title, is_default, created_at, updated_at")
            .single()
            .execute()
            .value
        let result = ListModel(
            id: row.id, ownerId: row.owner_id, title: row.title,
            isDefault: row.is_default, createdAt: row.created_at,
            updatedAt: row.updated_at ?? row.created_at
        )
        return logResult(params: (listId: listId, title: title), result: result)
    }

    func deleteList(listId: UUID) async throws {
        _ = try await client
            .from("lists")
            .delete()
            .eq("id", value: listId.uuidString)
            .execute()
        logVoid(params: (action: "deleteList", listId: listId))
    }

    func setDefaultList(listId: UUID, ownerId: UUID) async throws {
        struct UnsetPatch: Codable { let is_default: Bool; let updated_at: Date }
        struct SetPatch: Codable { let is_default: Bool; let updated_at: Date }
        _ = try await client
            .from("lists")
            .update(UnsetPatch(is_default: false, updated_at: Date()))
            .eq("owner_id", value: ownerId.uuidString)
            .execute()
        _ = try await client
            .from("lists")
            .update(SetPatch(is_default: true, updated_at: Date()))
            .eq("id", value: listId.uuidString)
            .execute()
        logVoid(params: (listId: listId, ownerId: ownerId))
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

    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }

            let channelId = "private:list_members:\(userId.uuidString)"
            let channel = client.realtime.channel(channelId)

            let deletions = channel.postgresChange(
                DeleteAction.self,
                schema: "public",
                table: "list_members",
                filter: .eq("profile_id", value: userId.uuidString)
            )

            let task = Task {
                do {
                    try await channel.subscribeWithError()
                    for await deletion in deletions {
                        // PK (list_id, profile_id) ist immer im oldRecord enthalten
                        if let raw = deletion.oldRecord["list_id"],
                           let listIdString: String = {
                               let s = String(describing: raw)
                               return s == "<null>" ? nil : s.replacingOccurrences(of: "AnyJSON.", with: "")
                           }(),
                           let listId = UUID(uuidString: listIdString) {
                            continuation.yield(listId)
                        }
                    }
                } catch {
                    logVoid(params: (action: "observeMemberRemovals.subscribeError",
                                     error: (error as NSError).localizedDescription))
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                Task { await channel.unsubscribe() }
            }
        }
    }

    func fetchMembers(listId: UUID) async throws -> [ListMember] {
        // 1. Hole profile_ids + added_at aus list_members
        struct MemberRow: Codable {
            let profile_id: UUID
            let added_at: Date
        }
        let memberRows: [MemberRow] = try await client
            .from("list_members")
            .select("profile_id, added_at")
            .eq("list_id", value: listId.uuidString)
            .execute()
            .value

        guard !memberRows.isEmpty else { return [] }

        // 2. Hole Profil-Daten für alle profile_ids
        // Kein PostgREST-Join möglich (kein FK profile_id → profiles.id) → zwei Queries
        struct ProfileRow: Codable {
            let id: UUID
            let public_id: String?
            let username: String?
            let full_name: String?
        }
        let profileIds = memberRows.map { $0.profile_id.uuidString }
        let profileRows: [ProfileRow] = try await client
            .from("profiles")
            .select("id, public_id, username, full_name")
            .in("id", values: profileIds)
            .execute()
            .value

        // 3. Join in Memory
        let profileMap = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id, $0) })
        let result = memberRows.compactMap { member -> ListMember? in
            guard let profile = profileMap[member.profile_id] else { return nil }
            return ListMember(
                id: member.profile_id,
                publicId: profile.public_id ?? "",
                username: profile.username,
                fullName: profile.full_name,
                addedAt: member.added_at
            )
        }
        return logResult(params: (listId: listId, count: result.count), result: result)
    }
}

