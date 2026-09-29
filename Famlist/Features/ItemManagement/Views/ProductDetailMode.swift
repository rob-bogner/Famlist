/*
 ProductDetailMode.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand des Screens „Produktdetails“ (ProductDetail.dc.html): ansehen, bearbeiten, neu.

 🔰 Notes for Beginners:
 - Beim Bearbeiten werden die Texte an derselben Stelle zu Eingabefeldern; das Layout bleibt gleich.

 📝 Last Change:
 - Initial creation (ersetzt NewItemSheet, EditItemSheet und ProductImageSheet).
 ------------------------------------------------------------------------
 */

import Foundation

/// Display state of the product detail screen.
enum ProductDetailMode: Equatable {
    /// Ansehen: Texte und Karten, Stift oben rechts.
    case view
    /// Bearbeiten: Felder an Ort und Stelle, unten „Speichern“.
    case edit
    /// Neuer Artikel: leere Felder, unten „Zur Liste hinzufügen“.
    case new

    var isEditing: Bool { self != .view }
}
