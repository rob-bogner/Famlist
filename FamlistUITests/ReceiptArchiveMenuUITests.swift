/*
 ReceiptArchiveMenuUITests.swift
 FamlistUITests

 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UI-Test (Fixture, kein Server): ☰ → „Gespeicherte Kassenzettel“ öffnet das Archiv direkt über der Liste;
   Detail → „Zurück“ → Archiv → „Zurück“ schließt (keine Einstellungen darunter).

 📝 Last Change:
 - Detail an der neuen Unterzeile erkennen (Einkaufsdaten).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert.
@MainActor
final class ReceiptArchiveMenuUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture", "-designFixture"]
        app.launch()
    }

    func test_menu_opensArchive_backClosesWithoutSettings() {
        app.buttons["Mehr"].firstMatch.tap()
        let menuItem = app.buttons["Gespeicherte Kassenzettel"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "Menüeintrag")
        menuItem.tap()

        let summary = app.staticTexts["12 Bons · 38 MB · für alle in der Liste sichtbar"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Archiv offen")
        XCTAssertFalse(app.descendants(matching: .any)["Fotos der Bons speichern"].exists, "Keine Einstellungen darunter")

        let edeka = app.buttons["Edeka, 24.09.2026 · Liste Edeka, 5 Positionen, 11,51\u{00A0}€"]
        edeka.tap()
        XCTAssertTrue(app.staticTexts["Liste Edeka · gescannt von Rob"].waitForExistence(timeout: 5), "Detail")
        app.buttons["Zurück"].firstMatch.tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "zurück im Archiv")

        app.buttons["Zurück"].firstMatch.tap()
        XCTAssertTrue(summary.waitForNonExistence(timeout: 5), "Archiv geschlossen")
        XCTAssertTrue(app.buttons["Mehr"].firstMatch.waitForExistence(timeout: 5), "zurück in der Liste")
        XCTAssertFalse(app.descendants(matching: .any)["Fotos der Bons speichern"].exists, "Einstellungen nicht geöffnet")
    }
}
