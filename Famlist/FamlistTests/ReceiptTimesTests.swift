/*
 ReceiptTimesTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für ReceiptTimes: Ende aus Bon-Uhrzeit oder Aufnahmezeit, Beginn laut Liste nur wenn plausibel.

 🔰 Notes for Beginners:
 - Alle Zeiten in Europe/Berlin (ReceiptTimes.calendar).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptTimesTests: XCTestCase {
    private let cal = ReceiptTimes.calendar

    private func at(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 9) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    func test_bonTime_onPurchaseDay() {
        let r = ReceiptTimes.make(day: at(24, 0, 0), time: DateComponents(hour: 18, minute: 5),
                                  capturedAt: at(24, 20, 0), listStart: at(24, 17, 42))
        XCTAssertEqual(r.end, at(24, 18, 5))
        XCTAssertEqual(r.start, at(24, 17, 42))
    }

    func test_noBonTime_captureSameDay_isEnd() {
        let r = ReceiptTimes.make(day: at(24, 12, 0), time: nil, capturedAt: at(24, 19, 0), listStart: nil)
        XCTAssertEqual(r.end, at(24, 19, 0))
        XCTAssertNil(r.start)
    }

    /// Alter Bon, heute fotografiert: keine Uhrzeit statt einer falschen.
    func test_noBonTime_captureOtherDay_noTimes() {
        let r = ReceiptTimes.make(day: at(20, 12, 0), time: nil, capturedAt: at(24, 19, 0), listStart: at(24, 18, 0))
        XCTAssertNil(r.end)
        XCTAssertNil(r.start)
    }

    func test_startAfterEnd_isDropped() {
        let r = ReceiptTimes.make(day: at(24, 0, 0), time: DateComponents(hour: 18, minute: 5),
                                  capturedAt: nil, listStart: at(24, 18, 30))
        XCTAssertNil(r.start)
        XCTAssertEqual(r.end, at(24, 18, 5))
    }

    func test_startMoreThan4hBeforeEnd_isDropped() {
        let r = ReceiptTimes.make(day: at(24, 0, 0), time: DateComponents(hour: 18, minute: 5),
                                  capturedAt: nil, listStart: at(24, 14, 0))
        XCTAssertNil(r.start)
    }

    /// Tagesgrenze: Einkauf am 31.08. um 23:59 bleibt im August.
    func test_lastMinuteOfMonth_staysOnDay() {
        let r = ReceiptTimes.make(day: at(31, 12, 0, month: 8), time: DateComponents(hour: 23, minute: 59),
                                  capturedAt: nil, listStart: nil)
        XCTAssertEqual(cal.dateComponents([.month, .day, .hour, .minute], from: r.end!),
                       DateComponents(month: 8, day: 31, hour: 23, minute: 59))
    }
}
