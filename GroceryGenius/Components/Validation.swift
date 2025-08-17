// MARK: - Validation.swift

/*
 File: Validation.swift
 Project: GroceryGenius
 Created: 31.05.2025 (est.)
 Last Updated: 17.08.2025

 Overview:
 Central validation helpers for item form input (name, units, price). Provides lightweight string validation & sanitation used by Add/Edit views.

 Responsibilities / Includes:
 - Name validation (non-empty, minimal length)
 - Units validation (numeric, range constraints)
 - Price validation (optional numeric)
 - Convenience: sanitized name & composite persistence check

 Design Notes:
 - Keeps logic pure (no side effects) for easy unit testing.
 - Returns optional localized error key string; nil means valid.
 - Range & limits are conservative; adapt as business rules evolve.

 Possible Enhancements:
 - Add per-field enum for richer error metadata.
 - Support localized number parsing based on current Locale.
 - Add category / description validation rules if requirements emerge.
*/
import Foundation

struct ItemInputValidator {
    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return String(localized: "validation.name.empty") }
        if trimmed.count < 2 { return String(localized: "validation.name.short") }
        return nil
    }
    static func validateUnits(_ units: String) -> String? {
        if units.isEmpty { return String(localized: "validation.units.missing") }
        guard let v = Int(units) else { return String(localized: "validation.units.nan") }
        if v < 1 { return String(localized: "validation.units.min") }
        if v > 999 { return String(localized: "validation.units.max") }
        return nil
    }
    static func validatePrice(_ price: String) -> String? {
        if price.isEmpty { return nil } // Price optional
        let normalized = price.replacingOccurrences(of: ",", with: ".")
        guard Double(normalized) != nil else { return String(localized: "validation.price.invalid") }
        return nil
    }
    static func sanitizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func canPersist(name: String, units: String) -> Bool {
        validateName(name) == nil && validateUnits(units) == nil
    }
}
