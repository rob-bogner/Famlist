/*
 PageLoader.swift
 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Loads paginated remote items using a composite (created_at, id) cursor.
 - Only performs upserts into SwiftData — never purges items it did not load.

 🛠 Includes:
 - PaginationConfig: page size constant.
 - PageLoader: loadNextPage(listId:cursor:) — wraps repository.fetchItems(cursor:limit:).

 🔰 Notes for Beginners:
 - Cursor ownership belongs exclusively to PageLoader; IncrementalSync must not advance it.
 - hasMoreItems is determined by comparing result count to page size (T1/T2/T3 rules in ListViewModel+Pagination).

 📝 FAM-79: Initial implementation.
 ------------------------------------------------------------------------
*/

import Foundation

// MARK: - PaginationConfig

/// Global pagination constants.
enum PaginationConfig {
    /// Number of items fetched per remote page.
    static let pageSize: Int = 50
}

// MARK: - PageLoader

/// Fetches pages of remote items using a stable composite cursor.
@MainActor
final class PageLoader {

    // MARK: - Dependencies

    private let repository: ItemsRepository
    let pageSize: Int

    // MARK: - Init

    init(repository: ItemsRepository, pageSize: Int = PaginationConfig.pageSize) {
        self.repository = repository
        self.pageSize = pageSize
    }

    // MARK: - Pagination

    /// Fetches the next page of non-tombstoned items sorted by (created_at ASC, id ASC).
    ///
    /// - Parameters:
    ///   - listId: The list to load items for.
    ///   - cursor: Position marker from the last loaded page. Nil loads the first page.
    /// - Returns:
    ///   - `items`: Items in this page, already upserted into SwiftData by the repository.
    ///   - `newCursor`: Cursor pointing to the last item in this page, or nil if the page is empty.
    func loadNextPage(listId: UUID, cursor: PaginationCursor?) async throws -> (items: [ItemModel], newCursor: PaginationCursor?) {
        let items = try await repository.fetchItems(listId: listId, cursor: cursor, limit: pageSize)

        let newCursor: PaginationCursor? = items.last.flatMap { last in
            guard let createdAt = last.createdAt,
                  let id = UUID(uuidString: last.id) else { return nil }
            return PaginationCursor(createdAt: createdAt, id: id)
        }

        return (items, newCursor)
    }
}
