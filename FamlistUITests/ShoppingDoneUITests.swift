/*
 ShoppingDoneUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Letzten Artikel abhaken → „Einkauf erledigt“ mit Angebot „Kassenzettel scannen“ erscheint.

 🔰 Notes for Beginners:
 - `-uiTestFixture -designFixture`: genau ein offener Artikel „Butter“ (im Speicher, kein Netz).
 - „Liste behalten“ schließt den Screen wieder, die Liste bleibt unverändert.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class ShoppingDoneUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture", "-designFixture"]
        app.launch()
    }

    func test_checkingLastItem_offersShoppingDone_andKeepCloses() {
        let check = app.buttons["Butter abhaken"]
        XCTAssertTrue(check.waitForExistence(timeout: 15))
        check.tap()

        XCTAssertTrue(app.staticTexts["Einkauf erledigt"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Kassenzettel scannen"].exists)

        app.buttons["Liste behalten"].tap()
        XCTAssertTrue(app.staticTexts["Einkauf erledigt"].waitForNonExistence(timeout: 5))
    }
}
