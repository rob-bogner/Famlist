/*
 CategoriesRepository.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Protocol defining category-related repository operations.
 🛠 Includes: CategoriesRepository protocol with fetch and create methods.
 🔰 Notes for Beginners: Allows swapping between Supabase and preview implementations.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.

/// Category operations.
protocol CategoriesRepository {
    /// Fetch all categories for profile or public ones.
    /// - Parameter profileId: Optional profile UUID to filter by; nil returns public categories.
    /// - Returns: Array of categories visible to the profile.
    func all(for profileId: UUID?) async throws -> [Category]
    
    /// Create a new category.
    /// - Parameters:
    ///   - name: Category name.
    ///   - emoji: Optional emoji.
    ///   - colorHex: Optional color hex string.
    /// - Returns: The newly created category.
    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category
}

