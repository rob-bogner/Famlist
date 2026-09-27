/*
 EditPriceDraftUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Artikel bearbeiten“: Ein eingetippter Preis geht nicht verloren, wenn man zwischendurch den
   Preisverlauf öffnet und zurückkehrt, und er wird danach mit „Speichern“ gespeichert.

 🔰 Notes for Beginners:
 - Läuft mit der In-Memory-Fixture (`-uiTestFixture`), ohne Anmeldung und ohne Server.
 - „Bearbeiten“ liegt als Glas-Knopf hinter der Karte (Wischen nach links); der Knopf selbst ist vor
   VoiceOver verborgen, deshalb wird über seiner Beschriftung getippt.

 📝 Last Change:
 - Initial creation (Gerätetest 25.09.2026: Preise wurden beim Bearbeiten nicht gespeichert).
 ------------------------------------------------------------------------
 */

import XCTest

@MainActor
final class EditPriceDraftUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture"]
        app.launch()
    }

    func test_typedPrice_survivesPriceHistory_andIsSaved() {
        openEdit("Butter")
        let field = app.textFields["Preis"]
        field.tap()
        field.typeText("3,33")

        // Zahlentastatur schließen wie ein Nutzer: Inhalt nach unten bis in die Tastatur ziehen (scrollDismissesKeyboard).
        // Das Preisfeld wird beim Fokussieren über „Speichern“ geholt – eine feste Strecke ab „Kategorie“ endet
        // seitdem weit über der Tastatur, deshalb bis 40 pt unter deren Oberkante ziehen.
        let label = app.staticTexts["Kategorie"]
        let start = label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let distance = app.keyboards.firstMatch.frame.minY + 40 - label.frame.midY
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3), "Tastatur geschlossen")
        let history = app.buttons["Preisverlauf anzeigen"]
        XCTAssertTrue(history.waitForExistence(timeout: 5), "Link „Preisverlauf“")
        history.tap()
        let close = app.buttons["Schließen"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Preisverlauf offen")
        close.tap()

        XCTAssertTrue(field.waitForExistence(timeout: 5), "zurück in „Artikel bearbeiten“")
        XCTAssertEqual(field.value as? String, "3,33", "eingetippter Preis ist noch da")
        app.buttons["Speichern"].tap()
        let price = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Preis 3,33")).firstMatch
        XCTAssertTrue(price.waitForExistence(timeout: 5), "Karte zeigt 3,33 €")
    }

    /// Fokussiertes Preisfeld liegt sichtbar über „Speichern“, „Speichern“ über der Tastatur (KeyboardRevealScrollView).
    /// Vorher lag das Feld hinter Ziffernblock und Knopf.
    func test_focusedPriceField_isVisibleAboveSaveButton() {
        openEdit("Butter")
        let field = app.textFields["Preis"]
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 3), "Tastatur offen")
        let save = app.buttons["Speichern"]
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            field.frame.maxY <= save.frame.minY && save.frame.maxY <= keyboard.frame.minY
        }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [visible], timeout: 3), .completed,
                       "Preisfeld \(field.frame) über „Speichern“ \(save.frame) über Tastatur \(keyboard.frame)")
    }

    private func openEdit(_ name: String) {
        let check = app.buttons["\(name) abhaken"]
        XCTAssertTrue(check.waitForExistence(timeout: 15))
        let start = check.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -200, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -150, dy: 0)),
                    withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.05)
        XCTAssertTrue(app.staticTexts["Bearbeiten"].firstMatch.waitForExistence(timeout: 3), "Knopf „Bearbeiten“")
        let rowMid = check.frame.midY
        let caption = app.staticTexts.matching(identifier: "Bearbeiten").allElementsBoundByIndex
            .min { abs($0.frame.midY - rowMid) < abs($1.frame.midY - rowMid) }!
        caption.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: -32)).tap()
        XCTAssertTrue(app.textFields["Preis"].waitForExistence(timeout: 5), "Formular „Artikel bearbeiten“")
    }
}
