/*
 ProductSuggestionSetting.swift
 Famlist
 Created on: 08.11.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstellung „Produktvorschläge“ (Design: Settings, Abschnitt „Liste“): Treffer aus Open Food Facts
   beim Hinzufügen von Artikeln (Eingabe über der Tastatur und Suche).

 🔰 Notes for Beginners:
 - Gilt nur auf diesem Gerät (@AppStorage wie „Artikelbilder anzeigen“), Standard: aus.
 - Aus: ItemSearchViewModel fragt den OFF-Katalog gar nicht erst an; es erscheinen nur eigene Artikel.
 - Barcode-Scanner und „Per Foto hinzufügen“ hängen bewusst NICHT an diesem Schalter (Entscheidung Robert,
   08.11.2026, T-009).

 📝 Last Change:
 - Initial creation (T-009).
 ------------------------------------------------------------------------
 */

import Foundation

enum ProductSuggestionSetting {
    static let storageKey = "add.offSuggestions"
    static let defaultValue = false

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultValue
    }
}
