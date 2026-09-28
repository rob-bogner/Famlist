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
 - Einkaufsdaten: Adresse, Uhrzeit, Beginn laut Liste, Kategorie und Inhalt je Zeile.
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
        XCTAssertTrue(points.stored.allSatisfy { $0.receiptId == nil }, "Ohne Archiv-Eintrag kein Verweis auf einen Bon")
    }

    /// Der Bon speichert seine Positionen; die Preise desselben Einkaufs verweisen auf ihn (Migration 029).
    func test_savePrices_storesLines_andLinksPrices() async throws {
        let repo = InMemoryReceiptsRepository()
        let points = InMemoryPricePointsRepository()
        let archive = makeArchive(repo)
        let flow = makeFlow(archive: archive, points: points)
        await flow.process()
        await flow.savePrices()
        await archive.flush()

        let receipt = try XCTUnwrap(repo.receipts.first)
        let lines = try XCTUnwrap(receipt.lines)
        XCTAssertEqual(lines.map(\.raw), ["KERRYGOLD BUTTER", "KOKOSM. 400ML", "FAIRGL.VM SCHOKO"])
        XCTAssertEqual(lines.map(\.isSaved), [true, true, false])
        XCTAssertEqual(lines[0].itemName, "Kerrygold, original irische Butter")
        XCTAssertNil(lines[2].itemName, "Nicht bestätigter neuer Artikel wird nicht zugeordnet")
        XCTAssertEqual(lines[1].price, Decimal(string: "1.39"))
        XCTAssertEqual(points.stored.count, 2)
        XCTAssertTrue(points.stored.allSatisfy { $0.receiptId == receipt.id })
    }

    /// Archiv-Einträge von vorher (ohne `lines` im lokalen JSON) lassen sich weiter lesen.
    func test_archivedReceipt_decodesWithoutLines() throws {
        let old = #"{"id":"6F1C2B2E-8B1B-4B6B-9A0C-0D6B8E7F1A11","listId":"0B8E9C1D-3C44-4B0E-8F21-5B7A9E2C4D10","#
            + #""storeName":"EDEKA","purchasedAt":780000000,"total":7.37,"lineCount":3,"savedPriceCount":2,"#
            + #""photoPaths":["a/b/1.jpg"],"bytes":10,"createdAt":780000000,"isPending":false}"#
        let receipt = try JSONDecoder().decode(ArchivedReceipt.self, from: Data(old.utf8))
        XCTAssertNil(receipt.lines)
        XCTAssertEqual(receipt.storeName, "EDEKA")
    }

    /// Einkaufsdaten (Migration 030): Adresse und Uhrzeit laut Bon, Beginn laut Liste, Kategorie und Inhalt je Zeile.
    func test_savePrices_storesShoppingData() async throws {
        let repo = InMemoryReceiptsRepository()
        let archive = makeArchive(repo)
        let cal = ReceiptTimes.calendar
        let start = cal.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 17, minute: 42))!
        let origin = ReceiptArchiveOrigin(listId: listId, listTitle: "Liste Edeka", createdBy: UUID(),
                                          creatorName: "Rob", listStart: start)
        let items = [ItemModel(id: "b", name: "Kerrygold Butter", units: 250, measure: "g", category: "Milchprodukte"),
                     ItemModel(id: "s", name: "Schokolade", units: 200, measure: "g")]
        let flow = ReceiptFlowViewModel(listItemNames: items.map(\.name), listItems: items, catalog: nil,
                                        priceBook: PriceBook(repository: InMemoryPricePointsRepository(), defaults: defaults),
                                        archive: archive, origin: origin)
        flow.recognize = { _ in ["EDEKA Center", "Leopoldstr. 82", "24.09.2026 18:05", "KERRYGOLD BUTTER   2,49 A",
                                 "SCHOKOLADE   3,50 A", "2 x 1,75", "SUMME   5,99"] }
        flow.addPage(UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        })
        await flow.process()
        await flow.savePrices()
        await archive.flush()

        let receipt = try XCTUnwrap(repo.receipts.first)
        XCTAssertEqual(receipt.storeAddress, "Leopoldstr. 82")
        XCTAssertEqual(receipt.startedAt, start)
        XCTAssertEqual(receipt.endedAt, cal.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 18, minute: 5)))
        let lines = try XCTUnwrap(receipt.lines)
        XCTAssertEqual(lines.map(\.category), ["Milchprodukte", CategoryDefinition.fallbackName])
        XCTAssertEqual(lines.map(\.quantity), [1, 2])
        XCTAssertEqual(lines.map(\.units), [250, 100])
        XCTAssertEqual(lines.map(\.measure), ["g", "g"])
        XCTAssertEqual(lines.map(\.itemId), ["b", "s"])
    }
}
