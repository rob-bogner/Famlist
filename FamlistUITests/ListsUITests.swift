/*
 ListsUITests.swift
 FamlistUITests
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UI-Tests für „Meine Listen“ und die Listen-Optionen (langer Druck) auf der In-Memory-Liste.

 🔰 Notes for Beginners:
 - Fixture (-uiTestFixture): „My List“ (aktiv, Standard, eigene), „Drogerie“ (eigene), „WG-Einkauf“ (geteilt).
 - Redesign „Hybrid“ (24.09.2026): keine Wischaktionen mehr auf Listenkarten; alle Listen-Aktionen gibt es
   nur in den Listen-Optionen (SPEC §3.6).
 - Speichern (Anlegen, Umbenennen, Favorit) prüfen die Unit-Tests; die Fixture hat kein Listen-Repository.

 📝 Last Change:
 - Auf langen Druck und Listen-Optionen umgestellt (Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class ListsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture"]
        app.launch()
        let openLists = app.buttons["Liste wechseln, aktuell My List"]
        XCTAssertTrue(openLists.waitForExistence(timeout: 15))
        openLists.tap()
        XCTAssertTrue(card("Drogerie").waitForExistence(timeout: 5))
    }

    private func card(_ name: String) -> XCUIElement { app.buttons["\(name) öffnen"] }
    private var activeCard: XCUIElement { app.buttons["My List, aktive Liste"] }

    private func drag(_ element: XCUIElement, dx: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)),
                    withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.05)
        Thread.sleep(forTimeInterval: 1.0)
    }

    func test_A_showsAllListsWithActiveOne() {
        XCTAssertTrue(activeCard.exists)
        XCTAssertTrue(card("WG-Einkauf").exists)
        XCTAssertTrue(app.buttons["Neue Liste erstellen"].exists)
    }

    func test_B_ownList_longPress_showsAllOptions() {
        card("Drogerie").press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["Umbenennen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Duplizieren"].exists)
        XCTAssertTrue(app.buttons["Als Favorit markieren"].exists)
        XCTAssertTrue(app.buttons["Mitglieder & Teilen"].exists)
        XCTAssertTrue(app.staticTexts["Liste löschen"].exists)
    }

    func test_C_sharedList_longPress_offersLeave() {
        card("WG-Einkauf").press(forDuration: 0.8)
        XCTAssertTrue(app.staticTexts["Liste verlassen"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Liste löschen"].exists)
    }

    func test_D_activeFavorite_showsRemoveFavorite() {
        activeCard.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["Favorit entfernen"].waitForExistence(timeout: 3))
    }

    func test_E_swipe_hasNoActions() {
        drag(card("Drogerie"), dx: -200)
        XCTAssertFalse(app.buttons["Löschen"].exists)
        XCTAssertFalse(app.buttons["Umbenennen"].exists)
    }

    func test_F_tapOutsideOptions_returnsToLists() {
        card("Drogerie").press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["Duplizieren"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.9)).tap()
        XCTAssertTrue(app.buttons["Neue Liste erstellen"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Duplizieren"].exists)
    }

    func test_G_membersOption_opensShareSheet() {
        card("Drogerie").press(forDuration: 0.8)
        app.buttons["Mitglieder & Teilen"].tap()
        XCTAssertTrue(app.staticTexts["Mitglieder & Teilen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Link kopieren"].exists)
    }

    func test_H_tap_switchesListAndCloses() {
        card("Drogerie").tap()
        XCTAssertTrue(app.buttons["Liste wechseln, aktuell Drogerie"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Neue Liste erstellen"].exists)
    }

    func test_I_createButton_opensCreateSheet() {
        app.buttons["Neue Liste erstellen"].tap()
        XCTAssertTrue(app.staticTexts["Neue Liste"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Als Favorit"].exists)
        XCTAssertTrue(app.textFields.firstMatch.exists)
    }
}
