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

// MARK: - Details für die Karte „Artikel erkannt“

extension ScannedProduct {
    /// Marke (leer → nil).
    var brand: String? {
        guard let b = entry.brand?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty else { return nil }
        return b
    }

    /// Detail-Chips unter dem Namen: Menge/Einheit · Kategorie · zuletzt gezahlter Preis (nur vorhandene).
    /// Freitext mit Zahl („250 g“ aus OpenFoodFacts) bleibt wie er ist, Einheiten-Codes („piece“) werden übersetzt.
    func detailChips(categories: [CategoryDefinition] = CategoryDefinition.defaults) -> [String] {
        var chips: [String] = []
        let measure = entry.measure.trimmingCharacters(in: .whitespacesAndNewlines)
        if !measure.isEmpty {
            chips.append(measure.rangeOfCharacter(from: .decimalDigits) != nil
                         ? measure : Measure.fromExternal(measure).localizedName)
        }
        if let raw = entry.category, !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            chips.append(CategoryResolver.name(for: raw, in: categories))
        }
        if entry.price > 0 {
            chips.append(entry.price.formatted(.currency(code: "EUR")))
        }
        return chips
    }

    /// Beschreibung (leer → nil).
    var details: String? {
        guard let d = entry.productDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty else { return nil }
        return d
    }

    /// Bildadresse aus dem Katalog (nur https), wenn kein eigenes Foto da ist.
    var remoteImageURL: URL? {
        guard entry.imageData?.isEmpty != false, let s = entry.imageUrl else { return nil }
        return RemoteProductImage.allowedURL(s)
    }
}
