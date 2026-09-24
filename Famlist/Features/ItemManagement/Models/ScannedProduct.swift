/*
 ScannedProduct.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ergebnis eines Barcode-Scans für die Karte „Artikel erkannt“.

 🔰 Notes for Beginners:
 - Quelle ist zuerst der eigene Artikelstamm (item_catalog.barcode), dann der globale
   Open-Food-Facts-Katalog (global_product_catalog.code).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

struct ScannedProduct: Equatable {
    let barcode: String
    /// Vorlage für den Listenartikel (Name, Marke, Kategorie, Einheit …).
    let entry: ItemCatalogEntry
    /// Zweite Zeile der Karte, z. B. „Kerrygold · 250 g“.
    let meta: String
}
