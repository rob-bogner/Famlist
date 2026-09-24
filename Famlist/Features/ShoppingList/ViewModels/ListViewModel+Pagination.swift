/*
 ListViewModel+Pagination.swift

 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Extension managing remote pagination via composite (created_at, id) cursor.

 🛠 Includes:
 - loadNextPage(): fetches next remote page via PageLoader + SyncOrchestrator.
 - pullToRefresh(): resets cursor + runs IncrementalSync (deterministic 5-step sequence).
 - hasMoreItems rules (T1/T2/T3) for termination detection without server-side count.

 🔰 Notes for Beginners:
 - Pagination is demand-driven: triggered only when the user scrolls to the last visible item.
 - Pull-to-Refresh resets the cursor synchronously BEFORE any network call.
 - The cursor is owned exclusively by this layer; IncrementalSync must not advance it.

 📝 FAM-40: Initial implementation.
 ------------------------------------------------------------------------
 */

import Foundation

// MARK: - Pagination

extension ListViewModel {

    // MARK: - Load Next Page

    /// Fetches the next remote page and upserts items into SwiftData.
    ///
    /// Termination rules (T1/T2/T3):
    ///   T1: hasMoreItems = (result.count == pageLoader.pageSize)
    ///   T2: hasMoreItems = false when a page returns 0 items (corrects false-positive from T1).
    ///   T3: hasMoreItems = false after 1 consecutive empty page (guards against timing anomalies).
    @MainActor
    func loadNextPage() async {
        guard !isBulkMutationActive else { return }
        guard let pageLoader else { return }
        guard hasMoreItems && !isLoadingNextPage else { return }

        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let (items, newCursor) = try await withPageLoad {
                try await pageLoader.loadNextPage(listId: listId, cursor: currentCursor)
            }

            // Upsert fetched items into SwiftData (no purge per FAM-79).
            for item in items {
                _ = try? itemStore.upsert(model: item)
            }
            try? itemStore.save()

            // Advance cursor (T1 rule first).
            if let newCursor {
                currentCursor = newCursor
                newCursor.save(listId: listId)
            }

            // T1: hasMoreItems based on page fullness.
            let pageSize = pageLoader.pageSize
            hasMoreItems = (items.count == pageSize)

            // T2/T3: empty page handling.
            if items.isEmpty {
                consecutiveEmptyPages += 1
                if consecutiveEmptyPages >= 1 {
                    hasMoreItems = false // T2+T3: stop after first empty page.
                }
            } else {
                consecutiveEmptyPages = 0
            }

            refreshItemsFromStore()

            logVoid(params: (
                action: "loadNextPage.success",
                listId: listId,
                itemCount: items.count,
                hasMoreItems: hasMoreItems
            ))
        } catch {
            logVoid(params: (
                action: "loadNextPage.error",
                listId: listId,
                error: (error as NSError).localizedDescription
            ))
            setError(error)
        }
    }

    // MARK: - Pull-to-Refresh

    /// Deterministic Pull-to-Refresh sequence (FAM-24 canonical contract):
    ///   1. cursor = nil               (synchronous, before any await)
    ///   2. hasMoreItems = true        (synchronous, before any await)
    ///   3. IncrementalSync(since:)    (async — fetches delta)
    ///   4. refreshItemsFromStore()    (UI updated from SwiftData)
    ///   5. Next pagination starts at page 1 on User-Scroll
    @MainActor
    func pullToRefresh() async {
        // Steps 1 & 2: reset pagination state atomically, synchronously, before network.
        currentCursor = nil
        PaginationCursor.clear(listId: listId)
        hasMoreItems = true
        consecutiveEmptyPages = 0

        // Step 3: IncrementalSync — fetches all changes since lastSyncTimestamp.
        // suppressHighlight: true because pull-to-refresh is a user-triggered full refresh;
        // highlighting all returned items would be noisy and misleading.
        await runIncrementalSync(suppressHighlight: true)

        // Step 4: refreshItemsFromStore() is called inside runIncrementalSync().
        logVoid(params: (action: "pullToRefresh.complete", listId: listId))
    }

    // MARK: - Private Helpers

    /// Executes `work` while holding the SyncOrchestrator page-load lock (if available).
    /// Realtime handlers arriving during the page fetch are buffered and flushed afterwards.
    private func withPageLoad<T>(_ work: () async throws -> T) async rethrows -> T {
        if let orchestrator = syncOrchestrator {
            return try await orchestrator.runPageLoad(work)
        }
        return try await work()
    }
}
