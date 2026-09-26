/*
 WatchMessageCodingTests.swift
 FamlistTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Jede Nachricht zwischen iPhone und Uhr übersteht Kodieren und Dekodieren (Property-List-Form);
   eine unbekannte Version wird abgelehnt; Artikel reisen ohne Fotos und in Teilen zu 50.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class WatchMessageCodingTests: XCTestCase {
    private func roundTrip(_ message: WatchMessage) throws -> WatchMessage {
        let dictionary = try message.dictionary()
        // Wie WatchConnectivity: nur Property-List-Werte erlaubt.
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
        let decoded = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        return try WatchMessage(dictionary: decoded)
    }

    func test_everyMessage_survivesRoundTrip() throws {
        let item = ItemModel(id: UUID().uuidString, name: "Milch", units: 2, measure: "l", isChecked: true,
                             category: "Milchprodukte", listId: UUID().uuidString, hlcTimestamp: 1_790_000_000_000,
                             hlcCounter: 3, hlcNodeId: "watch", tombstone: false)
        let messages: [WatchMessage] = [
            .requestSession,
            .sessionGrant(tokenHash: "abc123", userId: UUID()),
            .sessionUnavailable(reason: .rateLimited),
            .sessionUnavailable(reason: .signedOut),
            .itemsChanged([item]),
            .signedOut
        ]
        for message in messages {
            XCTAssertEqual(try roundTrip(message), message)
        }
    }

    func test_unknownVersion_isRejected() throws {
        var dictionary = try WatchMessage.requestSession.dictionary()
        dictionary["v"] = WatchMessage.version + 1
        XCTAssertThrowsError(try WatchMessage(dictionary: dictionary)) { error in
            XCTAssertEqual(error as? WatchMessage.CodingError, .unsupportedVersion(WatchMessage.version + 1))
        }
        XCTAssertThrowsError(try WatchMessage(dictionary: ["v": WatchMessage.version]))
    }

    func test_itemBatches_dropImages_andSplitInFifties() {
        let items = (0..<120).map { ItemModel(id: UUID().uuidString, imageData: "BASE64", name: "Artikel \($0)") }
        let batches = WatchMessage.itemBatches(items)
        let sizes = batches.map { message -> Int in
            guard case .itemsChanged(let chunk) = message else { return -1 }
            XCTAssertTrue(chunk.allSatisfy { $0.imageData == nil }, "Fotos reisen nicht mit")
            return chunk.count
        }
        XCTAssertEqual(sizes, [50, 50, 20])
    }

    func test_applicationContext_roundTrip_andEmptyIsNil() throws {
        let context = WatchApplicationContext(userId: UUID(), changedListIds: [UUID()])
        let data = try PropertyListSerialization.data(fromPropertyList: try context.dictionary(), format: .binary, options: 0)
        let decoded = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(WatchApplicationContext(dictionary: decoded), context)
        XCTAssertNil(WatchApplicationContext(dictionary: [:]), "iPhone hat noch nie gesendet")
    }
}
