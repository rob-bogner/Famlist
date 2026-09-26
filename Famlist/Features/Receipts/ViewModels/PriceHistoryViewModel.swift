/*
 PriceHistoryViewModel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lädt die Preispunkte eines Artikels und berechnet die Kennzahlen für „Preisverlauf“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class PriceHistoryViewModel: ObservableObject {
    @Published private(set) var points: [PricePoint] = []
    @Published private(set) var stats = PriceStatistics.make(points: [])
    @Published private(set) var isLoading = false

    let entry: ItemCatalogEntry
    private let priceBook: PriceBook
    /// Ladenname für den Ersatzpunkt (z. B. Listenname „Edeka“), wenn es noch keinen Verlauf gibt.
    private let fallbackStore: String

    init(entry: ItemCatalogEntry, priceBook: PriceBook, fallbackStore: String? = nil) {
        self.entry = entry
        self.priceBook = priceBook
        self.fallbackStore = fallbackStore ?? "Gespeicherter Preis"
    }

    /// Offline-First: zuerst sofort der lokale Stand, danach der Server (Audit M6 – vorher wartete die
    /// Anzeige ohne Netz, bis die Anfrage abbrach).
    func load() async {
        show(priceBook.localHistory(itemName: entry.name))
        isLoading = true
        show(await priceBook.history(itemName: entry.name))
        isLoading = false
    }

    private func show(_ history: [PricePoint]) {
        points = Self.withFallback(history, entry: entry, store: fallbackStore)
        stats = PriceStatistics.make(points: points)
    }

    /// Ohne Verlauf, aber mit gespeichertem Artikelpreis: dieser Preis als einziger Punkt (heute).
    /// So zeigt der Preisverlauf auch einen einzelnen Preis an statt „Noch keine Preise“.
    static func withFallback(_ history: [PricePoint], entry: ItemCatalogEntry, store: String,
                             now: Date = Date()) -> [PricePoint] {
        guard history.isEmpty, entry.price > 0 else { return history }
        return [PricePoint(itemName: entry.name, storeName: store, purchasedAt: now, price: decimal(entry.price))]
    }

    /// Double → Decimal auf 2 Nachkommastellen (1.49 bleibt 1.49 statt 1.4899999…).
    static func decimal(_ value: Double) -> Decimal {
        Decimal(string: String(format: "%.2f", value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
    }

    /// „250 g · zuletzt 2,49 € bei Edeka“ (Design); ohne Preise „Noch keine Preise“.
    var subtitle: String {
        let size = entry.measure.isEmpty ? nil : "1 \(Measure.fromExternal(entry.measure).localizedName)"
        guard let latest = stats.latest else { return [size, "Noch keine Preise"].compactMap { $0 }.joined(separator: " · ") }
        let price = PriceHistoryViewModel.euro(latest.price)
        return [size, "zuletzt \(price) bei \(latest.storeName)"].compactMap { $0 }.joined(separator: " · ")
    }

    static func euro(_ value: Decimal?) -> String {
        guard let value else { return "–" }
        return value.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
    }

    /// Monatskürzel wie im Design („Mär“, „Apr“ …).
    var monthLabels: [String] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLL"
        return stats.months.map { f.string(from: $0.start).replacingOccurrences(of: ".", with: "") }
    }

    /// „zuletzt im September“
    static func lastSeen(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLLL"
        return "zuletzt im \(f.string(from: date))"
    }
}
