/*
 DuplicateAddUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression: Einen Artikel hinzufügen, der schon auf der Liste steht, erhöht die angezeigte Menge sofort.

 🔰 Notes for Beginners:
 - Fixture: „Brot“ steht mit Menge 1 (ohne Einheit) auf der Liste; der Beispiel-Artikelstamm kennt „Brot“
   mit Einheit „Stück“. Nach dem Hinzufügen muss die Karte „2 Stück“ zeigen.
 - Gerätefehler 25.09.2026: Daten waren korrekt (Menge erhöht), die Karte zeigte weiter den alten Wert.

 📝 Last Change:
 - 11.10.2026: Weg über das Plus im Dock (vorher veraltete Beschriftungen der Suchleiste); Eingabe und
   Barcode-Scanner müssen nach dem Hinzufügen geschlossen sein.
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class DuplicateAddUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture"]
        app.launch()
    }

    /// Plus im Dock → Eingabe über der Tastatur → Treffer antippen. Die Eingabe muss danach geschlossen sein.
    /// - Parameter unit: Treffer mit dieser Einheit wählen. Der Beispiel-Artikelstamm kennt „Brot“ zweimal:
    ///   mit „Stück“ (Beispieldaten) und ohne Einheit (von der Fixture beim Füllen der Liste gespeichert).
    private func addFromSearch(_ name: String, unit: String? = nil) {
        app.buttons["Artikel hinzufügen"].tap()
        let field = app.textFields["Artikel hinzufügen"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        // Trefferzeile heißt „Brot“ bzw. „Brot, Stück, auf der Liste“ (nicht „Brötchen“).
        let prefix = [name, unit].compactMap { $0 }.joined(separator: ", ")
        let row = NSPredicate(format: "label == %@ OR label BEGINSWITH %@", prefix, "\(prefix),")
        let add = app.buttons.matching(row).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Eingabe schließt nach dem Hinzufügen")
    }

    /// Wie auf dem Gerät: der Artikel hat ein großes Foto.
    func test_addExistingItemWithLargeImage_showsIncreasedQuantity() {
        app.terminate()
        app.launchArguments = ["-uiTestFixture", "-fixtureLargeImage"]
        app.launch()
        test_addExistingItem_showsIncreasedQuantityImmediately()
    }

    func test_addExistingItem_showsIncreasedQuantityImmediately() {
        XCTAssertTrue(app.buttons["Brot abhaken"].waitForExistence(timeout: 15))
        addFromSearch("Brot", unit: "Stück")
        XCTAssertTrue(app.staticTexts["2 Stück"].waitForExistence(timeout: 5), "Karte zeigt die erhöhte Menge")

        addFromSearch("Brot", unit: "Stück")
        XCTAssertTrue(app.staticTexts["3 Stück"].waitForExistence(timeout: 5), "auch beim zweiten Mal")
    }

    /// Barcode-Scanner: „Zur Liste hinzufügen“ legt den Artikel an und schließt den Scanner.
    /// `-designSheet barcode` zeigt die Karte „Artikel erkannt“ ohne Kamera (Simulator).
    func test_addScannedItem_closesScanner() {
        app.terminate()
        app.launchArguments = ["-uiTestFixture", "-designSheet", "barcode"]
        app.launch()
        let add = app.buttons["Zur Liste hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        XCTAssertTrue(add.waitForNonExistence(timeout: 5), "Scanner schließt nach dem Hinzufügen")
        // Der neue Artikel liegt unterhalb des sichtbaren Bereichs (LazyVStack); der Zähler im Kopf zeigt ihn (16 → 17).
        XCTAssertTrue(app.staticTexts["0 von 17 Artikeln"].waitForExistence(timeout: 5), "Artikel steht auf der Liste")
    }

    /// Suche: Ein Tipp auf den Treffer fügt hinzu und schließt die Eingabe (Prüfung in `addFromSearch`).
    func test_addFromSearch_closesInput() {
        XCTAssertTrue(app.buttons["Brot abhaken"].waitForExistence(timeout: 15))
        addFromSearch("Brot")
        XCTAssertTrue(app.buttons["Artikel hinzufügen"].waitForExistence(timeout: 5), "Dock ist wieder sichtbar")
    }
}
