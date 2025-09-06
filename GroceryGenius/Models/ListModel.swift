/*
 ListModel.swift

 GroceryGenius
 Created on: 04.09.2025
 Last updated on: 04.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Strongly typed model representing a shopping list row as stored in Supabase (public.lists).

 🛠 Includes:
 - ListModel struct with id, ownerId, title, isDefault, createdAt, updatedAt.

 🔰 Notes for Beginners:
 - This model is separate from ItemModel and is used to identify which list to show.
 - Dates are non-optional here; when mapping from database rows where timestamps may be null, we fall back to Date().

 📝 Last Change:
 - Initial creation to support default list fetching and wiring.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID and Date used by this model.

/// Represents a shopping list entity.
/// - Fields align with columns in public.lists; used by repositories and view models.
struct ListModel: Codable, Hashable, Identifiable { // Codable for decoding, Hashable for sets, Identifiable for SwiftUI.
    /// Unique list identifier (UUID primary key in DB).
    let id: UUID // Immutable id.
    /// Owner profile/user UUID.
    let ownerId: UUID // The user/profile who owns the list.
    /// Human-readable list title.
    let title: String // Display name.
    /// Whether this list is the user's default list.
    let isDefault: Bool // True if default.
    /// Creation timestamp (fallback to current date if missing from DB mapping).
    let createdAt: Date // Non-optional for simplicity in UI.
    /// Last update timestamp (fallback to current date if missing from DB mapping).
    let updatedAt: Date // Non-optional for simplicity in UI.
}
