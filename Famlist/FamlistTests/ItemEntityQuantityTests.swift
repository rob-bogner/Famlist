/*
 ItemEntityQuantityTests.swift
 FamlistTests
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lokale Menge mit Nachkommastellen: `quantity` (neu, optional) neben dem ganzzahligen `units`.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ItemEntityQuantityTests: XCTestCase {

    /// Einträge von vor Migration 025 haben kein `quantity` → es gilt `units`.
    func test_amount_fallsBackToUnits_whenQuantityMissing() {
        let entity = ItemEntity.make(from: ItemModel(name: "Eier", units: 6, listId: UUID().uuidString))
        entity.quantity = nil
        XCTAssertEqual(entity.amount, 6)
        XCTAssertEqual(entity.toItemModel().units, 6)
    }

    /// Kommazahl: `quantity` genau, `units` aufgerundet (für ältere Leser).
    func test_amount_writesQuantityAndRoundedUnits() {
        let entity = ItemEntity.make(from: ItemModel(name: "Hack", units: 1.5, measure: "kg", listId: UUID().uuidString))
        XCTAssertEqual(entity.quantity, 1.5)
        XCTAssertEqual(entity.units, 2)
        XCTAssertEqual(entity.toItemModel().units, 1.5)

        entity.apply(model: ItemModel(name: "Hack", units: 0.25, measure: "kg", listId: UUID().uuidString))
        XCTAssertEqual(entity.amount, 0.25)
        XCTAssertEqual(entity.units, 1)
    }
}
