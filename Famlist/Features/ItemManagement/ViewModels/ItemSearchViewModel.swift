/*
 ItemSearchViewModel.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - ViewModel for the item search sheet (FAM-60 + OpenFoodFacts integration).
 - Manages the search text, result lists, loading state, and error state.
 - Debounces search to avoid spamming Supabase on every keystroke.

 🛠 Includes:
 - @Published searchText, personalResults, globalResults, isSearching, errorMessage.
 - Parallel search: personal catalog + optional global OFF catalog.
 - Two separate result collections – no merging, no shared slot budget.
 - fetchGlobal(): non-throwing – returns [] on error for offline-first behaviour.

 🔰 Notes for Beginners:
 - Uses a Task for the debounce timer so searches can be cancelled when text changes.
 - Conforms to @MainActor to keep state on the main thread.
 - globalCatalogRepository is optional; passing nil disables OFF search gracefully.

 📝 Last Change:
 - Split merged results into personalResults + globalResults (separate sections).
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides Task, Duration, etc.

/// ViewModel managing the live item search against personal and global product catalogs.
@MainActor
final class ItemSearchViewModel: ObservableObject {

    // MARK: - Published State

    @Published var searchText: String = ""
    @Published var personalResults: [SearchResult] = []
    @Published var globalResults: [SearchResult] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let catalogRepository: any ItemCatalogRepository
    private let globalCatalogRepository: (any GlobalProductCatalogRepository)?

    // MARK: - Private State

    private var searchTask: Task<Void, Never>?

    // MARK: - Constants

    private static let maxQueryLength = 100
    private static let maxPersonalResults = 5

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
            personalResults = []
            globalResults = []
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
            personalResults = personal
                .prefix(Self.maxPersonalResults)
                .map { SearchResult(entry: $0, source: .personal, imageUrl: nil) }
            globalResults = global
                .map { globalEntry in
                    // ownerPublicId "" is a placeholder; addItem() fills it from the auth session.
                    let entry = globalEntry.toItemCatalogEntry(ownerPublicId: "")
                    return SearchResult(entry: entry, source: .global, imageUrl: globalEntry.imageUrl)
                }
        } else {
            // Personal search failed
            errorMessage = String(localized: "itemSearch.error.generic")
            personalResults = []
            globalResults = []
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

}
