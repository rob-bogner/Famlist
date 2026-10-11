/*
 CheckUndoUITests.swift
 FamlistUITests
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abhaken mit Rückgängig: Nach dem Abhaken eines Artikels erscheint der Toast „„Name“ abgehakt“ mit
   „Rückgängig“; ein Tipp darauf entfernt den Haken wieder.

 🔰 Notes for Beginners:
 - Fixture: 16 offene Artikel (`-uiTestFixture`, Daten im Speicher, kein Server).
 - Ein abgehakter Artikel wandert ans Ende der Liste und liegt dort außerhalb des Bildschirms (die Liste
   baut nur sichtbare Zeilen auf). Deshalb prüfen die Tests: Der Knopf „<Artikel> abhaken“ ist weg bzw. wieder da.

 📝 Last Change:
 - Initial creation (Wunsch Robert 12.10.2026).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class CheckUndoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture"]
        app.launch()
        XCTAssertTrue(app.buttons["Äpfel abhaken"].waitForExistence(timeout: 15))
    }

    func test_check_showsUndoToast_andUndoRemovesCheck() {
        app.buttons["Äpfel abhaken"].tap()
        XCTAssertTrue(app.staticTexts["„Äpfel“ abgehakt"].waitForExistence(timeout: 3), "Toast nennt den Artikel")
        XCTAssertTrue(app.buttons["Äpfel abhaken"].waitForNonExistence(timeout: 5), "Äpfel sind abgehakt")
        // Sichtkontrolle wie in der Screenshot-Tour: TEST_RUNNER_FAMLIST_SHOTS=<Ordner> legt ein Bild des Toasts ab.
        if let folder = ProcessInfo.processInfo.environment["FAMLIST_SHOTS"] {
            let url = URL(fileURLWithPath: folder).appendingPathComponent("CheckUndoToast.png")
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        }

        let undo = app.buttons["Rückgängig"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()

        XCTAssertTrue(app.buttons["Äpfel abhaken"].waitForExistence(timeout: 5), "Äpfel sind wieder offen")
        XCTAssertTrue(undo.waitForNonExistence(timeout: 3), "Toast ist weg")
    }

    func test_undoToast_disappearsAfterFiveSeconds_checkStays() {
        app.buttons["Äpfel abhaken"].tap()
        let undo = app.buttons["Rückgängig"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertTrue(undo.waitForNonExistence(timeout: 8), "Toast blendet nach 5 s aus")
        XCTAssertFalse(app.buttons["Äpfel abhaken"].exists, "der Haken bleibt")
    }

    func test_secondCheck_replacesToast() {
        app.buttons["Äpfel abhaken"].tap()
        XCTAssertTrue(app.staticTexts["„Äpfel“ abgehakt"].waitForExistence(timeout: 3))
        app.buttons["Bananen abhaken"].tap()
        XCTAssertTrue(app.staticTexts["„Bananen“ abgehakt"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["„Äpfel“ abgehakt"].exists)

        app.buttons["Rückgängig"].tap()
        XCTAssertTrue(app.buttons["Bananen abhaken"].waitForExistence(timeout: 5), "Bananen sind wieder offen")
        XCTAssertFalse(app.buttons["Äpfel abhaken"].exists, "Äpfel bleiben abgehakt")
    }
}
