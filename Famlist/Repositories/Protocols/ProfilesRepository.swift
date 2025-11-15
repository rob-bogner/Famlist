/*
 ProfilesRepository.swift
 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Protocol defining profile-related repository operations.
 🛠 Includes: ProfilesRepository protocol with upsert, fetch, and lookup methods.
 🔰 Notes for Beginners: Allows swapping between Supabase and preview implementations.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.

/// Profile-related operations.
protocol ProfilesRepository {
    /// Create or update current profile.
    /// - Parameters:
    ///   - authUserId: The authenticated user's UUID.
    ///   - publicId: The public identifier for sharing.
    func upsertProfile(authUserId: UUID, publicId: String) async throws
    
    /// Fetch current profile.
    /// - Returns: The current user's profile.
    /// - Throws: AuthError.unauthenticated if no user is logged in.
    func myProfile() async throws -> Profile
    
    /// Look up profile by public id.
    /// - Parameter publicId: The public identifier to search for.
    /// - Returns: Matching profile or nil if not found.
    func profileByPublicId(_ publicId: String) async throws -> Profile?
}

