/*
 ReceiptParserMetaTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für ReceiptParser+Meta: Uhrzeit des Einkaufs und Adresse des Ladens.

 🔰 Notes for Beginners:
 - Die Beispiel-Bons sind im Aufbau typischer Bons von Edeka, Rewe, Lidl und dm nachgebaut (keine echten Scans).
 - TSE-Zeitstempel mit „Z“ sind UTC; am 12.09.2026 gilt in Berlin Sommerzeit (+2 h).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ReceiptParserMetaTests: XCTestCase {

    private func parse(_ bon: String) -> ParsedReceipt {
        ReceiptParser.parse(lines: bon.components(separatedBy: "\n"))
    }

    private func hm(_ c: DateComponents?) -> String? {
        c.map { String(format: "%02d:%02d", $0.hour ?? -1, $0.minute ?? -1) }
    }

    func test_edeka_timeInDateLine_streetAfterStore() {
        let r = parse("""
        EDEKA Center Muster
        Leopoldstr. 82
        80802 München
        Tel. 089 1234567
        KERRYGOLD BUTTER         2,49 A
        SUMME                    2,49
        Geg. EC-Karte            2,49
        24.09.2026 18:05 Bon-Nr. 1234
        """)
        XCTAssertEqual(hm(r.time), "18:05")
        XCTAssertEqual(r.address, "Leopoldstr. 82")
        XCTAssertEqual(r.lines.count, 1, "Metadaten ändern die Positionen nicht")
    }

    func test_rewe_timeInLineBelowDate_withSeconds() {
        let r = parse("""
        REWE Markt GmbH
        Musterstraße 12
        80331 München
        KERRYGOLD BUTTER         2,49 B
        SUMME                EUR 2,49
        Datum: 24.09.2026
        Uhrzeit: 18:42:10 Uhr
        """)
        XCTAssertEqual(hm(r.time), "18:42")
        XCTAssertEqual(r.address, "Musterstraße 12")
    }

    func test_lidl_noClockTime_usesTseStop_convertedFromUTC() {
        let r = parse("""
        LIDL
        Hauptstr. 5a
        12345 Berlin
        MILCH 1,5%               1,19 A
        zu zahlen                1,19
        TSE-Start: 2026-09-12T15:10:02.000Z
        TSE-Stop: 2026-09-12T15:12:40.000Z
        12.09.26  Filiale 1234
        """)
        XCTAssertEqual(hm(r.time), "17:12", "UTC 15:12 = 17:12 Sommerzeit Berlin")
        XCTAssertEqual(r.address, "Hauptstr. 5a")
    }

    func test_dm_timeWithWord_andStreetWithStrasse() {
        let r = parse("""
        dm-drogerie markt
        Leopoldstraße 1
        80802 München
        Datum 21.08.2026 Zeit 10:07
        BALEA DUSCHGEL           0,95 1
        SUMME EUR                0,95
        """)
        XCTAssertEqual(r.store, "dm")
        XCTAssertEqual(hm(r.time), "10:07")
        XCTAssertEqual(r.address, "Leopoldstraße 1")
    }

    func test_tseInLocalTime_isTakenAsIs() {
        let r = parse("""
        REWE
        TSE-Stop: 2026-09-24T18:42:10
        """)
        XCTAssertEqual(hm(r.time), "18:42")
    }

    func test_noTime_noAddress_areNil() {
        let r = parse("""
        REWE
        BANANEN                  1,29 B
        SUMME                    1,29
        24.09.2026
        """)
        XCTAssertNil(r.time)
        XCTAssertNil(r.address)
    }

    func test_onlyPostalCode_isUsedAsAddress() {
        let r = parse("""
        Netto
        80802 München
        BANANEN                  1,29 B
        """)
        XCTAssertEqual(r.address, "80802 München")
    }

    /// „BIO RING 2,49“ ist eine Position, keine Straße.
    func test_articleLineWithStreetWord_isNoAddress() {
        let r = parse("""
        EDEKA
        BIO RING 2               2,49 A
        SUMME                    2,49
        """)
        XCTAssertNil(r.address)
    }

    /// Preise mit Komma sind keine Uhrzeiten.
    func test_priceIsNoTime() {
        XCTAssertNil(ReceiptParser.detectTime(["24.09.2026", "BUTTER 12,49 A"]))
    }

    // MARK: - TSE in UTC: Versatz vom Datum des Zeitstempels, nicht vom Lauftag

    private func tse(_ stamp: String) -> String? {
        hm(ReceiptParser.detectTime(["TSE-Stop: \(stamp)"]))
    }

    /// Sommerzeit: +2 h, auch ohne Sekunden im Zeitstempel.
    func test_tseUTC_summer_addsTwoHours() {
        XCTAssertEqual(tse("2026-07-01T10:05Z"), "12:05")
    }

    /// Winterzeit: +1 h.
    func test_tseUTC_winter_addsOneHour() {
        XCTAssertEqual(tse("2026-01-15T10:05:00.000Z"), "11:05")
    }

    /// Umstellung am 29.03.2026 um 01:00 UTC.
    func test_tseUTC_dstStartDay_switchesAtOneUTC() {
        XCTAssertEqual(tse("2026-03-29T00:30:00Z"), "01:30")
        XCTAssertEqual(tse("2026-03-29T01:30:00Z"), "03:30")
    }

    func test_tseUTC_crossesMidnight() {
        XCTAssertEqual(tse("2026-09-12T23:30:00Z"), "01:30")
    }

    /// Ein unmögliches Datum (Lesefehler) ergibt keine Uhrzeit statt einer falschen.
    func test_tseUTC_impossibleDate_isNil() {
        XCTAssertNil(ReceiptParser.detectTime(["TSE-Stop: 2026-02-30T10:05:00Z"]))
    }
}
