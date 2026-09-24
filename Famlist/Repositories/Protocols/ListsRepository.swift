/*
 ListsRepository.swift

 Famlist
 Created on: 04.09.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Protocol defining list-related repository operations and convenience extension for ListModel.

 🛠 Includes:
 - ListsRepository protocol with list management methods.
 - Protocol extension providing `fetchDefaultList(for:)` that bridges existing ensureDefaultListExists(...) to ListModel.

 🔰 Notes for Beginners:
 - Allows swapping between Supabase and preview implementations.
 - The extension provides a convenience method shared by both Supabase and Preview implementations.

 📝 Last Change:
 - Extracted protocol from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
 */

import Foundation // Provides UUID and Date.

/// List-related operations for sharing and creation.
protocol ListsRepository {
    /// Get or create default list.
    /// - Parameter owner: The owner UUID.
    /// - Returns: The default list row.
    func ensureDefaultListExists(for owner: UUID) async throws -> List
    
    /// One-shot stream of lists for owner.
    /// - Parameter owner: The owner UUID.
    /// - Returns: AsyncStream emitting arrays of lists.
    func observeLists(for owner: UUID) -> AsyncStream<[List]>
    
    /// Insert a new list.
    /// - Parameters:
    ///   - owner: The owner UUID.
    ///   - title: The list title.
    /// - Returns: The newly created list.
    func createList(for owner: UUID, title: String) async throws -> List
    
    /// Add a member to list.
    /// - Parameters:
    ///   - listId: The list UUID.
    ///   - profileId: The profile UUID to add.
    func addMember(listId: UUID, profileId: UUID) async throws
    
    /// Remove a member from list.
    /// - Parameters:
    ///   - listId: The list UUID.
    ///   - profileId: The profile UUID to remove.
    func removeMember(listId: UUID, profileId: UUID) async throws

    /// Returns all collaborators (non-owner members) of a list.
    /// - Parameter listId: The list UUID.
    /// - Returns: Array of ListMember objects.
    func fetchMembers(listId: UUID) async throws -> [ListMember]

    /// Beobachtet DELETE-Events auf list_members für den angegebenen User.
    /// Liefert die list_id jedes Mal, wenn der User aus einer Liste entfernt wird.
    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID>
    
    /// Fetch default list or create it if missing.
    /// - Parameter ownerId: The owner/profile UUID.
    /// - Returns: A ListModel representing the default list.
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel

    /// Fetch all lists for a given owner.
    /// - Parameter ownerId: The owner/profile UUID.
    /// - Returns: Array of ListModels sorted by creation date.
    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel]

    /// Rename an existing list.
    /// - Parameters:
    ///   - listId: The UUID of the list to rename.
    ///   - title: The new title.
    /// - Returns: The updated ListModel.
    func renameList(listId: UUID, title: String) async throws -> ListModel

    /// Delete a list permanently (remote cascade handles items).
    /// - Parameter listId: The UUID of the list to delete.
    func deleteList(listId: UUID) async throws

    /// Set a list as the default, clearing the previous default.
    /// - Parameters:
    ///   - listId: The UUID of the list to make default.
    ///   - ownerId: The owner UUID (needed to clear previous default).
    func setDefaultList(listId: UUID, ownerId: UUID) async throws
}

/// Convenience API to retrieve the default list as a strongly-typed ListModel.
extension ListsRepository {
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
