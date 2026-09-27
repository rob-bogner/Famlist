/*
 WatchItemDetail.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anzeigedaten des Screens „Artikel“: Name, Kategorie (Ladenweg-Name), Einheit, Menge.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

struct WatchItemDetail: Hashable {
    let id: String
    let name: String
    let category: String
    /// Einheit ohne Zahl, z. B. „Packung“, „Stück“.
    let unitName: String
    /// Menge, auch mit Nachkommastellen (1,5 kg).
    let units: Double
    /// Feiner Schritt (± tippen, Krone langsam): kg/l/m 0,1 · g/ml 50 · sonst 1 – wie auf dem iPhone.
    let step: Double
    /// Grober Schritt (± halten, Krone schnell): kg/l/m 1 · sonst wie `step`.
    let coarseStep: Double
    let isChecked: Bool
}
