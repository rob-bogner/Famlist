/*
 BarcodeScanViewModel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ablauf des Barcode-Scanners: Code erkennen → im Artikelstamm, dann im globalen Katalog suchen →
   Karte „Artikel erkannt“ oder „Neuer Artikel“ vorbefüllt.

 🔰 Notes for Beginners:
 - Bekannte Codes treffen einen Artikel; „Zur Liste hinzufügen“ legt ihn mit der gewählten Menge an.
 - Unbekannte Codes (oder keine Verbindung) melden `onUnknown(code)`; die Liste öffnet dann
   „Neuer Artikel“ und merkt sich den Code im Artikelstamm.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class BarcodeScanViewModel: ObservableObject {
    enum State: Equatable {
        case scanning
        case lookingUp(String)
        case found(ScannedProduct)
    }

    @Published private(set) var state: State = .scanning
    /// Menge im Kreis links neben „Zur Liste hinzufügen“ (1× … 9×).
    @Published var quantity = 1
    @Published var torchOn = false

    private let catalog: (any ItemCatalogRepository)?
    private let global: (any GlobalProductCatalogRepository)?

    init(catalog: (any ItemCatalogRepository)?, global: (any GlobalProductCatalogRepository)?) {
        self.catalog = catalog
        self.global = global
    }

    var isPaused: Bool { state != .scanning }

    /// Neuer Code aus der Kamera. Liefert den Code zurück, wenn er unbekannt ist.
    func handle(code: String) async -> String? {
        guard state == .scanning else { return nil }
        state = .lookingUp(code)
        if let product = await lookup(code) {
            quantity = 1
            state = .found(product)
            UserLog.Data.barcodeRecognized(name: product.entry.name)
            return nil
        }
        state = .scanning
        UserLog.Data.barcodeUnknown(code: code)
        return code
    }

    func lookup(_ code: String) async -> ScannedProduct? {
        if let own = try? await catalog?.find(barcode: code) {
            return ScannedProduct(barcode: code, entry: own, meta: ManageItemsViewModel.meta(for: own))
        }
        if let product = try? await global?.product(code: code) {
            var entry = product.toItemCatalogEntry(ownerPublicId: "")
            entry.barcode = code
            let meta = [product.brand, product.measure].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            return ScannedProduct(barcode: code, entry: entry, meta: meta)
        }
        return nil
    }

    func cycleQuantity() {
        quantity = quantity >= 9 ? 1 : quantity + 1
    }

    /// „Weiter scannen“ bzw. nach dem Hinzufügen.
    func resume() {
        state = .scanning
        quantity = 1
    }
}
