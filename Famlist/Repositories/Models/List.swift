/*
 List.swift
 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Shopping list model representing a row from the lists table.
 🛠 Includes: List struct with Codable, Identifiable, Hashable conformance.
 🔰 Notes for Beginners: Used by ListsRepository to represent shopping list rows from the database.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID, Date, and Codable support.

/// Represents a shopping list row from the lists table.
struct List: Codable, Identifiable, Hashable {
    let id: UUID // List id.
    let owner_id: UUID // Owner UUID.
    let title: String // Human-readable list title.
    let is_default: Bool // Whether this is the default list.
    let created_at: Date? // Creation timestamp.
    let updated_at: Date? // Last update timestamp.
}

