/*
 SupabaseAccountRepository.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - AccountRepository über Supabase: RPCs aus Migration 027 und die Edge Function purge-my-account (Migration 028).

 🔰 Notes for Beginners:
 - my_account_status liefert eine Zeile, wenn das Konto archiviert ist, sonst keine.
 - Hinweise (account_notices) liest die App direkt aus der Tabelle; die Zugriffsregel zeigt nur eigene.
 - purge-my-account antwortet mit 409, wenn das Konto nicht archiviert ist, und mit 502, wenn der Löschlauf
   nicht fertig wurde; beides kommt als Fehler zurück.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

final class SupabaseAccountRepository: AccountRepository {
    private let client: SupabaseClienting

    init(client: SupabaseClienting) {
        self.client = client
    }

    private struct NoParams: Encodable, Sendable {}
    private struct ListParams: Encodable, Sendable { let p_list_id: UUID }

    func status() async throws -> AccountArchiveStatus? {
        struct Row: Decodable, Sendable { let archived_at: Date; let purge_after: Date }
        let rows: [Row] = try await client.rpcRows("my_account_status", params: NoParams())
        let result = rows.first.map { AccountArchiveStatus(archivedAt: $0.archived_at, purgeAfter: $0.purge_after) }
        return logResult(params: ["archived": result != nil], result: result)
    }

    func restore() async throws -> Bool {
        let restored: Bool = try await client.rpcValue("restore_my_account", params: NoParams())
        return logResult(params: ["action": "restore"], result: restored)
    }

    func purge() async throws {
        struct Response: Decodable, Sendable { let purged: Bool }
        let response: Response = try await client.invokeFunction("purge-my-account")
        logVoid(params: ["action": "purge", "purged": response.purged])
    }

    func archivedMembers(listId: UUID) async throws -> [ArchivedListMember] {
        struct Row: Decodable, Sendable { let profile_id: UUID; let name: String?; let purge_after: Date }
        let rows: [Row] = try await client.rpcRows("archived_list_members", params: ListParams(p_list_id: listId))
        let result = rows.map { ArchivedListMember(id: $0.profile_id, name: $0.name ?? "Mitglied", purgeAfter: $0.purge_after) }
        return logResult(params: (listId: listId, count: result.count), result: result)
    }

    func removeArchivedMember(listId: UUID, profileId: UUID) async throws {
        struct Params: Encodable, Sendable { let p_list_id: UUID; let p_profile_id: UUID }
        let removed: Bool = try await client.rpcValue("remove_archived_member",
                                                      params: Params(p_list_id: listId, p_profile_id: profileId))
        logVoid(params: (listId: listId, profileId: profileId, removed: removed))
    }

    func unseenNotices() async throws -> [AccountNotice] {
        struct Row: Decodable, Sendable { let id: UUID; let list_id: UUID?; let subject_name: String? }
        let rows: [Row] = try await client
            .from("account_notices")
            .select("id, list_id, subject_name")
            .is("seen_at", value: nil)
            .order("created_at", ascending: true)
            .execute()
            .value
        let result = rows.map { AccountNotice(id: $0.id, listId: $0.list_id, subjectName: $0.subject_name ?? "Ein Mitglied") }
        return logResult(params: ["count": result.count], result: result)
    }

    func markNoticeSeen(_ id: UUID) async throws {
        struct Params: Encodable, Sendable { let p_id: UUID }
        let _: Bool = try await client.rpcValue("mark_notice_seen", params: Params(p_id: id))
    }
}
