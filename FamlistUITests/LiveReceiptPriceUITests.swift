/*
 LiveReceiptPriceUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Live-Test gegen Supabase (Simulator-Testkonto „Tester“): Artikelpreise werden gespeichert –
   beim Bearbeiten und nach dem Kassenzettel („Artikelpreise aktualisieren?“ → „Preise übernehmen“).
   Geprüft wird die Karte, der Stand nach einem Neustart, das Formular „Artikel bearbeiten“ und der Server.

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_LIVE=1 xcodebuild test …` (echtes Netz, echte Daten des Testkontos).
 - Der Kassenzettel kommt als Bild aus der Fotomediathek des Simulators (die Simulator-Kamera liefert
   kein Bild). Vorher einmal: `swift scripts/make_test_receipt.swift /tmp/bon.png` und
   `xcrun simctl addmedia <Simulator-ID> /tmp/bon.png` – Zeilen „LIVETEST QUITTENGELEE 2,49 A“,
   „LIVETEST BIRNENSAFT 2,58 A“, „2 Stk x 1,29“; es muss das neueste Foto sein.
 - Texterkennung (Vision), Parser, Zuordnung und Speichern laufen echt.

 📝 Last Change:
 - Initial creation (Gerätetest 25.09.2026: Preise wurden nicht im Artikel gespeichert).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert.
@MainActor
final class LiveReceiptPriceUITests: XCTestCase {
    private var app: XCUIApplication!
    private let shots = ProcessInfo.processInfo.environment["FAMLIST_SHOTS"]
    private let jelly = "Livetest Quittengelee"
    private let juice = "Livetest Birnensaft"

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FAMLIST_LIVE"] == "1", "nur mit TEST_RUNNER_FAMLIST_LIVE=1")
        continueAfterFailure = false
        await LiveTestCleanup.removeLiveTestData()            // Reste früherer Läufe stören die Zuordnung
        app = XCUIApplication()
        app.launch()
        addTeardownBlock { await LiveTestCleanup.removeLiveTestData() }
    }

    func test_live_pricesSaved_byEdit_andByReceipt() {
        signInIfNeeded()
        createNew(jelly)
        createNew(juice)
        XCTAssertTrue(checkButton(jelly).waitForExistence(timeout: 10), "Quittengelee steht auf der Liste")
        XCTAssertTrue(checkButton(juice).waitForExistence(timeout: 10), "Birnensaft steht auf der Liste")

        // 1) Preis über „Artikel bearbeiten“
        setPriceViaEdit(jelly, to: "1,11")
        XCTAssertTrue(priceLabel("1,11").waitForExistence(timeout: 5), "Karte zeigt 1,11 € sofort")
        shot("1-edit")
        relaunchAfterSync()
        XCTAssertTrue(priceLabel("1,11").waitForExistence(timeout: 20), "1,11 € nach Neustart")
        assertServerPrice(jelly, 1.11)

        // 2) Kassenzettel → „Preise übernehmen“
        scanReceiptFromPhotos()
        let save = app.buttons["Preise speichern"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Kassenzettel prüfen")
        XCTAssertTrue(waitUntil(20) { save.isEnabled }, "Positionen erkannt und zugeordnet")
        shot("2-review")
        save.tap()
        let alert = app.alerts["Artikelpreise aktualisieren?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Rückfrage erscheint")
        shot("3-alert")
        alert.buttons["Preise übernehmen"].tap()
        let keep = app.buttons["Liste behalten"]
        XCTAssertTrue(keep.waitForExistence(timeout: 10), "Einkauf erledigt")
        keep.tap()

        XCTAssertTrue(priceLabel("2,49").waitForExistence(timeout: 5), "Quittengelee zeigt 2,49 €")
        XCTAssertTrue(priceLabel("1,29").waitForExistence(timeout: 5), "Birnensaft zeigt Stückpreis 1,29 €")
        shot("4-list")
        relaunchAfterSync()
        XCTAssertTrue(priceLabel("2,49").waitForExistence(timeout: 20), "2,49 € nach Neustart")
        XCTAssertTrue(priceLabel("1,29").waitForExistence(timeout: 5), "1,29 € nach Neustart")
        XCTAssertEqual(editFormPrice(jelly), "2,49", "Formular „Artikel bearbeiten“ zeigt den neuen Preis")
        shot("5-edit-form")

        assertServerPrice(jelly, 2.49)
        assertServerPrice(juice, 1.29)
        assertCatalogPrice(jelly, 2.49)
        assertCatalogPrice(juice, 1.29)

        // 3) Preis über „Artikel verwalten“ (Artikelstamm) → gleichnamiger Listenartikel übernimmt ihn
        setCatalogPrice(jelly, to: "3,05")
        XCTAssertTrue(priceLabel("3,05").waitForExistence(timeout: 5), "Listenkarte zeigt 3,05 € aus dem Artikelstamm")
        assertCatalogPrice(jelly, 3.05)
        relaunchAfterSync()
        XCTAssertTrue(priceLabel("3,05").waitForExistence(timeout: 20), "3,05 € nach Neustart")
        assertServerPrice(jelly, 3.05)
    }

    /// Wie beim Einkauf: alles abhaken → „Einkauf erledigt“ → Kassenzettel → „Preise übernehmen“ →
    /// „Abgehakte löschen & fertig“. Danach sind die Artikel weg; neu hinzugefügt tragen sie den Bon-Preis
    /// (aus dem Artikelstamm).
    func test_live_receiptAfterShopping_pricesSurviveFinish() {
        signInIfNeeded()
        createNew(jelly)
        createNew(juice)
        setPriceViaEdit(jelly, to: "1,11")
        setPriceViaEdit(juice, to: "0,5")
        XCTAssertTrue(priceLabel("0,50").waitForExistence(timeout: 5), "Birnensaft 0,50 €")

        checkAllOnList()
        let scan = app.buttons["Kassenzettel scannen"]
        XCTAssertTrue(scan.waitForExistence(timeout: 8), "„Einkauf erledigt“ bietet den Scan an")
        scan.tap()
        pickReceiptPhoto()
        let save = app.buttons["Preise speichern"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Kassenzettel prüfen")
        XCTAssertTrue(waitUntil(20) { save.isEnabled }, "Positionen erkannt und zugeordnet")
        save.tap()
        let alert = app.alerts["Artikelpreise aktualisieren?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Rückfrage erscheint")
        alert.buttons["Preise übernehmen"].tap()
        let finish = app.buttons["Abgehakte löschen & fertig"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10), "Einkauf erledigt")
        shot("6-done")
        finish.tap()
        XCTAssertTrue(checkButton(jelly).waitForNonExistence(timeout: 10), "Abgehakte gelöscht")
        Thread.sleep(forTimeInterval: 7)                      // Rückgängig-Frist + Senden abwarten

        assertCatalogPrice(jelly, 2.49)
        assertCatalogPrice(juice, 1.29)
        addFromSearch(jelly)
        addFromSearch(juice)
        XCTAssertTrue(priceLabel("2,49").waitForExistence(timeout: 5), "neu hinzugefügt mit Bon-Preis 2,49 €")
        XCTAssertTrue(priceLabel("1,29").waitForExistence(timeout: 5), "neu hinzugefügt mit Bon-Preis 1,29 €")
        shot("7-readded")
        relaunchAfterSync()
        XCTAssertTrue(priceLabel("2,49").waitForExistence(timeout: 20), "2,49 € nach Neustart")
        XCTAssertTrue(priceLabel("1,29").waitForExistence(timeout: 5), "1,29 € nach Neustart")
        assertServerPrice(jelly, 2.49)
        assertServerPrice(juice, 1.29)
    }

    // MARK: - Schritte

    /// Alle offenen Artikel der Liste abhaken (erst dann bietet die App „Einkauf erledigt“ an).
    private func checkAllOnList() {
        // Kopfzeilen-Knopf „Alle Sonstiges abhaken“ ausnehmen: nur Artikelkarten einzeln abhaken.
        let open = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@ AND NOT (label BEGINSWITH %@)",
                                                    " abhaken", "Alle "))
        var guardCount = 0
        while open.firstMatch.exists, guardCount < 30 {
            open.firstMatch.tap()
            Thread.sleep(forTimeInterval: 0.4)
            guardCount += 1
        }
    }

    private func addFromSearch(_ name: String) {
        app.buttons["Artikel suchen oder hinzufügen"].tap()
        let field = app.textFields["Artikel suchen"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(name)
        let add = app.buttons["\(name) hinzufügen"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10), "Suchtreffer \(name)")
        add.tap()
        XCTAssertTrue(checkButton(name).waitForExistence(timeout: 10), "\(name) wieder auf der Liste")
    }

    private func signInIfNeeded() {
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
    private func createNew(_ name: String) {
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

    /// Wischen nach links → „Bearbeiten“ → Preis eintippen → „Speichern“.
    private func setPriceViaEdit(_ name: String, to price: String) {
        openEdit(name)
        let field = app.textFields["Preis"]
        field.tap()
        if let old = field.value as? String, !old.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        field.typeText(price)
        app.buttons["Speichern"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Formular geschlossen")
    }

    private func openEdit(_ name: String) {
        let check = checkButton(name)
        XCTAssertTrue(check.waitForExistence(timeout: 10))
        let start = check.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -200, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -150, dy: 0)),
                    withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.05)
        // Der Glas-Knopf ist vor VoiceOver verborgen (Aktion „Bearbeiten“ liegt an der Zeile); sichtbar ist
        // seine Beschriftung. Knopf 52 hoch, 6 über der Beschriftung → Mitte 32 pt über ihrer Oberkante.
        // Jede Zeile hat (verdeckt) eigene Beschriftungen → die in derselben Zeile wie der Artikel nehmen.
        XCTAssertTrue(app.staticTexts["Bearbeiten"].firstMatch.waitForExistence(timeout: 3), "Knopf „Bearbeiten“")
        let rowMid = check.frame.midY
        let caption = app.staticTexts.matching(identifier: "Bearbeiten").allElementsBoundByIndex
            .min { abs($0.frame.midY - rowMid) < abs($1.frame.midY - rowMid) }!
        XCTAssertLessThan(abs(caption.frame.midY - rowMid), 47, "Beschriftung liegt in der Zeile von \(name)")
        caption.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: -32)).tap()
        let opened = app.textFields["Preis"].waitForExistence(timeout: 5)
        if !opened { shot("edit-missing") }
        XCTAssertTrue(opened, "Formular „Artikel bearbeiten“\n\(app.debugDescription)")
    }

    /// ☰ → „Artikel verwalten“ → Pfeil des Eintrags → Preis → „Speichern“ → Sheet schließen.
    private func setCatalogPrice(_ name: String, to price: String) {
        app.buttons["Mehr"].tap()
        let menuItem = app.buttons["Artikel verwalten"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "Menü")
        menuItem.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "\(name) in „Artikel verwalten“")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()   // nur der Pfeil öffnet Bearbeiten
        let field = app.textFields["Preis"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Formular „Artikel bearbeiten“ (Artikelstamm)")
        field.tap()
        if let old = field.value as? String, !old.isEmpty, old != "0,00" {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        field.typeText(price)
        app.buttons["Speichern"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Formular geschlossen")
        app.buttons["Schließen"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Artikel suchen oder hinzufügen"].waitForExistence(timeout: 5), "zurück zur Liste")
    }

    /// Wert im Preisfeld des Formulars, danach Formular schließen.
    private func editFormPrice(_ name: String) -> String? {
        openEdit(name)
        let value = app.textFields["Preis"].value as? String
        app.buttons["Schließen"].firstMatch.tap()
        _ = app.textFields["Preis"].waitForNonExistence(timeout: 5)
        return value
    }

    /// ☰ → „Kassenzettel scannen“ → „Aus Fotos wählen“ → neuestes Foto → „Kassenzettel prüfen“.
    private func scanReceiptFromPhotos() {
        app.buttons["Mehr"].tap()
        let menuItem = app.buttons["Kassenzettel scannen"]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5), "Menü")
        menuItem.tap()
        pickReceiptPhoto()
    }

    /// In der Aufnahme: „Aus Fotos wählen“ → neuestes Foto → bestätigen (öffnet „Kassenzettel prüfen“).
    private func pickReceiptPhoto() {
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
    }

    private func relaunchAfterSync() {
        Thread.sleep(forTimeInterval: 5)                      // Senden + Realtime-Echo abwarten
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Artikel suchen oder hinzufügen"].waitForExistence(timeout: 20), "Liste nach Neustart")
        Thread.sleep(forTimeInterval: 4)                      // Start-Abgleich abwarten (darf nichts zurücksetzen)
    }

    // MARK: - Prüfen

    private func checkButton(_ name: String) -> XCUIElement { app.buttons["\(name) abhaken"] }

    /// Preis-Element einer Karte („Preis 2,49 €“).
    private func priceLabel(_ euro: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Preis \(euro)")).firstMatch
    }

    private func assertServerPrice(_ name: String, _ expected: Double, file: StaticString = #filePath, line: UInt = #line) {
        let rows = serverRows("items?name=eq.\(encoded(name))&select=name,price")
        let price = rows.first?["price"] as? Double
        XCTAssertEqual(price ?? -1, expected, accuracy: 0.001, "Server: items.price von \(name) (\(rows))", file: file, line: line)
    }

    private func assertCatalogPrice(_ name: String, _ expected: Double, file: StaticString = #filePath, line: UInt = #line) {
        var price: Double?
        for _ in 0..<10 {                                     // Artikelstamm-Warteschlange sendet nacheinander
            let rows = serverRows("item_catalog?name_lower=eq.\(encoded(name.lowercased()))&select=name,price")
            price = rows.first?["price"] as? Double
            if let price, abs(price - expected) < 0.001 { break }
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertEqual(price ?? -1, expected, accuracy: 0.001, "Server: item_catalog.price von \(name)", file: file, line: line)
    }

    /// Server-Abfrage synchron (der Test selbst ist synchron, damit er beim ersten Fehler stoppt).
    private func serverRows(_ path: String) -> [[String: Any]] {
        let done = expectation(description: "server \(path)")
        nonisolated(unsafe) var rows: [[String: Any]] = []
        Task.detached {
            rows = await LiveTestCleanup.serverRows(path)
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        return rows
    }

    private func encoded(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
    }

    private func waitUntil(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        return condition()
    }

    private func shot(_ name: String) {
        guard let shots else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
    }
}
