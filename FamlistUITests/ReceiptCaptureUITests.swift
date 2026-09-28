/*
 ReceiptCaptureUITests.swift
 FamlistUITests

 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UI-Test Kamerabildschirm „Kassenzettel“ (Fixture, kein Server): Foto aus der Mediathek → Tippen aufs
   Vorschaubild öffnet das Vollbild (löscht nicht) → „Ecken anpassen“ → Abbrechen → ✕ → Aufnahme ist noch da.

 🔰 Notes for Beginners:
 - Im Simulator gibt es keine Kamera und keine Bon-Erkennung; das Foto kommt aus der Mediathek
   (Beispielfotos des Simulators) und bleibt unbeschnitten.
 - Getippt wird bewusst rechts oben ins Vorschaubild: Dort lag früher die Tippfläche des ✕.

 📝 Last Change:
 - Initial creation (Kassenzettel wie ein Dokumentenscanner).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert.
@MainActor
final class ReceiptCaptureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture", "-designFixture"]
        app.launch()
    }

    func test_thumbnailTap_opensFullscreen_andCornerEditor_withoutDeleting() {
        app.buttons["Mehr"].firstMatch.tap()
        let menuItem = app.buttons["Kassenzettel scannen"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "Menü")
        menuItem.tap()
        pickFirstPhoto()

        let thumbnail = app.buttons["Aufnahme 1 vergrößern"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 10), "Vorschaubild nach der Fotoauswahl")
        thumbnail.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.3)).tap()

        let adjust = app.buttons["Ecken anpassen"]
        XCTAssertTrue(adjust.waitForExistence(timeout: 5), "Vollbild mit „Ecken anpassen“")
        adjust.tap()
        XCTAssertTrue(app.staticTexts["Ecken anpassen · Teil 1"].waitForExistence(timeout: 5), "Ecken-Editor")
        XCTAssertTrue(app.buttons["Ganzes Foto verwenden"].exists)
        XCTAssertTrue(app.buttons["Zuschnitt übernehmen"].exists)
        app.buttons["Abbrechen"].tap()

        XCTAssertTrue(adjust.waitForExistence(timeout: 5), "zurück im Vollbild")
        let close = app.buttons["receiptFullscreenClose"]
        close.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.5)).tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 3), "✕ schließt das Vollbild")
        XCTAssertTrue(thumbnail.exists, "Aufnahme wurde nicht gelöscht")
    }

    /// „Aus Fotos wählen“ → erstes Foto → bestätigen (die Fotoauswahl läuft in einem Systemprozess →
    /// auf Positionen tippen, wie in LiveReceiptSteps).
    private func pickFirstPhoto() {
        let pick = app.buttons["Aus Fotos wählen"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "Kassenzettel-Aufnahme")
        pick.tap()
        let photos = app.images.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@", "Foto", "Photo"))
        XCTAssertTrue(photos.firstMatch.waitForExistence(timeout: 10), "Fotoauswahl\n\(app.debugDescription)")
        let frame = photos.firstMatch.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        let add = app.buttons.matching(NSPredicate(format: "label IN %@", ["Hinzufügen", "Add", "Fertig", "Done"])).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Fotoauswahl bestätigen")
        let addFrame = add.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: addFrame.midX, dy: addFrame.midY)).tap()
    }
}
