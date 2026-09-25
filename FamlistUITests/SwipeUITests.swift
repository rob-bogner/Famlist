/*
 SwipeUITests.swift
 FamlistUITests
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - UI-Tests der eigenen Wischgeste (SwipeableItemRow) auf der In-Memory-Liste (-uiTestFixture).

 🔰 Notes for Beginners:
 - Kartenposition = Position des Abhak-Kreises („<Name> abhaken“).
 - Erwartete Werte (96 pt rechts offen, 86 pt „Zurück“, Durchwischen) stammen aus SwipeRevealPhysics.
 - Ursprünglich auf dem echten iPhone 16 Pro Max validiert (14/14).

 📝 Last Change:
 - Aus der Scratchpad-Kopie der Hybrid-Redesign-Session ins Projekt übernommen.
 ------------------------------------------------------------------------
 */

import XCTest

/// Real-device swipe checks on the in-memory fixture. Card position = position of the check circle.
// @MainActor: XCUIApplication und XCUIElement sind Main-Actor-isoliert; XCTest führt UI-Tests ohnehin auf dem Main Thread aus.
@MainActor
final class SwipeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-uiTestFixture"]
        app.launch()
        XCTAssertTrue(check("Äpfel").waitForExistence(timeout: 15))
    }

    private func check(_ name: String) -> XCUIElement { app.buttons["\(name) abhaken"] }
    private func x(_ name: String) -> CGFloat { check(name).frame.minX }

    /// Drag on the Äpfel card starting `fromRight` pt left of the check circle centre.
    private func drag(fromRight: CGFloat, dx: CGFloat, velocity: CGFloat) {
        let start = check("Äpfel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -fromRight, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: 0)),
                    withVelocity: XCUIGestureVelocity(velocity), thenHoldForDuration: 0.05)
        Thread.sleep(forTimeInterval: 1.0)
    }

    private func report(_ label: String, rest: CGFloat) {
        let now = x("Äpfel")
        print("[DEVICE] \(label): rest=\(Int(rest)) now=\(Int(now)) delta=\(Int(now - rest))")
    }

    func test_A_left_fromCheckCircle() {
        let rest = x("Äpfel"); drag(fromRight: 0, dx: -200, velocity: 600); report("left from circle", rest: rest)
        XCTAssertLessThan(x("Äpfel"), rest - 200, "open")
    }

    func test_B_left_fromName() {
        let rest = x("Äpfel"); drag(fromRight: 200, dx: -150, velocity: 600); report("left from name", rest: rest)
        XCTAssertLessThan(x("Äpfel"), rest - 200, "open")
    }

    func test_C_left_fromThumbnail() {
        let rest = x("Äpfel"); drag(fromRight: 280, dx: -60, velocity: 600); report("left from thumbnail", rest: rest)
        XCTAssertLessThan(x("Äpfel"), rest - 200, "open")
    }

    func test_D_left_fromName_slow() {
        let rest = x("Äpfel"); drag(fromRight: 200, dx: -150, velocity: 200); report("left from name slow", rest: rest)
        XCTAssertLessThan(x("Äpfel"), rest - 200, "open")
    }

    func test_E_right_toButton_staysOpen_thenTapChecks() {
        let rest = x("Äpfel"); drag(fromRight: 250, dx: 110, velocity: 500); report("right to button", rest: rest)
        XCTAssertTrue(check("Äpfel").exists, "must not be checked yet")
        XCTAssertEqual(x("Äpfel"), rest + 96, accuracy: 4, "open on the right")
        // Grüner Button: 76er Spalte, 10 pt Einzug vom linken Kartenrand (Karte beginnt bei rest − (cardWidth − 44 − 15)).
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20 + 10 + 38, dy: check("Äpfel").frame.midY - 14)).tap()
        XCTAssertTrue(check("Äpfel").waitForNonExistence(timeout: 3), "tap on button checks")
    }

    func test_J_right_fullSwipe_checks() {
        drag(fromRight: 280, dx: 240, velocity: 600)
        XCTAssertTrue(check("Äpfel").waitForNonExistence(timeout: 3), "full swipe checks")
    }

    func test_K_checkedItem_rightToButton_staysChecked_fullSwipeRestores() {
        drag(fromRight: 280, dx: 240, velocity: 600)
        let checked = app.buttons["Äpfel ist abgehakt. Tippen macht es wieder offen."]
        for _ in 0..<6 where !(checked.exists && checked.isHittable && checked.frame.maxY < app.windows.firstMatch.frame.height - 140) {
            app.swipeUp()
        }
        XCTAssertTrue(checked.exists)
        let rest = checked.frame.minX
        let start = checked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -250, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 110, dy: 0)),
                    withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.05)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(checked.exists, "still checked after reveal")
        XCTAssertEqual(checked.frame.minX, rest + 96, accuracy: 4, "Zurück button revealed")
        let s2 = checked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -250, dy: 0))
        s2.press(forDuration: 0.05, thenDragTo: s2.withOffset(CGVector(dx: 150, dy: 0)),
                 withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.05)
        XCTAssertTrue(checked.waitForNonExistence(timeout: 3), "full swipe restores")
    }

    func test_F_left_fromEmptyAreaNearCircle() {
        let rest = x("Äpfel"); drag(fromRight: 70, dx: -200, velocity: 600); report("left from empty near circle", rest: rest)
        XCTAssertLessThan(x("Äpfel"), rest - 200, "open")
    }

    func test_G_left_fromEmptyAreaCenter_withSnapBack() {
        // Links wischen, dann Daumen zurückschnellen lassen (wie auf dem Gerät gemessen).
        let rest = x("Äpfel")
        let start = check("Äpfel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -150, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -170, dy: 0)),
                    withVelocity: XCUIGestureVelocity(700), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 1.0)
        report("left from center", rest: rest)
        XCTAssertLessThan(x("Äpfel"), rest - 200, "open")
    }

    func test_H_right_fromEmptyArea_toButton_opens() {
        let rest = x("Äpfel"); drag(fromRight: 120, dx: 110, velocity: 600)
        XCTAssertTrue(check("Äpfel").exists, "not checked")
        XCTAssertEqual(x("Äpfel"), rest + 96, accuracy: 4, "open on the right")
    }

    func test_I_verticalScroll_fromEmptyArea_scrolls() {
        let y0 = check("Äpfel").frame.minY
        let start = check("Äpfel").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -120, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -250)),
                    withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 1.0)
        print("[DEVICE] vertical from empty: y0=\(Int(y0)) now=\(Int(check("Äpfel").frame.minY))")
        XCTAssertLessThan(check("Äpfel").frame.minY, y0 - 80, "scrolled")
    }

    private func checkedÄpfelVisible() -> XCUIElement {
        drag(fromRight: 280, dx: 240, velocity: 600)
        let checked = app.buttons["Äpfel ist abgehakt. Tippen macht es wieder offen."]
        for _ in 0..<6 where !(checked.exists && checked.isHittable && checked.frame.maxY < app.windows.firstMatch.frame.height - 140) {
            app.swipeUp()
        }
        return checked
    }

    func test_L_checkedItem_leftToButton_staysChecked() {
        let checked = checkedÄpfelVisible()
        XCTAssertTrue(checked.exists)
        let rest = checked.frame.minX
        let start = checked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -120, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -100, dy: 0)),
                    withVelocity: XCUIGestureVelocity(500), thenHoldForDuration: 0.05)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(checked.exists, "still checked")
        XCTAssertEqual(checked.frame.minX, rest - 86, accuracy: 4, "Zurück revealed")
    }

    func test_M_checkedItem_leftFullSwipe_restores() {
        let checked = checkedÄpfelVisible()
        XCTAssertTrue(checked.exists)
        let start = checked.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: -60, dy: 0))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -240, dy: 0)),
                    withVelocity: XCUIGestureVelocity(600), thenHoldForDuration: 0.05)
        XCTAssertTrue(checked.waitForNonExistence(timeout: 3), "full left swipe restores")
    }

    func test_N_openItem_leftFullSwipe_doesNotDelete() {
        drag(fromRight: 60, dx: -330, velocity: 800)
        XCTAssertTrue(check("Äpfel").exists, "must not be deleted or changed")
    }
}
