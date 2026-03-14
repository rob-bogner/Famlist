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

    /// Searches the global_product_catalog for products whose lowercased name contains the query.
    /// Results are sorted by popularity (scans_n desc), then name alphabetically. Max 5 results.
    func search(query: String) async throws -> [GlobalProductEntry] {
        let results: [GlobalProductEntry] = try await client
            .from("global_product_catalog")
            .select("code,name,brand,category,measure,image_url,scans_n")
            .ilike("name_lower", pattern: "%\(query.lowercased())%")
            .order("scans_n", ascending: false)
            .order("name_lower", ascending: true)
            .limit(5)
            .execute()
            .value
        return results
    }
}
