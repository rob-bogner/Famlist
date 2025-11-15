/*
 Profile.swift
 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: User profile model representing a row from the profiles table.
 🛠 Includes: Profile struct with Codable, Identifiable, Hashable conformance.
 🔰 Notes for Beginners: Used by ProfilesRepository to represent authenticated user profiles.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID, Date, and Codable support.

/// Represents a user profile from the profiles table.
struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    let publicId: String
    let username: String?
    let fullName: String?
    let avatarUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case publicId = "public_id"
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

