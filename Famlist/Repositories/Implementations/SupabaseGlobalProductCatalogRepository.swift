/*
 SupabaseGlobalProductCatalogRepository.swift

 Famlist
 Created on: 14.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-backed implementation of GlobalProductCatalogRepository.
 - Queries the global_product_catalog table (read-only, public for authenticated users).

 🛠 Includes:
 - search(): trigram ILIKE on name_lower, ordered by scans_n desc, max 5 results.

 🔰 Notes for Beginners:
 - No RLS filter needed here: the table has a single policy for all authenticated users.
 - Results are decoded into GlobalProductEntry via CodingKeys (id ← code).
 - Callers (ItemSearchViewModel.fetchGlobal) catch errors gracefully for offline-first behaviour.

 📝 Last Change:
 - Initial creation for OpenFoodFacts integration.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides URL types used indirectly.
import Supabase // Supabase client for PostgREST queries.

/// Supabase-backed global product catalog repository.
/// @MainActor ensures all DB calls and state are on the main thread.
@MainActor
final class SupabaseGlobalProductCatalogRepository: GlobalProductCatalogRepository {

    // MARK: - Dependencies

    private let client: SupabaseClienting

    // MARK: - Init

    init(client: SupabaseClienting) {
        self.client = client
    }

    // MARK: - GlobalProductCatalogRepository

    /// Suche im globalen Katalog über die Datenbankfunktion `search_global_products` (Migration 020):
    /// ab 3 Zeichen, Kandidaten per Trigramm-Index, davon die 5 beliebtesten. Vorher lief eine direkte
    /// `ilike`-Abfrage im Mittel 2,8 s (bis 6,3 s) pro Tastendruck, weil Postgres den falschen Index wählte.
    func search(query: String) async throws -> [GlobalProductEntry] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumQueryLength else { return [] }
        struct Params: Encodable, Sendable { let p_query: String }
        return try await client.rpcRows("search_global_products", params: Params(p_query: query))
    }

    /// Kürzere Eingaben liefern im globalen Katalog zu viele Treffer; der Server sucht erst ab 3 Zeichen.
    static let minimumQueryLength = 3

    /// Barcode-Scanner: Produkt zum EAN/UPC-Code (Primärschlüssel `code`).
    func product(code: String) async throws -> GlobalProductEntry? {
        let rows: [GlobalProductEntry] = try await client
            .from("global_product_catalog")
            .select("code,name,brand,category,measure,image_url,scans_n")
            .eq("code", value: code)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}
