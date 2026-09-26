/*
 SupabasePricePointsRepository.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-Umsetzung von PricePointsRepository. profile_id kommt aus der aktiven Sitzung (RLS).

 🔰 Notes for Beginners:
 - purchased_at ist eine DATE-Spalte → als „yyyy-MM-dd“ senden/lesen.
 - price ist NUMERIC(10,2) → als Zahl senden; Supabase liefert eine Zahl zurück.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

final class SupabasePricePointsRepository: PricePointsRepository {
    let client: SupabaseClienting

    init(client: SupabaseClienting) {
        self.client = client
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private struct Row: Codable {
        let id: UUID
        let profile_id: UUID?
        let item_key: String
        let item_name: String
        let store_name: String
        let purchased_at: String
        let price: Decimal
    }

    func insert(_ points: [PricePoint]) async throws {
        guard !points.isEmpty else { return }
        let uid: UUID
        if let current = client.auth.currentUser?.id { uid = current } else { uid = try await client.auth.session.user.id }
        let rows = points.map {
            Row(id: $0.id, profile_id: uid, item_key: $0.itemKey, item_name: $0.itemName, store_name: $0.storeName,
                purchased_at: Self.dayFormatter.string(from: $0.purchasedAt), price: $0.price)
        }
        // ignoreDuplicates → ON CONFLICT DO NOTHING: Doppeltes Senden (Antwort ging verloren) ist harmlos und
        // braucht keine UPDATE-Regel. Vorher blieb die Warteschlange danach für immer hängen (Audit H9).
        try await client.from("price_points").upsert(rows, onConflict: "id", ignoreDuplicates: true).execute()
    }

    func history(itemKey: String) async throws -> [PricePoint] {
        let rows: [Row] = try await client.from("price_points")
            .select("id, profile_id, item_key, item_name, store_name, purchased_at, price")
            .eq("item_key", value: itemKey)
            .order("purchased_at", ascending: true)
            .execute().value
        return rows.map {
            PricePoint(id: $0.id, itemName: $0.item_name, storeName: $0.store_name,
                       purchasedAt: Self.dayFormatter.date(from: $0.purchased_at) ?? Date(), price: $0.price)
        }
    }
}
