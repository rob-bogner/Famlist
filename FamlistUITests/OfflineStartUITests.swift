/*
 OfflineStartUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Live-Test (Testkonto „Tester“): Nach einmaliger Anmeldung startet die App OHNE Netz direkt in die
   Liste (nicht in „Anmelden“), zeigt die gespeicherten Artikel und nimmt offline neue Artikel an.
   Danach, wieder online, bleibt der offline angelegte Artikel erhalten.

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_LIVE=1`. „Ohne Netz“ = Startargument `-simulateOffline`
   (nur DEBUG, siehe SimulatedOffline.swift).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, K6 Offline-Start).
 ------------------------------------------------------------------------
 */

import XCTest

final class OfflineStartUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FAMLIST_LIVE"] == "1", "nur mit TEST_RUNNER_FAMLIST_LIVE=1")
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private var searchButton: XCUIElement { app.buttons["Artikel suchen oder hinzufügen"] }

    private func signInIfNeeded() {
        if searchButton.waitForExistence(timeout: 12) { return }
        let profileDone = app.buttons["Los geht’s"]
        if profileDone.exists {
            profileDone.tap()
            XCTAssertTrue(searchButton.waitForExistence(timeout: 20))
            return
        }
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 72, dy: 195)).press(forDuration: 1.2)
        let tester = app.buttons["Tester"]
        XCTAssertTrue(tester.waitForExistence(timeout: 5), "Testkonten-Dialog")
        tester.tap()
        completeProfileIfAsked()
        XCTAssertTrue(searchButton.waitForExistence(timeout: 30), "Liste nach Anmeldung")
    }

    /// Konto ohne Benutzernamen → „Profil anlegen“ bestätigen.
    private func completeProfileIfAsked() {
        let profileDone = app.buttons["Los geht’s"]
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, !searchButton.exists {
            if profileDone.exists { profileDone.tap(); return }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    private func createNew(_ name: String) {
        searchButton.tap()
        let field = app.textFields["Artikel suchen"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        let cta = app.buttons["Neu anlegen: „\(name)“"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8), "Neu anlegen")
        cta.tap()
        let save = app.buttons["Zur Liste hinzufügen"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Formular „Neuer Artikel“")
        save.tap()
    }

    func test_offlineStart_opensList_andAcceptsNewItems() {
        let stamp = Int(Date().timeIntervalSince1970) % 100000
        let online = "Offlineprobe A\(stamp)"
        let offline = "Offlineprobe B\(stamp)"

        // 1. Online anmelden und einen Artikel anlegen
        app.launch()
        signInIfNeeded()
        createNew(online)
        XCTAssertTrue(app.buttons["\(online) abhaken"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 3)                                  // senden lassen
        app.terminate()

        // 2. Ohne Netz neu starten: Liste statt „Anmelden“, Artikel aus dem lokalen Speicher
        app.launchArguments = ["-simulateOffline"]
        app.launch()
        XCTAssertTrue(searchButton.waitForExistence(timeout: 20), "Offline-Start zeigt die Liste")
        XCTAssertFalse(app.buttons["Weiter mit E-Mail"].exists, "kein Anmeldebildschirm")
        XCTAssertTrue(app.buttons["\(online) abhaken"].waitForExistence(timeout: 5), "gespeicherter Artikel sichtbar")

        // 3. Offline hinzufügen
        createNew(offline)
        XCTAssertTrue(app.buttons["\(offline) abhaken"].waitForExistence(timeout: 5), "offline sofort sichtbar")
        app.terminate()

        // 4. Wieder online: offline angelegter Artikel bleibt (und wird gesendet)
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["\(offline) abhaken"].waitForExistence(timeout: 20), "nach Rückkehr online erhalten")
        Thread.sleep(forTimeInterval: 4)                                  // senden lassen
        XCTAssertTrue(app.buttons["\(offline) abhaken"].exists, "nicht durch Server-Abgleich verschwunden")
    }
}
