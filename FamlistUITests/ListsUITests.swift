/*
 ListsUITests.swift
 FamlistUITests
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UI-Tests für das Sheet „Meine Listen“ (MyListsSheet / SwipeableListCard) auf der In-Memory-Liste.

 🔰 Notes for Beginners:
 - Fixture (-uiTestFixture): „My List“ (aktiv, Standard, eigene), „Drogerie“ (eigene), „WG-Einkauf“ (geteilt).
 - Erwartete Wischwege: eigene Liste links 172 pt (Löschen + Umbenennen), geteilte 88 pt (nur Umbenennen),
   rechts 96 pt („Standard“, nur eigene Liste, die noch nicht Standard ist).
 - Speichern (Anlegen, Umbenennen, Standard) prüfen die Unit-Tests; die Fixture hat kein Listen-Repository.

 📝 Last Change:
 - Initial creation („Meine Listen“ im Hybrid-Design).
 ------------------------------------------------------------------------
 */

import XCTest

final class ListsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
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

    private func drag(_ element: XCUIElement, dx: CGFloat, velocity: CGFloat = 600) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)),
                    withVelocity: XCUIGestureVelocity(velocity), thenHoldForDuration: 0.05)
        Thread.sleep(forTimeInterval: 1.0)
    }

    func test_A_showsAllListsWithActiveOne() {
        XCTAssertTrue(activeCard.exists)
        XCTAssertTrue(card("WG-Einkauf").exists)
        XCTAssertTrue(app.buttons["Neue Liste erstellen"].exists)
    }

    func test_B_ownList_leftSwipe_revealsDeleteAndRename() {
        let rest = card("Drogerie").frame.minX
        drag(card("Drogerie"), dx: -200)
        XCTAssertEqual(card("Drogerie").frame.minX, rest - 172, accuracy: 4)
    }

    func test_C_sharedList_leftSwipe_revealsRenameOnly() {
        let rest = card("WG-Einkauf").frame.minX
        drag(card("WG-Einkauf"), dx: -150)
        XCTAssertEqual(card("WG-Einkauf").frame.minX, rest - 88, accuracy: 4)
    }

    func test_D_ownList_rightSwipe_revealsStandard() {
        let rest = card("Drogerie").frame.minX
        drag(card("Drogerie"), dx: 110, velocity: 500)
        XCTAssertEqual(card("Drogerie").frame.minX, rest + 96, accuracy: 4)
    }

    func test_E_defaultList_rightSwipe_staysClosed() {
        let rest = activeCard.frame.minX
        drag(activeCard, dx: 150)
        XCTAssertEqual(activeCard.frame.minX, rest, accuracy: 2)
    }

    func test_F_leftFullSwipe_doesNotDelete() {
        drag(card("Drogerie"), dx: -330, velocity: 800)
        XCTAssertTrue(card("Drogerie").exists)
        XCTAssertFalse(app.staticTexts["„Drogerie“ löschen?"].exists, "no delete confirmation")
    }

    func test_G_longPress_showsContextMenu() {
        card("Drogerie").press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Umbenennen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Als Standard setzen"].exists)
        XCTAssertTrue(app.buttons["Löschen"].exists)
    }

    func test_H_tap_switchesListAndCloses() {
        card("Drogerie").tap()
        XCTAssertTrue(app.buttons["Liste wechseln, aktuell Drogerie"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Neue Liste erstellen"].exists)
    }

    func test_I_createButton_opensNameSheet() {
        app.buttons["Neue Liste erstellen"].tap()
        XCTAssertTrue(app.staticTexts["Neue Liste"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.textFields.firstMatch.exists)
    }
}
