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
        let model = try await ensureDefaultList(id: UUID(), for: owner)
        return List(id: model.id, owner_id: model.ownerId, title: model.title, is_default: model.isDefault,
                    created_at: model.createdAt, updated_at: model.updatedAt)
    }

    /// Standardliste atomar sicherstellen (RPC ensure_default_list, Migration 018): höchstens eine je Besitzer,
    /// auch wenn zwei Geräte gleichzeitig starten.
    func ensureDefaultList(id: UUID, for owner: UUID) async throws -> ListModel {
        struct Params: Encodable, Sendable { let p_id: UUID }
        let rows: [ListRow] = try await client.rpcRows("ensure_default_list", params: Params(p_id: id))
        guard let row = rows.first else { throw URLError(.cannotParseResponse) }
        return logResult(params: (owner: owner, requestedId: id), result: row.model)
    }

    /// Fetches the default list as an app-level ListModel; creates it if missing (atomar, siehe oben).
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel {
        try await ensureDefaultList(id: UUID(), for: ownerId)
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
        try await createList(id: UUID(), for: owner, title: title)
    }

    /// Anlegen mit einer auf dem Gerät vergebenen ID (Offline-First, OfflineListsRepository).
    func createList(id: UUID, for owner: UUID, title: String) async throws -> List {
        struct NewList: Codable {
            let id: UUID
            let owner_id: UUID
            let title: String
        }
        let value: List = try await client
            .from("lists")
            .insert(NewList(id: id, owner_id: owner, title: title))
            .select()
            .single()
            .execute()
            .value
        return logResult(params: (owner: owner, title: title), result: value)
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

    /// Standardliste in EINER Transaktion umstellen (RPC set_default_list, Migration 018).
    func setDefaultList(listId: UUID, ownerId: UUID) async throws {
        struct Params: Encodable, Sendable { let p_list_id: UUID }
        let _: Bool = try await client.rpcValue("set_default_list", params: Params(p_list_id: listId))
        logVoid(params: (action: "setDefaultList", listId: listId))
    }

    func leaveList(listId: UUID, profileId: UUID) async throws {
        try await removeMember(listId: listId, profileId: profileId)
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

    /// „Du wurdest aus einer Liste entfernt“ kommt als privater Broadcast an `user:<id>`
    /// (Trigger on_list_member_removed, Migration 014). Postgres Changes auf list_members
    /// gingen nicht: DELETE-Events lassen sich dort nicht filtern und erreichten alle Nutzer.
    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }

            let channel = client.realtime.channel("user:\(userId.uuidString.lowercased())") {
                $0.isPrivate = true
            }
            let removals = channel.broadcastStream(event: "member_removed")

            let task = Task {
                // Anmelden mit Wiederholung wie bei den Listen-Kanälen; vorher blieb es nach einem
                // Fehlschlag beim einen Versuch (Audit 2, Befund S12).
                await SupabaseRealtimeManager.subscribeWithRetry(channel, listId: nil)
                for await message in removals {
                    if let listId = Self.listId(fromBroadcast: message) {
                        continuation.yield(listId)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                Task { await channel.unsubscribe() }
            }
        }
    }

    /// Liest `list_id` aus einer Broadcast-Nachricht. realtime.send liefert
    /// `{"event": …, "payload": {"list_id": …}}`; zur Sicherheit wird auch die oberste Ebene geprüft.
    nonisolated static func listId(fromBroadcast message: JSONObject) -> UUID? {
        let inner = message["payload"]?.objectValue ?? message
        guard let raw = inner["list_id"]?.stringValue else { return nil }
        return UUID(uuidString: raw)
    }

    func fetchMembers(listId: UUID) async throws -> [ListMember] {
        // Ein Join über den Fremdschlüssel list_members.profile_id → profiles.id.
        struct ProfileRow: Decodable {
            let public_id: String?
            let username: String?
            let full_name: String?
        }
        struct MemberRow: Decodable {
            let profile_id: UUID
            let added_at: Date
            let profiles: ProfileRow?
        }
        let rows: [MemberRow] = try await client
            .from("list_members")
            .select("profile_id, added_at, profiles(public_id, username, full_name)")
            .eq("list_id", value: listId.uuidString)
            .order("added_at", ascending: true)
            .execute()
            .value

        let result = rows.map { row in
            ListMember(
                id: row.profile_id,
                publicId: row.profiles?.public_id ?? "",
                username: row.profiles?.username,
                fullName: row.profiles?.full_name,
                addedAt: row.added_at
            )
        }
        return logResult(params: (listId: listId, count: result.count), result: result)
    }

    // MARK: - Einladung (Migration 014)

    func createInvite(listId: UUID) async throws -> String {
        struct Params: Encodable, Sendable { let p_list_id: UUID }
        struct Row: Decodable { let token: String }
        let rows: [Row] = try await client.rpcRows("create_list_invite", params: Params(p_list_id: listId))
        guard let token = rows.first?.token else { throw InviteError.unavailable }
        logVoid(params: (action: "createInvite", listId: listId))
        return token
    }

    func invitePreview(token: String) async throws -> InvitePreviewRow? {
        struct Params: Encodable, Sendable { let p_token: String }
        let rows: [InvitePreviewRow] = try await client.rpcRows("invite_preview_by_token", params: Params(p_token: token))
        return rows.first
    }

    func acceptInvite(token: String) async throws -> UUID {
        struct Params: Encodable, Sendable { let p_token: String }
        do {
            let listId: UUID = try await client.rpcValue("accept_list_invite", params: Params(p_token: token))
            logVoid(params: (action: "acceptInvite", listId: listId))
            return listId
        } catch {
            throw InviteError.from(error) ?? error
        }
    }
}

/// Zeile der Tabelle lists (RPC-Antworten).
private struct ListRow: Decodable {
    let id: UUID
    let owner_id: UUID
    let title: String
    let is_default: Bool
    let created_at: Date
    let updated_at: Date?

    var model: ListModel {
        ListModel(id: id, ownerId: owner_id, title: title, isDefault: is_default,
                  createdAt: created_at, updatedAt: updated_at ?? created_at)
    }
}
