/*
 ListsRepository.swift

 GroceryGenius
 Created on: 04.09.2025
 Last updated on: 04.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Adds a convenience API on the existing ListsRepository (defined in SupabaseRepositories.swift) to fetch the default list as a ListModel.

 🛠 Includes:
 - Protocol extension providing `fetchDefaultList(for:)` that bridges existing ensureDefaultListExists(...) to ListModel.

 🔰 Notes for Beginners:
 - The app already had a ListsRepository protocol elsewhere with broader methods.
 - This file doesn’t redefine the protocol to avoid duplication; it adds a convenience method shared by both Supabase and Preview implementations.

 📝 Last Change:
 - Replaced duplicate protocol with a non-conflicting extension that returns ListModel.
 ------------------------------------------------------------------------
 */

import Foundation // Provides UUID and Date.

/// Convenience API to retrieve the default list as a strongly-typed ListModel.
extension ListsRepository { // Extend the existing protocol declared in SupabaseRepositories.swift
    /// Fetches (or creates) the default list for a given owner and maps it to ListModel.
    /// - Parameter ownerId: The owner/profile UUID.
    /// - Returns: A ListModel representing the default list.
    /// - Throws: Any error from the underlying repository implementation.
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel { // Bridge existing API -> ListModel
        // Use the existing helper to ensure a default list row exists
        let row = try await ensureDefaultListExists(for: ownerId) // Returns a `List` row type from SupabaseRepositories
        // Map existing List row (DB mapping) to the app-level ListModel used by view models
        return ListModel(
            id: row.id,
            ownerId: row.owner_id,
            title: row.title,
            isDefault: row.is_default,
            createdAt: row.created_at ?? Date(),
            updatedAt: row.updated_at ?? row.created_at ?? Date() // Prefer updated_at; fallback to created_at or now
        )
    }
}
