/*
 CheckUndoUITests.swift
 FamlistUITests
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abhaken mit Rückgängig: Nach dem Abhaken erscheint der Toast „„Name“ abgehakt“ bzw. „n Artikel abgehakt“
   mit „Rückgängig“; ein Tipp darauf entfernt die Haken wieder. Gilt für einen Artikel und für „Alle abhaken“
   (Abschnittskopf und Dock). „Einkauf erledigt“ erscheint erst, wenn der Toast weg ist.

 🔰 Notes for Beginners:
 - Fixture: 16 offene Artikel (`-uiTestFixture`, Daten im Speicher, kein Server).
 - Ein abgehakter Artikel wandert ans Ende der Liste und liegt dort außerhalb des Bildschirms (die Liste
   baut nur sichtbare Zeilen auf). Deshalb prüfen die Tests: Der Knopf „<Artikel> abhaken“ ist weg bzw. wieder da.

 📝 Last Change:
 - „Alle abhaken“ im Abschnittskopf und im Dock (12.10.2026).
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

    // MARK: - „Alle abhaken“ (Abschnittskopf und Dock)

    func test_checkAllInCategory_showsUndoToast_andUndoReopensItems() {
        app.buttons["Alle Obst & Gemüse abhaken"].tap()
        XCTAssertTrue(app.staticTexts["3 Artikel abgehakt"].waitForExistence(timeout: 3), "Toast nennt die Anzahl")
        XCTAssertTrue(app.buttons["Äpfel abhaken"].waitForNonExistence(timeout: 5), "Obst & Gemüse ist abgehakt")

        app.buttons["Rückgängig"].tap()
        XCTAssertTrue(app.buttons["Äpfel abhaken"].waitForExistence(timeout: 5), "Äpfel sind wieder offen")
        XCTAssertTrue(app.buttons["Bananen abhaken"].exists)
        XCTAssertTrue(app.buttons["Tomaten abhaken"].exists)
    }

    func test_dockCheckAll_showsUndoToast_beforeShoppingDone_andUndoReopensList() {
        app.buttons["Alle Artikel abhaken"].tap()
        XCTAssertTrue(app.staticTexts["16 Artikel abgehakt"].waitForExistence(timeout: 3), "Toast nennt die Anzahl")
        Thread.sleep(forTimeInterval: 2)                 // früher öffnete „Einkauf erledigt“ nach 0,7 s
        XCTAssertFalse(app.staticTexts["Einkauf erledigt"].exists, "das Angebot wartet auf den Toast")

        app.buttons["Rückgängig"].tap()
        XCTAssertTrue(app.buttons["Äpfel abhaken"].waitForExistence(timeout: 5), "die Liste ist wieder offen")
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(app.staticTexts["Einkauf erledigt"].exists, "nach „Rückgängig“ kein Angebot")
    }

    func test_dockCheckAll_withoutUndo_offersShoppingDoneAfterToast() {
        app.buttons["Alle Artikel abhaken"].tap()
        XCTAssertTrue(app.buttons["Rückgängig"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Einkauf erledigt"].waitForExistence(timeout: 10), "Angebot kommt nach dem Toast")
        XCTAssertFalse(app.buttons["Rückgängig"].exists, "der Toast ist weg")
    }
}
