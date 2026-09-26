/*
 ReceiptFlowArchiveTests.swift
 FamlistTests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests: „Preise speichern“ legt einen Archiv-Eintrag an (Schalter an) bzw. keinen (Schalter aus).

 🔰 Notes for Beginners:
 - Die Texterkennung wird durch feste Zeilen ersetzt; das Bild ist ein kleines weißes Rechteck.
 - Archiv-Dateien liegen in einem eigenen temporären Ordner und werden nach jedem Test gelöscht.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ReceiptFlowArchiveTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private let listId = UUID()
    private let bon = ["EDEKA Center", "24.09.2026", "KERRYGOLD BUTTER   2,49 A", "KOKOSM. 400ML   1,39 A",
                       "FAIRGL.VM SCHOKO   3,49 A", "SUMME   7,37"]

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptFlowArchiveTests-\(UUID().uuidString)")
        defaults = UserDefaults(suiteName: "ReceiptFlowArchiveTests")
        defaults.removePersistentDomain(forName: "ReceiptFlowArchiveTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: "ReceiptFlowArchiveTests")
    }

    private func makeFlow(archive: ReceiptArchive, points: InMemoryPricePointsRepository) -> ReceiptFlowViewModel {
        let origin = ReceiptArchiveOrigin(listId: listId, listTitle: "Wocheneinkauf", createdBy: UUID(), creatorName: "Robert")
        let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Kokosmilch"],
                                        catalog: nil, priceBook: PriceBook(repository: points, defaults: defaults),
                                        archive: archive, origin: origin)
        flow.recognize = { _ in self.bon }
        let page = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        }
        flow.addPage(page)
        flow.addPage(page)
        return flow
    }

    private func makeArchive(_ repo: InMemoryReceiptsRepository) -> ReceiptArchive {
        let store = ReceiptArchiveLocalStore(directory: root.appendingPathComponent("support"),
                                             photoCache: root.appendingPathComponent("caches"))
        return ReceiptArchive(repository: repo, store: store, defaults: defaults)
    }

    func test_savePrices_archivesReceiptWithPhotosAndCounts() async throws {
        let repo = InMemoryReceiptsRepository()
        let archive = makeArchive(repo)
        let flow = makeFlow(archive: archive, points: InMemoryPricePointsRepository())
        await flow.process()
        await flow.savePrices()
        await archive.flush()

        let receipt = try XCTUnwrap(repo.receipts.first)
        XCTAssertEqual(receipt.storeName, "EDEKA")
        XCTAssertEqual(receipt.listId, listId)
        XCTAssertEqual(receipt.total, Decimal(string: "7.37"))
        XCTAssertEqual(receipt.lineCount, 3)
        XCTAssertEqual(receipt.savedPriceCount, 2)
        XCTAssertEqual(receipt.photoPaths.count, 2)
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day], from: receipt.purchasedAt),
                       DateComponents(year: 2026, month: 9, day: 24))
        XCTAssertEqual(Set(repo.photos.keys), Set(receipt.photoPaths))
        XCTAssertEqual(flow.phase, .done(saved: 2))
    }

    func test_savePrices_switchOff_savesPricesButNoReceipt() async {
        defaults.set(false, forKey: ReceiptArchiveSetting.storageKey)
        let repo = InMemoryReceiptsRepository()
        let points = InMemoryPricePointsRepository()
        let archive = makeArchive(repo)
        let flow = makeFlow(archive: archive, points: points)
        await flow.process()
        await flow.savePrices()
        await archive.flush()

        XCTAssertTrue(repo.receipts.isEmpty)
        XCTAssertTrue(archive.receipts.isEmpty)
        XCTAssertEqual(points.stored.count, 2, "Preise werden trotzdem gespeichert")
    }
}
