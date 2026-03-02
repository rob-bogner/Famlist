/*
 Validation.swift

 Famlist
 Created on: 31.05.2025 (est.)
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Central validation helpers for item form input (name, units, price). Provides lightweight string validation & sanitation used by Add/Edit views.

 🛠 Includes:
 - Name validation (non-empty, minimal length)
 - Units validation (numeric, range constraints)
 - Price validation (optional numeric)
 - Convenience: sanitized name & composite persistence check

 🔰 Notes for Beginners:
 - Keeps logic pure (no side effects) for easy unit testing.
 - Returns optional localized error key string; nil means valid.
 - Range & limits are conservative; adapt as business rules evolve.

 📝 Last Change:
 - Replaced ad-hoc header with standardized block and kept pure validation functions. No functional changes.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation used for String trimming utilities.

/// Pure helper struct containing static validation functions for item input fields.
struct ItemInputValidator { // Namespace struct; no instances required.
    /// Validates the item name; returns a localized error message or nil if valid.
    static func validateName(_ name: String) -> String? { // Name must not be empty and have at least 2 characters.
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines) // Remove spaces/newlines around the text.
        if trimmed.isEmpty { return String(localized: "validation.name.empty") } // Error when empty.
        if trimmed.count < 2 { return String(localized: "validation.name.short") } // Error when too short.
        return nil // Valid name.
    }
    /// Validates units text for numeric content and range boundaries.
    static func validateUnits(_ units: String) -> String? { // Units must be a number within 1...999.
        if units.isEmpty { return String(localized: "validation.units.missing") } // Error when missing.
        guard let v = Int(units) else { return String(localized: "validation.units.nan") } // Not a number.
        if v < 1 { return String(localized: "validation.units.min") } // Below minimum.
        if v > 999 { return String(localized: "validation.units.max") } // Above maximum.
        return nil // Valid units.
    }
    /// Validates a price string; empty is allowed, otherwise must be a number.
    static func validatePrice(_ price: String) -> String? { // Price optional; if provided must parse.
        if price.isEmpty { return nil } // Price optional.
        let normalized = price.replacingOccurrences(of: ",", with: ".") // Normalize comma decimal to dot.
        guard Double(normalized) != nil else { return String(localized: "validation.price.invalid") } // Not a number.
        return nil // Valid price.
    }
    /// Returns a trimmed name used for persistence.
    static func sanitizedName(_ name: String) -> String { // Trims spaces/newlines for storage.
        name.trimmingCharacters(in: .whitespacesAndNewlines) // Return trimmed value.
    }
    /// Combined validity for the minimum fields required to persist.
    static func canPersist(name: String, units: String) -> Bool { // Minimal checks for enabling Save button.
        validateName(name) == nil && validateUnits(units) == nil // True when both fields are valid.
    }
} // end ItemInputValidator
