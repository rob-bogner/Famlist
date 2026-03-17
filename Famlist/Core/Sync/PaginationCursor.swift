/*
 PaginationCursor.swift
 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Composite cursor (created_at, id) for stable, conflict-free remote pagination.

 🛠 Includes:
 - PaginationCursor struct with ISO8601 formatting for PostgREST queries.
 - UserDefaults persistence keyed per listId.

 🔰 Notes for Beginners:
 - A composite cursor prevents duplicate or skipped items when two items share the same created_at timestamp.
 - Cursor is reset only on Sign-Out, Pull-to-Refresh, or migration — never by Realtime events or IncrementalSync.

 📝 FAM-79: Initial implementation.
 ------------------------------------------------------------------------
*/

import Foundation

// MARK: - PaginationCursor

/// Identifies the exact position in a (created_at ASC, id ASC) sorted remote result set.
/// Used to fetch the next page of items without skipping or duplicating any rows,
/// even when multiple items share the same created_at timestamp.
struct PaginationCursor: Codable, Equatable {

    /// Creation timestamp of the last item on the previous page (UTC).
    let createdAt: Date

    /// UUID of the last item on the previous page (secondary sort key).
    let id: UUID

    // MARK: - PostgREST formatting

    /// ISO8601 string with fractional seconds and UTC timezone, compatible with PostgREST timestamptz filters.
    var createdAtISO: String {
        Self.postgrestFormatter.string(from: createdAt)
    }

    // Shared formatter — ISO8601 with fractional seconds required by Supabase/PostgREST.
    static let postgrestFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")!
        return f
    }()
}

// MARK: - UserDefaults Persistence

extension PaginationCursor {

    private static func defaultsKey(listId: UUID) -> String {
        "fam24_pagination_cursor_\(listId.uuidString)"
    }

    /// Loads the persisted cursor for a list from UserDefaults, or nil if none is stored.
    static func load(listId: UUID) -> PaginationCursor? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey(listId: listId)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PaginationCursor.self, from: data)
    }

    /// Persists the cursor for a list in UserDefaults.
    func save(listId: UUID) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey(listId: listId))
    }

    /// Removes the cursor for a list from UserDefaults (Sign-Out, Pull-to-Refresh, migration).
    static func clear(listId: UUID) {
        UserDefaults.standard.removeObject(forKey: defaultsKey(listId: listId))
    }
}
