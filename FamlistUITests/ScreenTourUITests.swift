/*
 ScreenTourUITests.swift
 FamlistUITests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fotografiert jeden Screen, jede Überlagerung und jedes Sheet (Fixture im Speicher, kein Netz).
   Damit wird geprüft, dass auf allen iPhones und bei größerer iOS-Schrift nichts abgeschnitten,
   gestaucht oder überlagert ist.

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_SHOTS=<Ordner>`; die Bilder landen dort als PNG.
 - Schriftgröße über `TEST_RUNNER_FAMLIST_TEXTSIZE` (z. B. UICTContentSizeCategoryXXXL), sonst Standard.
 - Dunkelmodus über `TEST_RUNNER_FAMLIST_DARK=1`.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest

final class ScreenTourUITests: XCTestCase {
    private var shotsDirectory: String?
    private let environment = ProcessInfo.processInfo.environment

    static let screens = ["signIn", "profileSetup", "acceptInvite"]
    static let overlays = ["menu", "sort", "copy", "delete", "copied", "undo"]
    static let sheets = ["search", "newItem", "edit", "productImage", "lists", "barcode", "createList",
                         "listOptions", "shareMembers", "settings", "editProfile", "deleteAccount",
                         "manageCategories", "editCategory", "receiptCapture", "receiptReview",
                         "shoppingDone", "priceHistory", "manageItems", "importClipboard"]

    override func setUpWithError() throws {
        shotsDirectory = environment["FAMLIST_SHOTS"]
        try XCTSkipIf(shotsDirectory == nil, "nur mit TEST_RUNNER_FAMLIST_SHOTS=<Ordner>")
        continueAfterFailure = true
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-uiTestFixture", "-designFixture"] + extra
        if let size = environment["FAMLIST_TEXTSIZE"] { arguments += ["-UIPreferredContentSizeCategoryName", size] }
        if environment["FAMLIST_DARK"] == "1" { arguments += ["-AppleInterfaceStyle", "Dark", "-appearanceChoice", "dark"] }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 1.2)                       // Einblend-Animationen abwarten
        guard let shotsDirectory else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "\(shotsDirectory)/\(name).png"))
    }

    func test_tour() {
        let list = launch([])
        shoot(list, "00-list")
        list.terminate()
        for screen in Self.screens {
            let app = launch(["-designScreen", screen])
            shoot(app, "01-screen-\(screen)")
            app.terminate()
        }
        for overlay in Self.overlays {
            let app = launch(["-designOverlay", overlay])
            shoot(app, "02-overlay-\(overlay)")
            app.terminate()
        }
        for sheet in Self.sheets {
            let app = launch(["-designSheet", sheet])
            shoot(app, "03-sheet-\(sheet)")
            app.terminate()
        }
    }
}
