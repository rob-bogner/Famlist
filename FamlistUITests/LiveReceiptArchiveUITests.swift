/*
 LiveReceiptArchiveUITests.swift
 FamlistUITests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Live-Test gegen Supabase (Testkonto „Tester“): „Preise speichern“ legt den Bon im Kassenzettel-Archiv ab.
   Geprüft: Archiv-Zeile in der App, Zeile `receipts` und Foto im Bucket `receipt-images` auf dem Server,
   Stand nach einem Neustart, Detail, Löschen (Zeile und Foto weg, Preispunkte bleiben).

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_LIVE=1`. Der Bon ist das neueste Foto im Simulator
   (`swift scripts/make_test_receipt.swift /tmp/bon.png`, `xcrun simctl addmedia <ID> /tmp/bon.png`).
 - Kennzeichen des Test-Bons: 25.09.2026, Summe 5,07 € (LiveTestCleanup.removeLiveTestReceipts räumt damit auf).

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import XCTest

// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert.
@MainActor
final class LiveReceiptArchiveUITests: XCTestCase {
    private var app: XCUIApplication!
    private let shots = ProcessInfo.processInfo.environment["FAMLIST_SHOTS"]
    private let bonFilter = "receipts?purchased_at=eq.2026-09-25&total=eq.5.07"
    private var steps: LiveReceiptSteps { LiveReceiptSteps(app: app, shot: { self.shot($0) }) }

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FAMLIST_LIVE"] == "1", "nur mit TEST_RUNNER_FAMLIST_LIVE=1")
        continueAfterFailure = false
        await LiveTestCleanup.removeLiveTestData()
        await LiveTestCleanup.removeLiveTestReceipts()
        app = XCUIApplication()
        app.launch()
        addTeardownBlock {
            await LiveTestCleanup.removeLiveTestData()
            await LiveTestCleanup.removeLiveTestReceipts()
        }
    }

    func test_live_receiptArchived_survivesRestart_andDeletes() {
        steps.signInIfNeeded()
        steps.createNew("Livetest Quittengelee")
        steps.createNew("Livetest Birnensaft")
        savePricesFromPhoto()

        // Archiv in der App, danach auf dem Server (Zeile + Foto)
        openArchive()
        let row = archiveRow()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Bon im Archiv\n\(app.debugDescription)")
        XCTAssertTrue(steps.waitUntil(30) { !row.label.contains("wird hochgeladen") }, "hochgeladen: \(row.label)")
        shot("archive-1")
        let server = serverRows(bonFilter + "&select=id,photo_paths,line_count,saved_price_count,store_name")
        XCTAssertEqual(server.count, 1, "Server: eine Zeile receipts (\(server))")
        let path = (server.first?["photo_paths"] as? [String])?.first ?? ""
        XCTAssertEqual(server.first?["saved_price_count"] as? Int, 2, "Server: 2 Preise gespeichert")
        XCTAssertEqual(photoFiles(path), ["1.jpg"], "Server: Foto \(path) im Bucket")

        // Neustart: Bon weiterhin im Archiv
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Artikel suchen oder hinzufügen"].waitForExistence(timeout: 20), "Liste nach Neustart")
        openArchive()
        XCTAssertTrue(archiveRow().waitForExistence(timeout: 10), "Bon nach Neustart im Archiv")

        // Detail → Löschen
        archiveRow().tap()
        XCTAssertTrue(app.staticTexts["Summe laut Bon"].waitForExistence(timeout: 5), "Detail")
        XCTAssertTrue(app.staticTexts["5,07\u{00A0}€"].exists, "Summe 5,07 €")
        shot("detail")
        app.buttons["Löschen"].tap()
        let confirm = app.buttons.matching(identifier: "Löschen").element(boundBy: 1)
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "Rückfrage")
        confirm.tap()
        XCTAssertTrue(archiveRow().waitForNonExistence(timeout: 5), "Bon aus dem Archiv entfernt")

        XCTAssertTrue(steps.waitUntil(15) { self.serverRows(self.bonFilter + "&select=id").isEmpty }, "Server: Zeile gelöscht")
        XCTAssertEqual(photoFiles(path), [], "Server: Foto gelöscht")
        let prices = serverRows("price_points?item_name=eq.Livetest%20Quittengelee&purchased_at=eq.2026-09-25&select=price")
        XCTAssertFalse(prices.isEmpty, "Preispunkte bleiben nach dem Löschen")
    }

    // MARK: - Schritte

    /// ☰ → „Kassenzettel scannen“ → Foto → „Preise speichern“ (Rückfrage: „Nur Preisverlauf“) → „Liste behalten“.
    private func savePricesFromPhoto() {
        steps.scanReceiptFromPhotos()
        let save = app.buttons["Preise speichern"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Kassenzettel prüfen")
        XCTAssertTrue(steps.waitUntil(20) { save.isEnabled }, "Positionen erkannt und zugeordnet")
        save.tap()
        let alert = app.alerts["Artikelpreise aktualisieren?"]
        if alert.waitForExistence(timeout: 3) { alert.buttons["Nur Preisverlauf"].tap() }
        let keep = app.buttons["Liste behalten"]
        XCTAssertTrue(keep.waitForExistence(timeout: 15), "Einkauf erledigt")
        keep.tap()
        XCTAssertTrue(keep.waitForNonExistence(timeout: 5), "„Einkauf erledigt“ geschlossen")
    }

    /// ☰ → „Einstellungen“ → „Gespeicherte Kassenzettel“.
    private func openArchive() {
        let settings = app.buttons["Einstellungen"]
        app.buttons["Mehr"].tap()
        if !settings.waitForExistence(timeout: 3) { app.buttons["Mehr"].tap() }   // Tipp während Sheet-Animation
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "Menü")
        settings.tap()
        let open = app.buttons["Gespeicherte Kassenzettel ansehen"]
        XCTAssertTrue(open.waitForExistence(timeout: 8), "Einstellungen → Kassenzettel")
        open.tap()
        XCTAssertTrue(app.staticTexts["Kassenzettel"].waitForExistence(timeout: 5), "Archiv")
    }

    private func archiveRow() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "25.09.2026", "5,07")).firstMatch
    }

    // MARK: - Server

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

    /// Dateien im Ordner des Fotos (`<list>/<receipt>/`) laut Storage-Datenbank; nil = Abfrage fehlgeschlagen.
    private func photoFiles(_ path: String) -> [String]? {
        let folder = (path as NSString).deletingLastPathComponent
        let done = expectation(description: "photo \(folder)")
        nonisolated(unsafe) var files: [String]?
        Task.detached {
            files = await LiveTestCleanup.storageFiles(bucket: "receipt-images", folder: folder)
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        return files
    }

    private func shot(_ name: String) {
        guard let shots else { return }
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(shots)/\(name).png"))
    }
}
