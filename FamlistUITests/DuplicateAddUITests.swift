/*
 DuplicateAddUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression: Einen Artikel hinzufügen, der schon auf der Liste steht, erhöht die angezeigte Menge sofort.

 🔰 Notes for Beginners:
 - Fixture: „Brot“ steht mit Menge 1 (ohne Einheit) auf der Liste; der Beispiel-Artikelstamm kennt „Brot“
   mit Einheit „Stück“. Nach dem Hinzufügen muss die Karte „2 Stück“ zeigen.
 - Gerätefehler 25.09.2026: Daten waren korrekt (Menge erhöht), die Karte zeigte weiter den alten Wert.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class DuplicateAddUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture"]
        app.launch()
    }

    private func addFromSearch(_ name: String) {
        app.buttons["Artikel suchen oder hinzufügen"].tap()
        let field = app.textFields["Artikel suchen"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        let add = app.buttons["\(name) hinzufügen"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
    }

    /// Wie auf dem Gerät: der Artikel hat ein großes Foto.
    func test_addExistingItemWithLargeImage_showsIncreasedQuantity() {
        app.terminate()
        app.launchArguments = ["-uiTestFixture", "-fixtureLargeImage"]
        app.launch()
        test_addExistingItem_showsIncreasedQuantityImmediately()
    }

    func test_addExistingItem_showsIncreasedQuantityImmediately() {
        XCTAssertTrue(app.buttons["Brot abhaken"].waitForExistence(timeout: 15))
        addFromSearch("Brot")
        XCTAssertTrue(app.staticTexts["2 Stück"].waitForExistence(timeout: 5), "Karte zeigt die erhöhte Menge")

        addFromSearch("Brot")
        XCTAssertTrue(app.staticTexts["3 Stück"].waitForExistence(timeout: 5), "auch beim zweiten Mal")
    }
}
