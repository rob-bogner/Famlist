/*
 ItemSearchViewModel.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 12.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - ViewModel for the item search sheet (FAM-60).
 - Manages the search text, result list, and loading state.
 - Debounces search to avoid spamming Supabase on every keystroke.

 🛠 Includes:
 - @Published searchText, results, isSearching, errorMessage.
 - onSearchTextChanged(): triggers debounced search after 300ms.
 - Minimum 2 characters before a search is fired.

 🔰 Notes for Beginners:
 - Uses a Task for the debounce timer so searches can be cancelled when text changes.
 - Conforms to @MainActor to keep state on the main thread.

 📝 Last Change:
 - Initial creation for FAM-60 smart search feature.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides Task, Duration, etc.

/// ViewModel managing the live item search against the user's personal item catalog.
@MainActor
final class ItemSearchViewModel: ObservableObject {

    // MARK: - Published State

    @Published var searchText: String = ""
    @Published var results: [ItemCatalogEntry] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let catalogRepository: any ItemCatalogRepository

    // MARK: - Private State

    private var searchTask: Task<Void, Never>?

    // MARK: - Init

    init(catalogRepository: any ItemCatalogRepository) {
        self.catalogRepository = catalogRepository
    }

    // MARK: - Search

    // MARK: - Constants

    private static let maxQueryLength = 100

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
        do {
            results = try await catalogRepository.search(query: query)
        } catch {
            guard !Task.isCancelled else { return }
            // Security: do not expose raw Supabase error details to the user
            errorMessage = String(localized: "itemSearch.error.generic")
            results = []
        }
        isSearching = false
    }
}
