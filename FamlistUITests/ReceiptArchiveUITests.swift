/*
 ReceiptArchiveUITests.swift
 FamlistUITests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UI-Test Kassenzettel-Archiv (Fixture, kein Server): Einstellungen → „Gespeicherte Kassenzettel“ →
   Filter nach Laden → Detail → Löschen mit Rückfrage → zurück im Archiv, ein Bon weniger.

 🔰 Notes for Beginners:
 - `-designFixture` füllt das Archiv mit den zwölf Beispiel-Bons aus ReceiptArchive.dc.html.
 - Die Bons von „Rob“ gehören dem Fixture-Konto; nur sie zeigen „Löschen“.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class ReceiptArchiveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture", "-designFixture", "-designSheet", "settings"]
        app.launch()
    }

    func test_settings_archive_filter_detail_delete() {
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["12 Bons · 38 MB"].exists)
        open.tap()

        XCTAssertTrue(app.staticTexts["12 Bons · 38 MB · für alle in der Liste sichtbar"].waitForExistence(timeout: 5))
        let edeka = app.buttons["Edeka, 24.09.2026 · Liste Edeka, 5 Positionen, 11,51\u{00A0}€"]
        XCTAssertTrue(edeka.exists)

        // Filter „Rewe“: nur Rewe-Bons, der Edeka-Bon verschwindet; zurück auf „Alle“.
        app.buttons["Rewe"].tap()
        XCTAssertTrue(edeka.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Rewe, 19.09.2026 · Wocheneinkauf, 23 Positionen, 64,87\u{00A0}€"].exists)
        app.buttons["Alle"].tap()
        XCTAssertTrue(edeka.waitForExistence(timeout: 3))

        edeka.tap()
        XCTAssertTrue(app.staticTexts["24.09.2026 · Liste Edeka · gescannt von Rob"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Summe laut Bon"].exists)
        XCTAssertTrue(app.buttons["Vollbild"].exists)

        app.buttons["Löschen"].tap()
        let confirm = app.buttons.matching(identifier: "Löschen").element(boundBy: 1)
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "Rückfrage erscheint")
        confirm.tap()

        let remaining = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '11 Bons · '")).firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5), "Archiv zählt einen Bon weniger")
        XCTAssertTrue(edeka.waitForNonExistence(timeout: 3))
    }

    func test_foreignReceipt_hasNoDelete() {
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let rewe = app.buttons["Rewe, 19.09.2026 · Wocheneinkauf, 23 Positionen, 64,87\u{00A0}€"]   // gescannt von Anna
        XCTAssertTrue(rewe.waitForExistence(timeout: 5))
        rewe.tap()
        XCTAssertTrue(app.staticTexts["Summe laut Bon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Teilen"].exists)
        XCTAssertFalse(app.buttons["Löschen"].exists)
    }
}
