/*
 LiveDuplicateAddUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Live-Test gegen Supabase (Simulator-Testkonto „Tester“): Artikel hinzufügen, der schon auf der
   Liste steht → Karte zeigt sofort die erhöhte Menge, auch nach dem Realtime-Echo und einem Listenwechsel.

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_LIVE=1 xcodebuild test …` (echtes Netz, echte Daten des Testkontos).
 - Anmeldung: langer Druck auf die Korb-Kachel (nur DEBUG/Simulator) → „Tester“.

 📝 Last Change:
 - Initial creation (Gerätefehler 25.09.2026: Menge/Foto nach Doppelt-Hinzufügen nicht aktualisiert).
 ------------------------------------------------------------------------
 */

import XCTest

final class LiveDuplicateAddUITests: XCTestCase {
    private var app: XCUIApplication!
    private let shots = ProcessInfo.processInfo.environment["FAMLIST_SHOTS"]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FAMLIST_LIVE"] == "1", "nur mit TEST_RUNNER_FAMLIST_LIVE=1")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func shot(_ name: String) {
        guard let shots else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
    }

    /// Meldet das Testkonto an, falls der Anmeldebildschirm erscheint.
    private func signInIfNeeded() {
        let list = app.buttons["Artikel suchen oder hinzufügen"]
        if list.waitForExistence(timeout: 12) { return }
        let profileDone = app.buttons["Los geht’s"]
        if profileDone.exists {                               // Konto ohne Benutzernamen → „Profil anlegen“
            profileDone.tap()
            XCTAssertTrue(list.waitForExistence(timeout: 20), "Liste nach Profil anlegen")
            return
        }
        shot("signin")
        // Korb-Kachel: 86 × 86 im Hero, links oben (VoiceOver-verborgen) → Koordinate.
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 72, dy: 195)).press(forDuration: 1.2)
        let tester = app.buttons["Tester"]
        XCTAssertTrue(tester.waitForExistence(timeout: 5), "Testkonten-Dialog")
        tester.tap()
        XCTAssertTrue(list.waitForExistence(timeout: 30), "Liste nach Anmeldung")
    }

    private func addFromSearch(_ name: String) {
        app.buttons["Artikel suchen oder hinzufügen"].tap()
        let field = app.textFields["Artikel suchen"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        let add = app.buttons["\(name) hinzufügen"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
    }

    /// Neuer Artikel über Suche → „Neu anlegen“ → „Zur Liste hinzufügen“ (landet auch im Artikelstamm).
    private func createNew(_ name: String) {
        app.buttons["Artikel suchen oder hinzufügen"].tap()
        let field = app.textFields["Artikel suchen"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        Thread.sleep(forTimeInterval: 1.5)                   // Suche (Entprellung + Netz)
        let cta = app.buttons["Neu anlegen: „\(name)“"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "Neu anlegen")
        cta.tap()
        let nameField = app.textFields.matching(NSPredicate(format: "value == %@ OR placeholderValue == %@ OR label == %@",
                                                            name, "Name", "Name")).firstMatch
        if nameField.waitForExistence(timeout: 3), (nameField.value as? String) != name {
            nameField.tap(); nameField.typeText(name)
        }
        let save = app.buttons["Zur Liste hinzufügen"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Formular „Neuer Artikel“")
        shot("new-item")
        save.tap()
    }

    /// Menge der Karte „name“ (erster Text mit Ziffer in der Zeile).
    private func quantity(of name: String) -> String? {
        let check = app.buttons["\(name) abhaken"]
        guard check.waitForExistence(timeout: 10) else { return nil }
        let row = check.frame
        return app.staticTexts.allElementsBoundByIndex
            .filter { abs($0.frame.midY - row.midY) < 40 && $0.label.first?.isNumber == true }
            .first?.label
    }

    func test_live_addExistingItem_updatesQuantity() {
        signInIfNeeded()
        shot("list0")
        let name = "Livetest \(Int(Date().timeIntervalSince1970) % 100000)"
        createNew(name)
        XCTAssertTrue(app.buttons["\(name) abhaken"].waitForExistence(timeout: 10), "Artikel steht auf der Liste")
        // Wie auf dem Gerät: Artikel kommt nach einem Neustart aus dem lokalen Speicher.
        Thread.sleep(forTimeInterval: 3)                     // Sync + Echo abwarten
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["\(name) abhaken"].waitForExistence(timeout: 20), "nach Neustart")
        Thread.sleep(forTimeInterval: 3)                     // Start-Sync abwarten
        let before = Int(quantity(of: name)?.split(separator: " ").first ?? "") ?? -1
        shot("before")

        addFromSearch(name)
        let expected = before + 1
        let deadline = Date().addingTimeInterval(4)
        var shown = before
        while Date() < deadline {
            shown = Int(quantity(of: name)?.split(separator: " ").first ?? "") ?? -1
            if shown == expected { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        shot("after-add")
        XCTAssertEqual(shown, expected, "sofort nach dem Hinzufügen")

        Thread.sleep(forTimeInterval: 4)                     // Realtime-Echo abwarten
        shot("after-echo")
        XCTAssertEqual(Int(quantity(of: name)?.split(separator: " ").first ?? "") ?? -1, expected, "nach dem Realtime-Echo")
    }
}
