/*
 ReceiptFlowDateTests.swift
 FamlistTests

 Famlist
 Created on: 08.11.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests: Kaufdatum nicht erkannt (T-008). Hinweis-Zustand, Wahl eines Datums, Speichern mit dem
   gewählten Datum im Preisverlauf und im Archiv, Sperre für Tage nach heute.

 🔰 Notes for Beginners:
 - Die Uhr ist fest (`flow.now`): So 08.11.2026, 12:00. Kein Test hängt vom Lauftag ab.
 - Der Bon hat keine Datumszeile; der Parser liefert dann kein Datum.

 📝 Last Change:
 - Initial creation (T-008).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ReceiptFlowDateTests: XCTestCase {
    private let calendar = Calendar.current
    private var fixedNow: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))!
    }
    private let bonWithoutDate = ["EDEKA Center", "KERRYGOLD BUTTER   2,49 A", "KOKOSM. 400ML   1,39 A", "SUMME   3,88"]
    private let bonWithDate = ["EDEKA Center", "24.09.2026", "KERRYGOLD BUTTER   2,49 A", "SUMME   2,49"]

    private func makeFlow(points: InMemoryPricePointsRepository, archive: ReceiptArchive? = nil,
                          defaults: UserDefaults? = nil) -> ReceiptFlowViewModel {
        let origin = archive.map { _ in
            ReceiptArchiveOrigin(listId: UUID(), listTitle: "Wocheneinkauf", createdBy: UUID(), creatorName: "Robert")
        }
        let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Kokosmilch"],
                                        catalog: nil,
                                        priceBook: PriceBook(repository: points, defaults: defaults ?? .standard),
                                        archive: archive, origin: origin)
        let now = fixedNow
        flow.now = { now }
        return flow
    }

    private func day(_ date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: date)
    }

    func test_noDateOnReceipt_marksPurchaseDateMissing() {
        let flow = makeFlow(points: InMemoryPricePointsRepository())
        flow.apply(ReceiptParser.parse(lines: bonWithoutDate))
        XCTAssertTrue(flow.isPurchaseDateMissing)
        XCTAssertNil(flow.purchaseDate)
    }

    func test_dateOnReceipt_isNotMissing() {
        let flow = makeFlow(points: InMemoryPricePointsRepository())
        flow.apply(ReceiptParser.parse(lines: bonWithDate))
        XCTAssertFalse(flow.isPurchaseDateMissing)
        XCTAssertEqual(day(flow.effectivePurchaseDate), DateComponents(year: 2026, month: 9, day: 24))
    }

    func test_chooseYesterday_everySavedPricePointCarriesYesterday() async {
        let points = InMemoryPricePointsRepository()
        let flow = makeFlow(points: points)
        flow.apply(ReceiptParser.parse(lines: bonWithoutDate))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: fixedNow)!

        XCTAssertTrue(flow.choosePurchaseDate(yesterday))
        XCTAssertFalse(flow.isPurchaseDateMissing, "Nach der Wahl verschwindet der Hinweis")
        await flow.savePrices()

        XCTAssertFalse(points.stored.isEmpty)
        XCTAssertTrue(points.stored.allSatisfy { day($0.purchasedAt) == DateComponents(year: 2026, month: 11, day: 7) })
    }

    func test_noChoice_savesWithToday() async {
        let points = InMemoryPricePointsRepository()
        let flow = makeFlow(points: points)
        flow.apply(ReceiptParser.parse(lines: bonWithoutDate))
        await flow.savePrices()

        XCTAssertFalse(points.stored.isEmpty)
        XCTAssertTrue(points.stored.allSatisfy { day($0.purchasedAt) == DateComponents(year: 2026, month: 11, day: 8) })
    }

    func test_futureDate_isRejected() {
        let flow = makeFlow(points: InMemoryPricePointsRepository())
        flow.apply(ReceiptParser.parse(lines: bonWithoutDate))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: fixedNow)!

        XCTAssertFalse(flow.choosePurchaseDate(tomorrow))
        XCTAssertNil(flow.purchaseDate)
        XCTAssertTrue(flow.isPurchaseDateMissing)
        XCTAssertTrue(flow.isSelectable(fixedNow), "Heute ist wählbar")
        XCTAssertFalse(flow.isSelectable(tomorrow))
    }

    func test_backToCapture_resetsMissingState() {
        let flow = makeFlow(points: InMemoryPricePointsRepository())
        flow.apply(ReceiptParser.parse(lines: bonWithoutDate))
        flow.backToCapture()
        XCTAssertFalse(flow.isPurchaseDateMissing)
        XCTAssertNil(flow.purchaseDate)
    }

    func test_chosenDate_landsInArchivedReceipt() async throws {
        let suite = "ReceiptFlowDateTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptFlowDateTests-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: root)
            defaults.removePersistentDomain(forName: suite)
        }
        let repo = InMemoryReceiptsRepository()
        let store = ReceiptArchiveLocalStore(directory: root.appendingPathComponent("support"),
                                             photoCache: root.appendingPathComponent("caches"))
        let archive = ReceiptArchive(repository: repo, store: store, defaults: defaults)
        let flow = makeFlow(points: InMemoryPricePointsRepository(), archive: archive, defaults: defaults)
        flow.recognize = { _ in self.bonWithoutDate }
        flow.addPage(UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        })
        await flow.process()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: fixedNow)!
        XCTAssertTrue(flow.choosePurchaseDate(twoDaysAgo))
        await flow.savePrices()
        await archive.flush()

        let receipt = try XCTUnwrap(repo.receipts.first)
        XCTAssertEqual(day(receipt.purchasedAt), DateComponents(year: 2026, month: 11, day: 6))
    }
}
