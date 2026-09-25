/*
 PricePointsRepository.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Speichert und liest Preispunkte (Tabelle `price_points`, Migration 012).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

/// `Sendable`: PriceBook (Main Actor) ruft die async-Methoden auf, die außerhalb des Main Actors laufen.
protocol PricePointsRepository: Sendable {
    func insert(_ points: [PricePoint]) async throws
    /// Alle Preise eines Artikels (item_key), älteste zuerst.
    func history(itemKey: String) async throws -> [PricePoint]
}

/// Für Vorschauen und Tests.
/// @MainActor schützt den veränderlichen Speicher; so ist die Klasse Sendable.
@MainActor
final class InMemoryPricePointsRepository: PricePointsRepository {
    private(set) var stored: [PricePoint]
    var failInsert = false

    init(_ stored: [PricePoint] = []) { self.stored = stored }

    func insert(_ points: [PricePoint]) async throws {
        if failInsert { throw URLError(.notConnectedToInternet) }
        stored += points
    }

    func history(itemKey: String) async throws -> [PricePoint] {
        stored.filter { $0.itemKey == itemKey }.sorted { $0.purchasedAt < $1.purchasedAt }
    }
}
