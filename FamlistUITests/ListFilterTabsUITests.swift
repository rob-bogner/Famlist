/*
 ListFilterTabsUITests.swift
 FamlistUITests
 Created on: 11.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tabs „Alle · Offen · Erledigt“ der Einkaufsliste: Nach dem Wechsel sind die passenden Artikel sichtbar,
   auch wenn die Liste vorher weit nach unten gescrollt war.

 🔰 Notes for Beginners:
 - Gerätefehler 11.10.2026: In „Alle“ zu den abgehakten Artikeln gescrollt, dann „Offen“ → leere Liste,
   bis man zu „Alle“ und zurück wechselte.
 - Fixture: 16 offene Artikel. Der Test hakt alle Kategorien außer „Obst & Gemüse“ ab (3 bleiben offen).

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class ListFilterTabsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture"]
        app.launch()
        XCTAssertTrue(app.buttons["Äpfel abhaken"].waitForExistence(timeout: 15))
    }

    /// Hakt jede Kategorie außer „Obst & Gemüse“ über „Alle … abhaken“ im Abschnittskopf ab.
    private func checkAllButFruit() {
        // Ohne das Dock („Alle Artikel abhaken“): Das würde alles abhaken und „Einkauf erledigt“ öffnen.
        let headers = NSPredicate(format: "label BEGINSWITH 'Alle ' AND label ENDSWITH ' abhaken' AND NOT (label IN %@)",
                                  ["Alle Obst & Gemüse abhaken", "Alle Artikel abhaken"])
        for _ in 0..<10 {
            let next = app.buttons.matching(headers).firstMatch
            guard next.waitForExistence(timeout: 2) else { break }
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["Abgehakte Artikel, 13"].waitForExistence(timeout: 5), "13 abgehakt, 3 offen")
    }

    /// Wie auf dem Gerät: nur EIN offener Artikel, alle anderen abgehakt. Nach jedem Tipp die Zahl abwarten –
    /// die Zeilen rücken animiert nach, ein zu früher zweiter Tipp trifft sonst die falsche Zeile.
    private func leaveOnlyApplesOpen() {
        app.buttons["Bananen abhaken"].tap()
        XCTAssertTrue(app.staticTexts["Abgehakte Artikel, 14"].waitForExistence(timeout: 5), "14 abgehakt")
        app.buttons["Tomaten abhaken"].tap()
        XCTAssertTrue(app.staticTexts["Abgehakte Artikel, 15"].waitForExistence(timeout: 5), "15 abgehakt, 1 offen")
    }

    func test_switchingToOpen_afterScrollingToCheckedItems_showsOpenItems() {
        checkAllButFruit()
        leaveOnlyApplesOpen()
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        XCTAssertFalse(app.buttons["Äpfel abhaken"].isHittable, "weit unten bei den abgehakten Artikeln")

        app.buttons["Offen"].firstMatch.tap()

        let apples = app.buttons["Äpfel abhaken"]
        XCTAssertTrue(apples.waitForExistence(timeout: 5), "offene Artikel sind da")
        XCTAssertTrue(apples.isHittable, "offene Artikel sind sichtbar")
    }

    /// Oberkante eines Abschnittskopfs: Bei großem Listenkopf liegt er deutlich tiefer als bei kompaktem
    /// (kompakt ≈ 225 pt, groß ≈ 400 pt auf dem iPhone 17 Pro).
    private func isBelowExpandedHeader(_ element: XCUIElement) -> Bool {
        element.waitForExistence(timeout: 5) && element.frame.minY > 320
    }

    /// Jeder Tab-Wechsel beginnt ganz oben, mit der großen Fortschrittskarte.
    func test_switchingTabs_scrollsToTop_andShowsLargeHeader() {
        checkAllButFruit()
        leaveOnlyApplesOpen()

        // „Alle“ weit unten → „Erledigt“
        app.swipeUp()
        app.swipeUp()
        app.buttons["Erledigt"].firstMatch.tap()
        XCTAssertTrue(isBelowExpandedHeader(app.staticTexts["Abgehakte Artikel, 15"]), "„Erledigt“ beginnt oben")

        // „Erledigt“ weit unten → „Alle“
        app.swipeUp()
        app.swipeUp()
        app.buttons["Alle"].firstMatch.tap()
        XCTAssertTrue(isBelowExpandedHeader(app.staticTexts["Obst & Gemüse, 1 Artikel"]), "„Alle“ beginnt oben")
        XCTAssertTrue(app.buttons["Äpfel abhaken"].isHittable, "erster Artikel ist sichtbar")
    }

    /// Gerätefall 12.10.2026: „Offen“ enthält mehrere Artikel (länger als der Bildschirm). Nach dem Wechsel aus
    /// „Alle“ (weit unten bei den abgehakten Artikeln) muss „Offen“ trotzdem ganz oben beginnen.
    func test_switchingToOpen_withManyOpenItems_scrollsToTop() {
        for (category, checked) in [("Milchprodukte", 3), ("Backwaren", 5), ("Getränke", 7)] {
            let header = app.buttons["Alle \(category) abhaken"]
            XCTAssertTrue(header.waitForExistence(timeout: 5), category)
            header.tap()
            // Der Abschnitt „Abgehakte Artikel“ liegt hier unter dem Bildschirm; die Plakette am Tab zeigt die Zahl.
            XCTAssertTrue(app.buttons["Erledigt, \(checked)"].waitForExistence(timeout: 5), "\(checked) abgehakt")
        }
        app.swipeUp()
        app.swipeUp()
        app.swipeUp()
        XCTAssertFalse(app.buttons["Äpfel abhaken"].isHittable, "weit unten bei den abgehakten Artikeln")

        app.buttons["Offen"].firstMatch.tap()

        XCTAssertTrue(isBelowExpandedHeader(app.staticTexts["Obst & Gemüse, 3 Artikel"]), "„Offen“ beginnt oben")
        XCTAssertTrue(app.buttons["Äpfel abhaken"].isHittable, "erster offener Artikel ist sichtbar")
    }

    /// XCUITest wartet vor und nach jedem Ereignis, bis die App ruht – also bis die Liste steht. Ein Tipp im
    /// Nachlauf ist so nicht möglich. Diese Funktion schaltet das Warten ab und liefert die Rücknahme.
    /// Sie ersetzt zwei private Methoden von XCTest; fehlen sie in einer neuen Xcode-Version, schlägt der Test fehl.
    private func skipWaitingForIdle() -> () -> Void {
        guard let process = NSClassFromString("XCUIApplicationProcess") else {
            XCTFail("XCUIApplicationProcess fehlt")
            return {}
        }
        var originals: [(Method, IMP)] = []
        for name in ["shouldSkipPreEventQuiescence", "shouldSkipPostEventQuiescence"] {
            guard let method = class_getInstanceMethod(process, NSSelectorFromString(name)) else {
                XCTFail("\(name) fehlt")
                continue
            }
            let skip: @convention(block) (AnyObject) -> Bool = { _ in true }
            originals.append((method, method_setImplementation(method, imp_implementationWithBlock(skip))))
        }
        return { originals.forEach { method_setImplementation($0.0, $0.1) } }
    }

    /// Bildschirmpunkt eines Elements als feste Koordinate (zwischen Wisch und Tipp darf keine Elementsuche liegen).
    private func fixedCenter(of element: XCUIElement) -> XCUICoordinate {
        let spot = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).screenPoint
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: spot.x, dy: spot.y))
    }

    /// Gerätefall 12.10.2026: Die Liste läuft nach einem kräftigen Wisch noch nach. Der ERSTE Tipp auf einen Tab
    /// muss wechseln (vorher hielt er nur das Scrollen an) und die Liste muss danach oben stehen.
    func test_tappingTab_whileListCoasts_switchesWithFirstTap() {
        checkAllButFruit()
        // Kopf einklappen, ohne Nachlauf: kurzer, langsamer Zug mit Halten am Ende.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
        let done = app.buttons["Erledigt"].firstMatch
        XCTAssertLessThan(done.frame.minY, 260, "Kopf ist eingeklappt")
        let doneTab = fixedCenter(of: done)

        let restoreWaiting = skipWaitingForIdle()
        app.swipeUp(velocity: .fast)                    // kräftiger Wisch: Die Liste läuft danach noch nach
        doneTab.tap()
        restoreWaiting()

        XCTAssertTrue(done.wait(for: \.isSelected, toEqual: true, timeout: 3), "erster Tipp wählt „Erledigt“")
        XCTAssertTrue(isBelowExpandedHeader(app.staticTexts["Abgehakte Artikel, 13"]), "„Erledigt“ beginnt oben")
    }
}
