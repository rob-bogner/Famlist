/*
 ManageSwipeUITests.swift
 FamlistUITests
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Wischen zum Löschen und Tippen in „Artikel verwalten“ und „Kategorien verwalten“.

 🔰 Notes for Beginners:
 - Start direkt im Sheet über `-designSheet manageItems` bzw. `manageCategories` (Fixture im Speicher).
 - Artikel: Nur der Pfeil rechts öffnet „Artikel bearbeiten“; Tippen auf die Kartenmitte tut nichts.
 - Kategorien: Tippen auf den Namen bearbeitet; „Sonstiges“ lässt sich nicht wischen.

 📝 Last Change:
 - Initial creation (Wischen war unzuverlässig, weil die Karte ein Button war).
 ------------------------------------------------------------------------
 */

import XCTest

final class ManageSwipeUITests: XCTestCase {
    private var app: XCUIApplication!

    private func launch(sheet: String) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture", "-designSheet", sheet]
        app.launch()
    }

    private func element(beginningWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Waagerechtes Wischen ab der Kartenmitte (dort lag vorher der Button).
    private func swipeLeft(_ element: XCUIElement, dx: CGFloat) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)),
                    withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.05)
        Thread.sleep(forTimeInterval: 1.5)          // Einrast-Animation abwarten
    }

    /// Der Glas-Knopf ist vor VoiceOver verborgen (Aktion „Löschen“ hängt an der Zeile) → Tippen per Koordinate:
    /// Knopfmitte liegt 39,5 pt über der Mitte der Beschriftung „Löschen“ (52/2 + 6 + 15/2 … Textmitte).
    private func tapDeleteButton() {
        let label = app.staticTexts.matching(NSPredicate(format: "label == %@", "Löschen"))
            .allElementsBoundByIndex.first { $0.isHittable && $0.frame.minX > 250 }
        XCTAssertNotNil(label, "Beschriftung „Löschen“ sichtbar")
        label?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 0, dy: -39.5)).tap()
    }

    // MARK: - Artikel verwalten

    func test_items_swipeFromCenter_revealsDelete_thenDeletes() {
        launch(sheet: "manageItems")
        let butter = element(beginningWith: "Butter,")
        XCTAssertTrue(butter.waitForExistence(timeout: 15))
        let rest = butter.frame.minX
        swipeLeft(butter, dx: -120)
        XCTAssertEqual(butter.frame.minX, rest - 88, accuracy: 4, "Löschen-Knopf eingerastet")
        XCTAssertFalse(app.staticTexts["Artikel bearbeiten"].exists, "Wischen darf nicht bearbeiten")

        tapDeleteButton()
        XCTAssertTrue(butter.waitForNonExistence(timeout: 5))
    }

    func test_items_tapCenter_doesNothing_tapChevron_opensEdit() {
        launch(sheet: "manageItems")
        let butter = element(beginningWith: "Butter,")
        XCTAssertTrue(butter.waitForExistence(timeout: 15))

        butter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(app.staticTexts["Artikel bearbeiten"].waitForExistence(timeout: 1.5))

        // Pfeil: 13 pt Einzug + 9 pt halbe Pfeilbreite vom rechten Kartenrand.
        butter.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(CGVector(dx: -22, dy: 0)).tap()
        XCTAssertTrue(app.staticTexts["Artikel bearbeiten"].waitForExistence(timeout: 5))
    }

    // MARK: - Kategorien verwalten

    func test_categories_swipe_revealsDelete_thenDeletes() {
        launch(sheet: "manageCategories")
        let first = element(beginningWith: "1. ")
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        let name = first.label
        let rest = first.frame.minX
        swipeLeft(first, dx: -120)
        XCTAssertEqual(first.frame.minX, rest - 88, accuracy: 4, "Löschen-Knopf eingerastet")

        tapDeleteButton()
        XCTAssertTrue(app.buttons[name].waitForNonExistence(timeout: 5), "\(name) gelöscht")
    }

    func test_categories_fallback_cannotBeSwiped() {
        launch(sheet: "manageCategories")
        let fallback = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Sonstiges bearbeiten")).firstMatch
        XCTAssertTrue(fallback.waitForExistence(timeout: 15))
        if !fallback.isHittable { app.swipeUp(); Thread.sleep(forTimeInterval: 1.5) }
        let rest = fallback.frame.minX
        swipeLeft(fallback, dx: -120)
        XCTAssertEqual(fallback.frame.minX, rest, accuracy: 1)
    }

    func test_categories_tapName_opensEdit() {
        launch(sheet: "manageCategories")
        let first = element(beginningWith: "1. ")
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        Thread.sleep(forTimeInterval: 1)             // Sheet-Animation abwarten
        first.tap()
        XCTAssertTrue(app.staticTexts["Kategorie bearbeiten"].waitForExistence(timeout: 5))
    }
}
