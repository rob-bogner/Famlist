/*
 MeasureCanonicalizer.swift
 GroceryGenius
 Created on: 12.10.2025
 Last updated on: 12.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Service for normalizing free-form measurement unit strings.
 🛠 Includes: Static method to convert user input to canonical Measure enum values.
 🔰 Notes for Beginners: Used by ListViewModel to ensure consistent measure storage.
 📝 Last Change: Extracted from ListViewModel.swift to reduce file size and improve modularity.
 ------------------------------------------------------------------------
*/

import Foundation // Provides String trimming.

/// Service for canonicalizing measurement unit strings.
struct MeasureCanonicalizer {
    /// Converts a free-form measure string to a normalized token using the Measure enum.
    /// - Parameter raw: User-provided measure string (e.g., "kilogram", "kg", "Kilogramm").
    /// - Returns: Canonical raw value from Measure enum (e.g., "kg") or empty string if input is empty.
    static func canonicalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return Measure.fromExternal(trimmed).rawValue
    }
}

