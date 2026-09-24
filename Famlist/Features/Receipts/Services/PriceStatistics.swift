/*
 PriceStatistics.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kennzahlen für „Preisverlauf“: Tiefster, Schnitt, Höchster Preis, Monatswerte fürs Diagramm und
   Preise „Nach Laden“ mit Markierung „GÜNSTIGSTER“.

 🔰 Notes for Beginners:
 - Monatswert = Durchschnitt aller Preise des Monats; das Diagramm zeigt die letzten 7 Monate.
 - „Nach Laden“ zeigt je Laden den letzten Preis; günstigster Laden = niedrigster letzter Preis.
 - Reine Funktionen → PriceStatisticsTests.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

struct PriceStatistics: Equatable {
    struct Month: Equatable {
        let start: Date
        /// nil = in diesem Monat kein Preis
        let average: Decimal?
    }

    struct StoreRow: Equatable {
        let store: String
        let lastPrice: Decimal
        let lastDate: Date
        let isCheapest: Bool
    }

    let min: Decimal?
    let average: Decimal?
    let max: Decimal?
    let months: [Month]
    let stores: [StoreRow]
    let latest: PricePoint?

    static func make(points: [PricePoint], now: Date = Date(), monthCount: Int = 7,
                     calendar: Calendar = Calendar(identifier: .gregorian)) -> PriceStatistics {
        let prices = points.map(\.price)
        let avg = prices.isEmpty ? nil : prices.reduce(0, +) / Decimal(prices.count)
        let latest = points.max { $0.purchasedAt < $1.purchasedAt }

        let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let months: [Month] = (0..<monthCount).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .month, value: -back, to: thisMonth),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            let inMonth = points.filter { $0.purchasedAt >= start && $0.purchasedAt < end }.map(\.price)
            return Month(start: start, average: inMonth.isEmpty ? nil : inMonth.reduce(0, +) / Decimal(inMonth.count))
        }

        let byStore = Dictionary(grouping: points, by: \.storeName)
        let lastPerStore = byStore.compactMap { store, pts -> (String, PricePoint)? in
            guard let last = pts.max(by: { $0.purchasedAt < $1.purchasedAt }) else { return nil }
            return (store, last)
        }
        let cheapest = lastPerStore.min { $0.1.price < $1.1.price }?.0
        let stores = lastPerStore
            .sorted { $0.1.purchasedAt > $1.1.purchasedAt }
            .map { StoreRow(store: $0.0, lastPrice: $0.1.price, lastDate: $0.1.purchasedAt,
                            isCheapest: lastPerStore.count > 1 && $0.0 == cheapest) }

        return PriceStatistics(min: prices.min(), average: avg, max: prices.max(), months: months,
                               stores: stores, latest: latest)
    }
}
