/*
 Category.swift
 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Category model representing a row from the categories table.
 🛠 Includes: Category struct with Codable, Identifiable, Hashable conformance.
 🔰 Notes for Beginners: Used by CategoriesRepository to represent item categories/tags.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID and Codable support.

/// Category/tag associated with items.
struct Category: Codable, Identifiable, Hashable {
    let id: UUID // Category id.
    let name: String // Category name.
    let emoji: String? // Optional emoji.
    let color_hex: String? // Optional color hex string.
    let profile_id: UUID? // Optional profile owner.
}

