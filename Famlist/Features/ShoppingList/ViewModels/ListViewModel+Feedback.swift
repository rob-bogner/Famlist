/*
 ListViewModel+Feedback.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rückmeldungen an die Oberfläche: kurzes Hervorheben frisch synchronisierter Artikel und Fehlermeldungen.

 📝 Last Change:
 - Aus ListViewModel.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ListViewModel {
    // MARK: - Remote Sync Highlight

    /// Marks items as recently synced from a remote source and schedules their removal after 2 seconds.
    /// Safe to call with an overlapping set — `formUnion` is idempotent.
    /// The removal subtracts only the IDs passed in this call, so a concurrent markRecentlySynced()
    /// for different items is not affected.
    internal func markRecentlySynced(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        recentlySyncedItemIDs.formUnion(ids)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            self.recentlySyncedItemIDs.subtract(ids)
        }
    }

    // MARK: - Error Handling

    /// Stores a user-presentable error string on the main actor.
    @MainActor
    internal func setError(_ error: Error) {
        self.errorMessage = (error as NSError).localizedDescription
    }
}
