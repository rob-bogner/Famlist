/*
 SupabaseItemsRepository+Fetch.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lesende Abfragen des Artikel-Repositorys: Seiten (FAM-79), Delta-Abgleich (FAM-41) für eine oder
   mehrere Listen, alle Artikel-IDs einer Liste.

 🔰 Notes for Beginners:
 - Die Abfragen schreiben nichts in SwiftData; der Aufrufer übernimmt die Zeilen per mergeRemote (HLC).
 - PostgREST liefert ohne Limit höchstens `max_rows` Zeilen – ohne Hinweis. Deshalb immer seitenweise.

 📝 Last Change:
 - Aus SupabaseItemsRepository.swift ausgelagert; Delta für mehrere Listen in einem Aufruf (Watch-Plan Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

extension SupabaseItemsRepository {

    // MARK: - Pagination (FAM-79)

    /// Fetches a page of non-tombstoned items sorted by (created_at ASC, id ASC) using a composite cursor.
    /// Items are returned for caller upsert — this method does NOT upsert into SwiftData itself.
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] {
        var query = client
            .from("items")
            .select(SupabaseItemRow.columns)
            .eq("list_id", value: listId.uuidString)
            .or("tombstone.is.false,tombstone.is.null")

        if let cursor {
            let isoDate = cursor.createdAtISO
            let uuidStr = cursor.id.uuidString.lowercased()
            query = query.or("created_at.gt.\(isoDate),and(created_at.eq.\(isoDate),id.gt.\(uuidStr))")
        }

        let rows: [SupabaseItemRow] = try await query
            .order("created_at", ascending: true)
            .order("id", ascending: true)
            .limit(limit)
            .execute()
            .value

        return rows.map { $0.toItemModel() }
    }

    // MARK: - Incremental Sync (FAM-41)

    /// Seitengröße des Delta-Abgleichs (PostgREST liefert ohne Limit höchstens `max_rows` Zeilen – ohne Hinweis).
    static let deltaPageSize = 500

    /// Fetches items (including tombstoned) whose updated_at is after `since`, seitenweise bis zum Ende.
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] {
        try await fetchItemsSince(listIds: [listId], since: since)
    }

    /// Delta mehrerer Listen in einem Aufruf je Seite (list_id IN (…)); sortiert nach (updated_at, id).
    /// Folgeseiten nutzen einen Schlüssel-Cursor (updated_at, id) mit dem exakten Zeitstempel des Servers
    /// (Mikrosekunden), damit bei gleichen Zeitstempeln an der Seitengrenze keine Zeile verloren geht.
    func fetchItemsSince(listIds: [UUID], since: Date) async throws -> [ItemModel] {
        guard !listIds.isEmpty else { return [] }
        let ids = listIds.map { $0.uuidString.lowercased() }
        var result: [ItemModel] = []
        var cursor: (updatedAt: String, id: String)?
        while true {
            var query = client.from("items").select(SupabaseItemRow.columns).in("list_id", values: ids)
            if let cursor {
                query = query.or("updated_at.gt.\(cursor.updatedAt),and(updated_at.eq.\(cursor.updatedAt),id.gt.\(cursor.id))")
            } else {
                query = query.gt("updated_at", value: PaginationCursor.postgrestFormatter.string(from: since))
            }
            let rows: [SupabaseItemRow] = try await query
                .order("updated_at", ascending: true)
                .order("id", ascending: true)
                .limit(Self.deltaPageSize)
                .execute()
                .value
            result += rows.map { $0.toItemModel() }
            guard rows.count == Self.deltaPageSize, let last = rows.last, let stamp = last.updatedAt else { break }
            cursor = (Self.filterSafeTimestamp(stamp), last.id.uuidString.lowercased())
        }
        return result
    }

    /// Alle Artikel-IDs einer Liste auf dem Server (nur die ID-Spalte, seitenweise nach ID).
    /// Für den Abgleich nach langer Pause: Der Server löscht Löschmarkierungen nach 30 Tagen endgültig.
    func fetchItemIds(listId: UUID) async throws -> Set<String>? {
        struct IdRow: Decodable, Sendable { let id: UUID }
        var ids: Set<String> = []
        var after: String?
        while true {
            var query = client.from("items").select("id").eq("list_id", value: listId.uuidString)
            if let after { query = query.gt("id", value: after) }
            let rows: [IdRow] = try await query.order("id", ascending: true).limit(1000).execute().value
            ids.formUnion(rows.map { $0.id.uuidString })
            guard rows.count == 1000, let last = rows.last else { return ids }
            after = last.id.uuidString.lowercased()
        }
    }

    /// Postgres liefert „…+00:00“; ein „+“ im Filter würde als Leerzeichen gelesen. UTC → „Z“.
    static func filterSafeTimestamp(_ raw: String) -> String {
        raw.hasSuffix("+00:00") ? String(raw.dropLast(6)) + "Z" : raw
    }
}
