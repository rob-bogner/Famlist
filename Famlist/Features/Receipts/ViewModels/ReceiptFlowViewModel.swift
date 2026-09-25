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
 - Preise je Stück: Bei „2 Stk x 1,29“ speichert der Preisverlauf 1,29 €, nicht den Zeilenbetrag 2,58 €.
 - `priceChanges`: zugeordnete Artikel, deren gespeicherter Preis (Liste oder Artikelstamm) vom Bon abweicht.
   „Kassenzettel prüfen“ fragt vor dem Speichern, ob diese Preise die Artikelpreise ersetzen sollen.

 📝 Last Change:
 - Rückfrage „Artikelpreise aktualisieren?“ vorbereitet (`priceChanges`); Preispunkte je Stück.
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
    /// Bekannte Artikelpreise je Name-Schlüssel (CatalogOperation.key): aus der Liste und aus dem Artikelstamm.
    private let listPrices: [String: Double]
    private var catalogPrices: [String: Double] = [:]
    private let catalog: (any ItemCatalogRepository)?
    private let priceBook: PriceBook
    /// Ersetzbar in Tests (Vision braucht echte Bilder).
    var recognize: ([UIImage]) async -> [String] = ReceiptTextRecognizer.recognizeLines(in:)

    /// `listPrices`: Artikelname → Preis der Artikel in der geöffneten Liste.
    init(listItemNames: [String], listPrices: [String: Double] = [:], catalog: (any ItemCatalogRepository)?,
         priceBook: PriceBook) {
        self.candidates = listItemNames
        self.listPrices = Dictionary(listPrices.map { (CatalogOperation.key($0.key), $0.value) },
                                     uniquingKeysWith: { first, _ in first })
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
            catalogPrices = Dictionary(entries.map { (CatalogOperation.key($0.name), $0.price) },
                                       uniquingKeysWith: { first, _ in first })
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
                                     status: match.status, quantity: line.quantity)
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
            line.itemName.map { PricePoint(itemName: $0, storeName: store, purchasedAt: date, price: line.unitPrice) }
        }
        let saved = await priceBook.save(points)
        phase = .done(saved: saved)
    }

    // MARK: - Artikelpreise

    /// Zugeordnete Artikel, deren Bon-Preis je Stück vom gespeicherten Artikelpreis abweicht.
    /// Neue Artikel zählen nicht (es gibt keinen Artikel, dessen Preis sich ändern könnte).
    /// Steht ein Artikel mehrmals auf dem Bon, gilt die letzte Position.
    var priceChanges: [ReceiptPriceChange] {
        var latest: [String: ReceiptPriceChange] = [:]
        for line in lines where line.isSaved && line.status != .new && line.unitPrice > 0 {
            guard let name = line.itemName else { continue }
            // Über den Text: NSDecimalNumber.doubleValue macht aus 2,49 den Wert 2,4899999999999998.
            let change = ReceiptPriceChange(name: name, price: Double(line.unitPrice.description) ?? 0)
            latest[change.key] = change
        }
        return latest.values
            .filter { change in
                let known = [listPrices[change.key], catalogPrices[change.key]].compactMap { $0 }
                return !known.isEmpty && known.contains { abs($0 - change.price) > 0.004 }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Text der Rückfrage: bis zu 5 Artikel mit neuem Preis, danach „und n weitere“.
    static func priceChangeMessage(_ changes: [ReceiptPriceChange]) -> String {
        let shown = changes.prefix(5).map { "\($0.name): \(PriceDisplaySetting.euro($0.price))" }
        let more = changes.count > 5 ? ["und \(changes.count - 5) weitere"] : []
        let intro = changes.count == 1
            ? "Bei 1 Artikel weicht der Preis auf dem Kassenzettel vom gespeicherten Preis ab."
            : "Bei \(changes.count) Artikeln weicht der Preis auf dem Kassenzettel vom gespeicherten Preis ab."
        return ([intro, ""] + shown + more).joined(separator: "\n")
    }

    /// „KOKOSM. 400ML“ → „Kokosm. 400ml“ (Vorschlag für einen neuen Artikel).
    static func suggestedName(_ raw: String) -> String {
        raw.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
