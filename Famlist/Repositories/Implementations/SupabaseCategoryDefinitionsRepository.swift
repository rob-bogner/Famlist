/*
 SupabaseCategoryDefinitionsRepository.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-Umsetzung von CategoryDefinitionsRepository (Tabelle `categories`).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 6).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

final class SupabaseCategoryDefinitionsRepository: CategoryDefinitionsRepository {
    let client: SupabaseClienting

    init(client: SupabaseClienting) {
        self.client = client
    }

    private struct Row: Codable {
        let id: UUID
        let profile_id: UUID
        let name: String
        let icon: String?
        let position: Int
    }

    func fetch(profileId: UUID) async throws -> [CategoryDefinition] {
        let rows: [Row] = try await client.from("categories")
            .select("id, profile_id, name, icon, position")
            .eq("profile_id", value: profileId.uuidString)
            .order("position", ascending: true)
            .execute().value
        return rows.map { CategoryDefinition(id: $0.id, name: $0.name, icon: $0.icon ?? "tag", position: $0.position) }
    }

    func upsert(_ categories: [CategoryDefinition], profileId: UUID) async throws {
        guard !categories.isEmpty else { return }
        let rows = categories.map { Row(id: $0.id, profile_id: profileId, name: $0.name, icon: $0.icon, position: $0.position) }
        try await client.from("categories").upsert(rows, onConflict: "id").execute()
    }

    func delete(id: UUID) async throws {
        try await client.from("categories").delete().eq("id", value: id.uuidString).execute()
    }
}
