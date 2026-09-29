/*
 ReceiptArchiveUITests.swift
 FamlistUITests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UI-Test Kassenzettel-Archiv (Fixture, kein Server): Einstellungen → „Gespeicherte Kassenzettel“ →
   Filter nach Laden → Detail → Löschen mit Rückfrage → zurück im Archiv, ein Bon weniger.

 🔰 Notes for Beginners:
 - `-designFixture` füllt das Archiv mit den zwölf Beispiel-Bons aus ReceiptArchive.dc.html.
 - Die Bons von „Rob“ gehören dem Fixture-Konto; nur sie zeigen „Löschen“.

 📝 Last Change:
 - Detail mit Einkaufsdaten: Unterzeile ohne Datum, Kacheln, Artikel; Fotos im Reiter „Bon-Foto“.
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class ReceiptArchiveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture", "-designFixture", "-designSheet", "settings"]
        app.launch()
    }

    func test_settings_archive_filter_detail_delete() {
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["12 Bons · 38 MB"].exists)
        open.tap()

        XCTAssertTrue(app.staticTexts["12 Bons · 38 MB · für alle in der Liste sichtbar"].waitForExistence(timeout: 5))
        let edeka = app.buttons["Edeka, 24.09.2026 · Liste Edeka, 5 Positionen, 11,51\u{00A0}€"]
        XCTAssertTrue(edeka.exists)

        // Filter „Rewe“: nur Rewe-Bons, der Edeka-Bon verschwindet; zurück auf „Alle“.
        app.buttons["Rewe"].tap()
        XCTAssertTrue(edeka.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Rewe, 19.09.2026 · Wocheneinkauf, 23 Positionen, 64,87\u{00A0}€"].exists)
        app.buttons["Alle"].tap()
        XCTAssertTrue(edeka.waitForExistence(timeout: 3))

        edeka.tap()
        // Detail mit Einkaufsdaten (Board ReceiptDetailMeta): Datum steht in den Kacheln, Artikel zuerst.
        XCTAssertTrue(app.staticTexts["Liste Edeka · gescannt von Rob"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["Wert, 11,51\u{00A0}€, Ø 1,92\u{00A0}€ je Stück"].exists)
        XCTAssertTrue(app.buttons["Kerrygold Butter, 1 × 250 g · je 2,49\u{00A0}€, Milchprodukte, 2,49\u{00A0}€"].exists)
        app.buttons["Bon-Foto"].tap()
        XCTAssertTrue(app.buttons["Vollbild"].waitForExistence(timeout: 3))

        app.buttons["Löschen"].tap()
        let confirm = app.buttons["Kassenzettel löschen"]                   // Aktionskarte: Schieben zum Löschen
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "Rückfrage erscheint")
        slide(confirm)

        let remaining = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '11 Bons · '")).firstMatch
        XCTAssertTrue(remaining.waitForExistence(timeout: 5), "Archiv zählt einen Bon weniger")
        XCTAssertTrue(edeka.waitForNonExistence(timeout: 3))
    }

    /// Vollbild eines gespeicherten Bons: ✕ schließt auch beim Tippen auf die Glasfläche neben den Strichen.
    /// (Vorher reagierten nur die Striche; ein Tipp in die Mitte traf sie zufällig, deshalb bewusst daneben.)
    func test_detailFullscreen_closeButtonClosesOnGlassArea() {
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let edeka = app.buttons["Edeka, 24.09.2026 · Liste Edeka, 5 Positionen, 11,51\u{00A0}€"]
        XCTAssertTrue(edeka.waitForExistence(timeout: 5))
        edeka.tap()
        let photoTab = app.buttons["Bon-Foto"]
        XCTAssertTrue(photoTab.waitForExistence(timeout: 5))
        photoTab.tap()
        let fullscreen = app.buttons["Vollbild"]
        XCTAssertTrue(fullscreen.waitForExistence(timeout: 5))
        fullscreen.tap()

        let close = app.buttons["receiptFullscreenClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Vollbild offen")
        close.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.5)).tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 3), "✕ schließt das Vollbild")
        XCTAssertTrue(app.staticTexts["Liste Edeka · gescannt von Rob"].exists, "zurück im Detail")
    }

    func test_foreignReceipt_hasNoDelete() {
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let rewe = app.buttons["Rewe, 19.09.2026 · Wocheneinkauf, 23 Positionen, 64,87\u{00A0}€"]   // gescannt von Anna
        XCTAssertTrue(rewe.waitForExistence(timeout: 5))
        rewe.tap()
        XCTAssertTrue(app.staticTexts["Wocheneinkauf · gescannt von Anna"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Teilen"].exists)
        XCTAssertFalse(app.buttons["Löschen"].exists)
    }

    /// Tipp auf einen zugeordneten Artikel öffnet seinen Preisverlauf; ✕ führt zurück ins Detail.
    func test_detailArticle_opensPriceHistory_andReturns() {
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let edeka = app.buttons["Edeka, 24.09.2026 · Liste Edeka, 5 Positionen, 11,51\u{00A0}€"]
        XCTAssertTrue(edeka.waitForExistence(timeout: 5))
        edeka.tap()
        let butter = app.buttons["Kerrygold Butter, 1 × 250 g · je 2,49\u{00A0}€, Milchprodukte, 2,49\u{00A0}€"]
        XCTAssertTrue(butter.waitForExistence(timeout: 5))
        butter.tap()
        XCTAssertTrue(app.staticTexts["Preisverlauf"].waitForExistence(timeout: 5), "Preisverlauf offen")
        app.buttons["Schließen"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Liste Edeka · gescannt von Rob"].waitForExistence(timeout: 5), "zurück im Detail")
    }

    /// Einstieg Auswertung: Archiv → Karte → Auswertung → Verbrauch → Zeile → Preisverlauf → zurück.
    func test_archiveCard_opensInsights_usageRow_priceHistory_andBack() {
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        open.tap()
        let card = app.buttons["Auswertung September öffnen"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Karte im Archiv")
        card.tap()
        XCTAssertTrue(app.staticTexts["Ausgegeben im September"].waitForExistence(timeout: 5), "Reiter Ausgaben")
        app.buttons["Verbrauch"].tap()
        let milk = app.buttons["Milch, 14 l im September, 16,66\u{00A0}€"]
        XCTAssertTrue(milk.waitForExistence(timeout: 5), "Reiter Verbrauch")
        milk.tap()
        XCTAssertTrue(app.staticTexts["Preisverlauf"].waitForExistence(timeout: 5), "Preisverlauf offen")
        app.buttons["Schließen"].firstMatch.tap()
        XCTAssertTrue(milk.waitForExistence(timeout: 5), "zurück in „Verbrauch“ desselben Monats")
        app.buttons["Schließen"].firstMatch.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5), "✕ führt ins Archiv")
    }

    /// „Schieben zum Löschen“: vom linken Rand der Spur bis ganz nach rechts ziehen.
    private func slide(_ element: XCUIElement) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
