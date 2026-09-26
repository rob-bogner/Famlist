/*
 ReceiptArchiveFormatTests.swift
 FamlistTests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für Hilfen des Kassenzettel-Archivs: Foto-Verkleinerung, Datumsumwandlung, Größenangabe.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptArchiveFormatTests: XCTestCase {
    func test_codec_downscalesLongEdgeTo2000_andStaysUnderLimit() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 4000), format: format).image { ctx in
            for y in stride(from: 0, to: 4000, by: 40) {           // viele Kanten wie Text auf einem Bon
                UIColor(white: CGFloat(y % 80) / 80, alpha: 1).setFill()
                ctx.fill(CGRect(x: 0, y: y, width: 3000, height: 20))
            }
        }
        let data = try XCTUnwrap(ReceiptPhotoCodec.jpeg(from: big))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size.height * decoded.scale, 2000)
        XCTAssertEqual(decoded.size.width * decoded.scale, 1500)
        XCTAssertLessThanOrEqual(data.count, ReceiptPhotoCodec.maxBytes)
    }

    func test_codec_doesNotUpscaleSmallImages() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 500), format: format).image { _ in }
        let decoded = try XCTUnwrap(UIImage(data: try XCTUnwrap(ReceiptPhotoCodec.jpeg(from: small))))
        XCTAssertEqual(decoded.size.width * decoded.scale, 300)
    }

    func test_day_roundTrip_keepsCalendarDay() throws {
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 0, minute: 30)))
        XCTAssertEqual(ReceiptDay.string(date), "2026-09-26")
        let parsed = try XCTUnwrap(ReceiptDay.date("2026-09-26"))
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: parsed),
                       DateComponents(year: 2026, month: 9, day: 26))
    }

    func test_timestamp_withMicroseconds() throws {
        let date = try XCTUnwrap(ReceiptDay.timestamp("2026-09-26T08:12:03.123456+00:00"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_790_410_323, accuracy: 1)
    }

    func test_summary_countAndSize() {
        XCTAssertEqual(ReceiptArchiveSetting.summary(count: 12, bytes: 38_000_000), "12 Bons · 38 MB")
        XCTAssertEqual(ReceiptArchiveSetting.summary(count: 1, bytes: 820_000), "1 Bon · 820 kB")
    }
}
