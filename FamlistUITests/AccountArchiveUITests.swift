/*
 AccountArchiveUITests.swift
 FamlistUITests
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Konto-Archiv in der App (Fixture, kein Server): Screen „Konto wiederherstellen“ mit allen Knöpfen,
   Bestätigung „Jetzt endgültig löschen?“ öffnen und abbrechen, Offline-Hinweis, gelöschtes Mitglied in
   „Mitglieder & Teilen“ mit Bestätigung, Hinweis-Toast für den Besitzer.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 5).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class AccountArchiveUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture", "-designFixture"] + extra
        app.launch()
        return app
    }

    /// Element, dessen VoiceOver-Beschriftung so beginnt (zusammengefasste Elemente: Name + Zeile darunter).
    private func element(_ app: XCUIApplication, startingWith text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
    }

    func test_restoreAccount_showsContentAndPurgeConfirmation() {
        let app = launch(["-designScreen", "restoreAccount"])
        XCTAssertTrue(app.staticTexts["Konto wiederherstellen?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Noch 60 Tage"].exists)
        XCTAssertTrue(app.staticTexts["Angemeldet als rob@beispiel.de"].exists)
        XCTAssertTrue(app.buttons["Konto wiederherstellen"].exists)
        XCTAssertTrue(app.buttons["Abmelden"].exists)

        app.buttons["Endgültig löschen"].tap()
        XCTAssertTrue(app.staticTexts["Jetzt endgültig löschen?"].waitForExistence(timeout: 3))
        app.buttons["actionCardClose"].tap()                                 // ✕ statt „Abbrechen“
        XCTAssertTrue(app.staticTexts["Jetzt endgültig löschen?"].waitForNonExistence(timeout: 3))
    }

    func test_restoreAccount_offline_showsNoticeAndHidesMail() {
        let app = launch(["-designScreen", "restoreAccountOffline"])
        XCTAssertTrue(app.staticTexts["Zum Wiederherstellen brauchst du eine Internetverbindung."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Angemeldet als rob@beispiel.de"].exists)
        app.buttons["Endgültig löschen"].tap()
        XCTAssertFalse(app.staticTexts["Jetzt endgültig löschen?"].waitForExistence(timeout: 1), "Offline: keine Bestätigung")
    }

    func test_shareMembers_archivedMember_removeAsksFirst() {
        let app = launch(["-designSheet", "shareMembersArchived"])
        XCTAssertTrue(element(app, startingWith: "Sofie, Konto gelöscht").waitForExistence(timeout: 5))
        app.buttons["Sofie entfernen"].tap()
        XCTAssertTrue(app.staticTexts["Sofie aus der Liste entfernen?"].waitForExistence(timeout: 3))
        let remove = app.buttons["Mitglied entfernen"]                          // Schieben zum Löschen
        XCTAssertTrue(remove.waitForExistence(timeout: 3))
        slide(remove)
        XCTAssertTrue(element(app, startingWith: "Sofie, Konto gelöscht").waitForNonExistence(timeout: 3))
    }

    func test_memberDeletedToast_appearsInList() {
        let app = launch(["-designOverlay", "memberDeleted"])
        XCTAssertTrue(element(app, startingWith: "Sofie hat das Konto gelöscht").waitForExistence(timeout: 5))
    }

    /// „Schieben zum Löschen“: vom linken Rand der Spur bis ganz nach rechts ziehen.
    private func slide(_ element: XCUIElement) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
