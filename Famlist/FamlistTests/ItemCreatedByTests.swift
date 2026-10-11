/*
 ItemCreatedByTests.swift
 FamlistTests
 Created on: 11.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Geteilte Liste: „hinzugefügt von“ (items.created_by, Migration 037) kommt vom Server bis in die lokale
   Datenbank und bleibt bei späteren Änderungen erhalten.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ItemCreatedByTests: XCTestCase {
    func testDecodesCreatedBy() throws {
        let json = #"{"id":"6F1C2C1E-1B7B-4E5B-9B1A-0C7E2B2F3A10","name":"Äpfel","units":1,"measure":"kg","price":0,"isChecked":false,"created_by":"8b0e6a2c-5d1f-4c55-9e0a-1f2d3c4b5a69"}"#
        let item = try JSONDecoder().decode(ItemModel.self, from: Data(json.utf8))
        XCTAssertEqual(item.createdBy, "8b0e6a2c-5d1f-4c55-9e0a-1f2d3c4b5a69")
    }

    func testEntityKeepsCreatorWhenUpdateHasNone() {
        let listId = UUID().uuidString
        let creator = UUID().uuidString.lowercased()
        let entity = ItemEntity.make(from: ItemModel(name: "Äpfel", listId: listId, createdBy: creator))
        XCTAssertEqual(entity.toItemModel().createdBy, creator)
        // Lokale Änderung ohne created_by darf den Ersteller nicht löschen.
        entity.assignContent(from: ItemModel(name: "Äpfel rot", listId: listId))
        XCTAssertEqual(entity.createdBy, creator)
        XCTAssertEqual(entity.name, "Äpfel rot")
    }
}
