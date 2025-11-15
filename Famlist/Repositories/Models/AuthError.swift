/*
 AuthError.swift
 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Authentication-related error types thrown by repositories.
 🛠 Includes: AuthError enum for unauthenticated state.
 🔰 Notes for Beginners: Thrown when repository operations require authentication but no user is logged in.
 📝 Last Change: Extracted from SupabaseRepositories.swift to follow one-type-per-file rule.
 ------------------------------------------------------------------------
*/

import Foundation // Provides Error protocol.

/// Authentication-related lightweight error states thrown by repositories when preconditions are not met.
enum AuthError: Error {
    /// Thrown when a call requires a logged-in user but none is present.
    case unauthenticated
}

