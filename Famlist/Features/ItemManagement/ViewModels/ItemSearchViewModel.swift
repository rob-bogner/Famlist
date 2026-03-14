/*
 ItemSearchViewModel.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - ViewModel for the item search sheet (FAM-60 + OpenFoodFacts integration).
 - Manages the search text, result list, loading state, and merged results.
 - Debounces search to avoid spamming Supabase on every keystroke.

 🛠 Includes:
 - @Published searchText, results, isSearching, errorMessage.
 - Parallel search: personal catalog + optional global OFF catalog.
 - Merge strategy: personal first (max 5 total), fill with global (dedup by name_lower).
 - fetchGlobal(): non-throwing – returns [] on error for offline-first behaviour.

 🔰 Notes for Beginners:
 - Uses a Task for the debounce timer so searches can be cancelled when text changes.
 - Conforms to @MainActor to keep state on the main thread.
 - globalCatalogRepository is optional; passing nil disables OFF search gracefully.

 📝 Last Change:
 - Added global OFF catalog search + SearchResult merge (OpenFoodFacts integration).
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides Task, Duration, etc.

/// ViewModel managing the live item search against personal and global product catalogs.
@MainActor
final class ItemSearchViewModel: ObservableObject {

    // MARK: - Published State

    @Published var searchText: String = ""
    @Published var results: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let catalogRepository: any ItemCatalogRepository
    private let globalCatalogRepository: (any GlobalProductCatalogRepository)?

    // MARK: - Private State

    private var searchTask: Task<Void, Never>?

    // MARK: - Constants

    private static let maxQueryLength = 100
    private static let maxTotalResults = 5

    // MARK: - Init

    init(
        catalogRepository: any ItemCatalogRepository,
        globalCatalogRepository: (any GlobalProductCatalogRepository)? = nil
    ) {
        self.catalogRepository = catalogRepository
        self.globalCatalogRepository = globalCatalogRepository
    }

    // MARK: - Search

    /// Called whenever searchText changes. Cancels any in-flight search and starts a new one
    /// after a 300ms debounce if the query is at least 2 characters long.
    func onSearchTextChanged() {
        // Security: clamp input length to prevent DoS via extremely long queries
        if searchText.count > Self.maxQueryLength {
            searchText = String(searchText.prefix(Self.maxQueryLength))
        }
        searchTask?.cancel()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            results = []
            isSearching = false
            errorMessage = nil
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    // MARK: - Private Helpers

    private func performSearch(query: String) async {
        errorMessage = nil

        // Run both searches in parallel
        async let personalTask = fetchPersonal(query: query)
        async let globalTask = fetchGlobal(query: query)

        let personal = await personalTask
        let global = await globalTask

        guard !Task.isCancelled else { return }

        if let personal {
            results = merge(personal: personal, global: global)
        } else {
            // Personal search failed
            errorMessage = String(localized: "itemSearch.error.generic")
            results = []
        }
        isSearching = false
    }

    /// Fetches personal catalog results. Returns nil on error.
    private func fetchPersonal(query: String) async -> [ItemCatalogEntry]? {
        do {
            return try await catalogRepository.search(query: query)
        } catch {
            guard !Task.isCancelled else { return nil }
            // Security: do not expose raw Supabase error details to the user
            return nil
        }
    }

    /// Fetches global OFF catalog results. Returns [] on error (offline-first degradation).
    private func fetchGlobal(query: String) async -> [GlobalProductEntry] {
        guard let repo = globalCatalogRepository else { return [] }
        do {
            return try await repo.search(query: query)
        } catch {
            // Global catalog is online-only; silently degrade to empty when offline.
            return []
        }
    }

    /// Merges personal and global results: personal first, fill up to maxTotalResults with global.
    /// Deduplicates by lowercased name (personal entries take precedence).
    func merge(personal: [ItemCatalogEntry], global: [GlobalProductEntry]) -> [SearchResult] {
        let personalResults = personal
            .prefix(Self.maxTotalResults)
            .map { entry in
                SearchResult(entry: entry, source: .personal, imageUrl: nil)
            }

        let usedNames = Set(personalResults.map { $0.entry.name.lowercased() })
        let slotsLeft = Self.maxTotalResults - personalResults.count

        let globalResults = global
            .filter { !usedNames.contains($0.name.lowercased()) }
            .prefix(slotsLeft)
            .map { globalEntry in
                // ownerPublicId "" is a placeholder; addItem() fills it from the auth session.
                let entry = globalEntry.toItemCatalogEntry(ownerPublicId: "")
                return SearchResult(entry: entry, source: .global, imageUrl: globalEntry.imageUrl)
            }

        return Array(personalResults) + Array(globalResults)
    }
}
