/*
 SwipeRevealPhysicsTests.swift
 FamlistTests
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit-Tests der Wischphysik (SwipeRevealPhysics): Versatz, Gummiband, drei Ruhelagen,
   Rechts zweistufig, Zurückschnellen vs. bewusstes Abbrechen (mit echten Gerätemessungen).

 📝 Last Change:
 - Auf drei Ruhelagen (zu / rechts offen / links offen) und Durchwischen umgestellt.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class SwipeRevealPhysicsTests: XCTestCase {
    private typealias P = SwipeRevealPhysics
    private let physics = SwipeRevealPhysics(revealWidth: 256, leadingWidth: 96)

    /// Drag from closed where the card simply followed the finger.
    private func drag(final: CGFloat, v: CGFloat, min: CGFloat = 0, max: CGFloat = 0,
                      backFromMin: Double = 0, backFromMax: Double = 0) -> P.Drag {
        P.Drag(translation: final, velocity: v, minOffset: Swift.min(min, final), maxOffset: Swift.max(max, final),
               pullBackFromMin: backFromMin, pullBackFromMax: backFromMax)
    }

    // MARK: - Offset

    func test_offset_followsFingerOneToOne() {
        XCTAssertEqual(physics.offset(rest: .closed, translation: -100), -100)
        XCTAssertEqual(physics.offset(rest: .trailing, translation: 56), -200)
        XCTAssertEqual(physics.offset(rest: .closed, translation: 150), 150)       // rechts bis 180 1:1
        XCTAssertEqual(physics.offset(rest: .leading, translation: 50), 146)
    }

    func test_offset_rubberBandsBeyondTargets() {
        let left = physics.offset(rest: .closed, translation: -2000)
        XCTAssertLessThan(left, -256)
        XCTAssertGreaterThan(left, -256 - 60)
        let right = physics.offset(rest: .closed, translation: 2000)
        XCTAssertGreaterThan(right, 180)
        XCTAssertLessThan(right, 180 + 60)
        let fromTrailing = physics.offset(rest: .trailing, translation: 400)       // über 0 hinaus: nur Gummiband
        XCTAssertLessThan(fromTrailing, 60)
    }

    // MARK: - Left swipe (trailing)

    func test_left_slowDrag_opensFrom90pt() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: -80, v: -50)), .rest(.closed))
        XCTAssertEqual(physics.release(from: .closed, drag(final: -100, v: -50)), .rest(.trailing))
    }

    func test_left_fastFling_opens() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: -40, v: -900)), .rest(.trailing))
    }

    func test_left_thumbSnapBack_staysOpen_deviceMeasurements() {
        // (weitester Punkt, Ende, Geschwindigkeit, Dauer der Rückbewegung) – gemessen am 24.09.2026
        XCTAssertEqual(physics.release(from: .closed, drag(final: -215, v: 657, min: -256, backFromMin: 0.09)), .rest(.trailing))
        XCTAssertEqual(physics.release(from: .closed, drag(final: 7, v: 1244, min: -158, backFromMin: 0.13)), .rest(.trailing))
        XCTAssertEqual(physics.release(from: .closed, drag(final: -79, v: 869, min: -236, backFromMin: 0.12)), .rest(.trailing))
        XCTAssertEqual(physics.release(from: .closed, drag(final: -36, v: 344, min: -134, backFromMin: 0.28)), .rest(.trailing))
    }

    func test_left_deliberateCancel_closes_deviceMeasurements() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: -76, v: 760, min: -137, backFromMin: 0.783)), .rest(.closed))
        XCTAssertEqual(physics.release(from: .closed, drag(final: 15, v: 616, min: -134, backFromMin: 0.95)), .rest(.closed))
    }

    func test_left_longPullBackStillBeyondThreshold_staysOpen() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: -120, v: 300, min: -200, backFromMin: 0.8)), .rest(.trailing))
    }

    func test_left_snapBackFarRight_neverChecks() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: 60, v: 1500, min: -180, max: 60, backFromMin: 0.1)),
                       .rest(.trailing))
    }

    func test_fromTrailing_closesOnlyPastHalf_andNeverChecks() {
        XCTAssertEqual(physics.release(from: .trailing, P.Drag(translation: 100, velocity: 50, minOffset: -256, maxOffset: -156)),
                       .rest(.trailing))
        XCTAssertEqual(physics.release(from: .trailing, P.Drag(translation: 140, velocity: 50, minOffset: -256, maxOffset: -116)),
                       .rest(.closed))
        XCTAssertEqual(physics.release(from: .trailing, P.Drag(translation: 500, velocity: 2000, minOffset: -256, maxOffset: 40)),
                       .rest(.closed))
    }

    // MARK: - Right swipe (leading, two stages)

    func test_right_toButtonAndRelease_staysOpen_doesNotCheck() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: 100, v: 50)), .rest(.leading))
        XCTAssertEqual(physics.release(from: .closed, drag(final: 120, v: 900)), .rest(.leading))  // schnell, aber nicht durchgewischt
        XCTAssertEqual(physics.release(from: .closed, drag(final: 60, v: 50)), .rest(.leading))
    }

    func test_right_shortStroke_closes() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: 30, v: 50)), .rest(.closed))
    }

    func test_right_fullSwipe_triggers() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: 200, v: 400)), .triggerLeading)
    }

    func test_right_fullSwipeWithThumbSnapBack_stillTriggers() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: 14, v: -600, max: 200, backFromMax: 0.12)), .triggerLeading)
    }

    func test_right_fullSwipeDeliberatelyPulledBack_onlyOpens() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: 110, v: -300, max: 200, backFromMax: 0.8)), .rest(.leading))
        XCTAssertEqual(physics.release(from: .closed, drag(final: 20, v: -300, max: 200, backFromMax: 0.8)), .rest(.closed))
    }

    func test_fromLeading_swipeFurther_triggers_orLeftCloses() {
        XCTAssertEqual(physics.release(from: .leading, P.Drag(translation: 100, velocity: 300, minOffset: 96, maxOffset: 196)),
                       .triggerLeading)
        XCTAssertEqual(physics.release(from: .leading, P.Drag(translation: -80, velocity: -100, minOffset: 16, maxOffset: 96)),
                       .rest(.closed))
        XCTAssertEqual(physics.release(from: .leading, P.Drag(translation: -20, velocity: -50, minOffset: 76, maxOffset: 96)),
                       .rest(.leading))
    }

    func test_withoutLeadingWidth_rightSwipeNeverOpens() {
        let noLeading = SwipeRevealPhysics(revealWidth: 256)
        XCTAssertEqual(noLeading.release(from: .closed, drag(final: 150, v: 900)), .rest(.closed))
    }

    // MARK: - Progress

    func test_progress_isClampedToUnitRange() {
        XCTAssertEqual(physics.revealProgress(offset: 20), 0)
        XCTAssertEqual(physics.revealProgress(offset: -128), 0.5, accuracy: 0.001)
        XCTAssertEqual(physics.revealProgress(offset: -300), 1)
        XCTAssertEqual(physics.leadingProgress(offset: 48), 0.5, accuracy: 0.001)
        XCTAssertEqual(physics.leadingProgress(offset: 200), 1)
    }

    // MARK: - Checked items: left swipe two-stage („Zurück“)

    private let checkedPhysics = SwipeRevealPhysics(revealWidth: 86, leadingWidth: 96, trailingFullSwipe: true)

    func test_checked_leftToButton_staysOpen() {
        XCTAssertEqual(checkedPhysics.release(from: .closed, drag(final: -100, v: -50)), .rest(.trailing))
    }

    func test_checked_leftFullSwipe_triggersUndo() {
        XCTAssertEqual(checkedPhysics.release(from: .closed, drag(final: -200, v: -400)), .triggerTrailing)
        XCTAssertEqual(checkedPhysics.release(from: .trailing, P.Drag(translation: -110, velocity: -300, minOffset: -196, maxOffset: -86)),
                       .triggerTrailing)
    }

    func test_checked_leftFullSwipeWithSnapBack_stillTriggers_deliberateDoesNot() {
        XCTAssertEqual(checkedPhysics.release(from: .closed, drag(final: -60, v: 700, min: -200, backFromMin: 0.12)), .triggerTrailing)
        XCTAssertEqual(checkedPhysics.release(from: .closed, drag(final: -100, v: 300, min: -200, backFromMin: 0.8)), .rest(.trailing))
    }

    func test_checked_offsetFollowsFingerToFullSwipe() {
        XCTAssertEqual(checkedPhysics.offset(rest: .closed, translation: -170), -170)   // 1:1 bis −180
    }

    func test_open_leftFullSwipe_neverTriggers() {
        XCTAssertEqual(physics.release(from: .closed, drag(final: -300, v: -1500)), .rest(.trailing))
    }
}
