/*
 LiveReceiptSteps.swift
 FamlistUITests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gemeinsame Schritte der Live-Tests zum Kassenzettel: anmelden (Testkonto „Tester“), Artikel neu anlegen,
   Bon aus der Fotomediathek scannen, auf eine Bedingung warten.

 🔰 Notes for Beginners:
 - Aus LiveReceiptPriceUITests.swift ausgelagert (Datei über 300 Zeilen). Neu: nach der Fotoauswahl
   „Prüfen“ tippen (die Aufnahme geht seit 08f2f55 nicht mehr von selbst weiter).
 - XCTAssert… außerhalb einer XCTestCase-Methode meldet den Fehler an den laufenden Test.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv: zweiter Live-Test braucht dieselben Schritte).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert.
@MainActor
struct LiveReceiptSteps {
    let app: XCUIApplication
    var shot: (String) -> Void = { _ in }

    private func checkButton(_ name: String) -> XCUIElement { app.buttons["\(name) abhaken"] }

    func signInIfNeeded() {
        let list = app.buttons["Artikel suchen oder hinzufügen"]
        if list.waitForExistence(timeout: 12) { return }
        let profileDone = app.buttons["Los geht’s"]
        if profileDone.exists {
            profileDone.tap()
            XCTAssertTrue(list.waitForExistence(timeout: 20), "Liste nach Profil anlegen")
            return
        }
        XCTAssertTrue(app.openTestAccountsDialog(), "Anmeldebildschirm")
        let tester = app.buttons["Tester"]
        XCTAssertTrue(tester.waitForExistence(timeout: 5), "Testkonten-Dialog")
        tester.tap()
        XCTAssertTrue(list.waitForExistence(timeout: 30), "Liste nach Anmeldung")
    }

    /// Suche → „Neu anlegen“ → „Zur Liste hinzufügen“ (landet auch im Artikelstamm).
    func createNew(_ name: String) {
        app.buttons["Artikel suchen oder hinzufügen"].tap()
        let field = app.textFields["Artikel suchen"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        let cta = app.buttons["Neu anlegen: „\(name)“"]
        XCTAssertTrue(cta.waitForExistence(timeout: 8), "Neu anlegen")
        cta.tap()
        let save = app.buttons["Zur Liste hinzufügen"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Formular „Neuer Artikel“")
        save.tap()
        XCTAssertTrue(checkButton(name).waitForExistence(timeout: 10), "\(name) auf der Liste")
    }

    /// ☰ → „Kassenzettel scannen“ → „Aus Fotos wählen“ → neuestes Foto → „Kassenzettel prüfen“.
    func scanReceiptFromPhotos() {
        app.buttons["Mehr"].tap()
        let menuItem = app.buttons["Kassenzettel scannen"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "Menü")
        menuItem.tap()
        pickReceiptPhoto()
    }

    /// In der Aufnahme: „Aus Fotos wählen“ → neuestes Foto → bestätigen → „Prüfen“ (öffnet „Kassenzettel prüfen“).
    func pickReceiptPhoto() {
        let pick = app.buttons["Aus Fotos wählen"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "Kassenzettel-Aufnahme")
        pick.tap()
        let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Foto", "Photo"))
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 10), "Fotoauswahl\n\(app.debugDescription)")
        shot("picker")
        // Neuestes Foto = oben links im Raster (Bezeichnung „Foto, 25. September, 23:15“; Beispielfotos sind älter).
        let receipt = photos.allElementsBoundByIndex
            .min { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) } ?? photos.firstMatch
        // Die Fotoauswahl läuft in einem Systemprozess: Elemente gelten als „nicht antippbar“ → auf die Position tippen.
        let frame = receipt.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        let add = app.buttons.matching(NSPredicate(format: "label IN %@", ["Hinzufügen", "Add", "Fertig", "Done"])).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Fotoauswahl bestätigen\n\(app.debugDescription)")
        let addFrame = add.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: addFrame.midX, dy: addFrame.midY)).tap()
        // Seit 08f2f55 geht die Aufnahme nach dem Import nicht mehr von selbst weiter → „Prüfen“ tippen.
        let check = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "prüfen und Preise auslesen")).firstMatch
        let ready = check.waitForExistence(timeout: 10)
        if !ready { shot("capture-missing") }
        XCTAssertTrue(ready, "Knopf „Prüfen“ nach der Fotoauswahl")
        check.tap()
    }

    func waitUntil(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return condition()
    }
}
