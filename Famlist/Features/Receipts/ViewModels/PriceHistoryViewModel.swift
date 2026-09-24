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

    init(entry: ItemCatalogEntry, priceBook: PriceBook) {
        self.entry = entry
        self.priceBook = priceBook
    }

    func load() async {
        isLoading = true
        points = await priceBook.history(itemName: entry.name)
        stats = PriceStatistics.make(points: points)
        isLoading = false
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
