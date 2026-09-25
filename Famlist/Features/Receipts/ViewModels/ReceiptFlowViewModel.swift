/*
 ReceiptFlowViewModel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ablauf „Kassenzettel“: Aufnahmen sammeln → Texterkennung → Positionen + Laden + Datum →
   Zuordnung zu Artikeln (korrigierbar) → „Preise speichern“ → „Einkauf erledigt“.

 🔰 Notes for Beginners:
 - Kandidaten für die Zuordnung sind die Artikel der aktuellen Liste und der Artikelstamm.
 - Korrigieren (nicht gestaltet, daher System-Dialog in der Ansicht): anderen Artikel wählen,
   „Als neuen Artikel speichern“ oder „Ignorieren“.
 - Gespeichert werden nur zugeordnete, geprüfte und bestätigte neue Positionen.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import UIKit

@MainActor
final class ReceiptFlowViewModel: ObservableObject {
    enum Phase: Equatable {
        case capturing
        case recognizing
        case review
        case done(saved: Int)
    }

    @Published var pages: [UIImage] = []
    @Published private(set) var phase: Phase = .capturing
    @Published var lines: [ReceiptReviewLine] = []
    @Published var storeName: String?
    @Published var purchaseDate: Date?
    @Published private(set) var receiptTotal: Decimal?
    @Published var errorMessage: String?

    private(set) var candidates: [String]
    private let catalog: (any ItemCatalogRepository)?
    private let priceBook: PriceBook
    /// Ersetzbar in Tests (Vision braucht echte Bilder).
    var recognize: ([UIImage]) async -> [String] = ReceiptTextRecognizer.recognizeLines(in:)

    init(listItemNames: [String], catalog: (any ItemCatalogRepository)?, priceBook: PriceBook) {
        self.candidates = listItemNames
        self.catalog = catalog
        self.priceBook = priceBook
    }

    /// Summe laut Bon, sonst Summe der Positionen.
    var total: Decimal { receiptTotal ?? lines.filter { !$0.ignored }.reduce(0) { $0 + $1.price } }

    var savableCount: Int { lines.filter(\.isSaved).count }

    // MARK: - Aufnahme

    func addPage(_ image: UIImage) { pages.append(image) }

    // MARK: - Erkennen

    func process() async {
        guard !pages.isEmpty else { return }
        phase = .recognizing
        if let entries = try? await catalog?.fetchAll() {
            candidates = Array(Set(candidates + entries.map(\.name)))
        }
        let text = await recognize(pages)
        apply(ReceiptParser.parse(lines: text))
    }

    /// Ergebnis des Parsers übernehmen und zuordnen.
    func apply(_ parsed: ParsedReceipt) {
        storeName = parsed.store
        purchaseDate = parsed.date
        receiptTotal = parsed.total
        lines = parsed.lines.map { line in
            let match = ReceiptItemMatcher.match(line.raw, candidates: candidates)
            return ReceiptReviewLine(id: line.id, raw: line.raw, price: line.price,
                                     itemName: match.status == .new ? Self.suggestedName(line.raw) : match.candidate,
                                     status: match.status)
        }
        UserLog.Data.receiptRecognized(lines: lines.count, store: storeName)
        errorMessage = lines.isEmpty ? "Auf dem Kassenzettel wurden keine Positionen erkannt." : nil
        phase = .review
    }

    // MARK: - Korrigieren

    func suggestions(for line: ReceiptReviewLine) -> [String] {
        ReceiptItemMatcher.suggestions(line.raw, candidates: candidates)
    }

    func assign(_ lineId: UUID, to name: String) {
        guard let i = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[i].itemName = name
        lines[i].status = .matched
        lines[i].ignored = false
    }

    func confirmNew(_ lineId: UUID) {
        guard let i = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[i].confirmedNew = true
        lines[i].ignored = false
    }

    func ignore(_ lineId: UUID) {
        guard let i = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[i].ignored = true
    }

    // MARK: - Speichern

    func savePrices() async {
        let store = (storeName?.isEmpty == false ? storeName : nil) ?? "Unbekannter Laden"
        let date = purchaseDate ?? Date()
        let points = lines.filter(\.isSaved).compactMap { line in
            line.itemName.map { PricePoint(itemName: $0, storeName: store, purchasedAt: date, price: line.price) }
        }
        let saved = await priceBook.save(points)
        phase = .done(saved: saved)
    }

    /// „KOKOSM. 400ML“ → „Kokosm. 400ml“ (Vorschlag für einen neuen Artikel).
    static func suggestedName(_ raw: String) -> String {
        raw.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
