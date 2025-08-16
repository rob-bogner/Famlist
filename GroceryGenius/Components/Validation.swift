// Validation.swift
// Zentrale Validierungsfunktionen für Formular-Eingaben
import Foundation

struct ItemInputValidator {
    static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Name darf nicht leer sein" }
        if trimmed.count < 2 { return "Mindestens 2 Zeichen" }
        return nil
    }
    static func validateUnits(_ units: String) -> String? {
        if units.isEmpty { return "Menge fehlt" }
        guard let v = Int(units) else { return "Keine Zahl" }
        if v < 1 { return ">= 1" }
        if v > 999 { return "<= 999" }
        return nil
    }
    static func validatePrice(_ price: String) -> String? {
        if price.isEmpty { return nil } // Preis optional
        let normalized = price.replacingOccurrences(of: ",", with: ".")
        guard Double(normalized) != nil else { return "Ungültiger Preis" }
        return nil
    }
    static func sanitizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func canPersist(name: String, units: String) -> Bool {
        validateName(name) == nil && validateUnits(units) == nil
    }
}
