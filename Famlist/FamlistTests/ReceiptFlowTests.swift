/*
 ReceiptFlowTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für den Kassenzettel-Ablauf: Zuordnung nach dem Erkennen, Korrigieren (zuordnen, neu, ignorieren),
   „Preise speichern“ inkl. Offline-Warteschlange des PriceBook.

 🔰 Notes for Beginners:
 - Die Texterkennung (Vision) wird durch feste Zeilen ersetzt (`recognize`).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ReceiptFlowTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "ReceiptFlowTests")
        defaults.removePersistentDomain(forName: "ReceiptFlowTests")
    }

    private let bon = ["EDEKA Center", "24.09.2026", "KERRYGOLD BUTTER   2,49 A", "KOKOSM. 400ML   1,39 A",
                       "FAIRGL.VM SCHOKO   3,49 A", "SUMME   7,37"]

    private func makeFlow(_ repo: InMemoryPricePointsRepository) -> ReceiptFlowViewModel {
        let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Kokosmilch"],
                                        catalog: nil, priceBook: PriceBook(repository: repo, defaults: defaults))
        flow.recognize = { _ in self.bon }
        flow.addPage(UIImage())
        return flow
    }

    func test_process_parsesAndMatches() async {
        let flow = makeFlow(InMemoryPricePointsRepository())
        await flow.process()
        XCTAssertEqual(flow.phase, .review)
        XCTAssertEqual(flow.storeName, "EDEKA")
        XCTAssertEqual(flow.lines.map(\.status), [.matched, .matched, .new])
        XCTAssertEqual(flow.total, Decimal(string: "7.37"))
        XCTAssertEqual(flow.savableCount, 2, "Neue Artikel werden nur nach Bestätigung gespeichert")
    }

    func test_corrections_assign_confirmNew_ignore() async {
        let flow = makeFlow(InMemoryPricePointsRepository())
        await flow.process()
        let schoko = flow.lines[2], butter = flow.lines[0]
        flow.confirmNew(schoko.id)
        flow.ignore(butter.id)
        XCTAssertEqual(flow.savableCount, 2)
        flow.assign(butter.id, to: "Kokosmilch")
        XCTAssertEqual(flow.lines[0].itemName, "Kokosmilch")
        XCTAssertFalse(flow.lines[0].ignored)
        XCTAssertEqual(flow.savableCount, 3)
    }

    func test_savePrices_storesPointsWithStoreAndDate() async {
        let repo = InMemoryPricePointsRepository()
        let flow = makeFlow(repo)
        await flow.process()
        await flow.savePrices()
        XCTAssertEqual(flow.phase, .done(saved: 2))
        XCTAssertEqual(repo.stored.map(\.itemName), ["Kerrygold, original irische Butter", "Kokosmilch"])
        XCTAssertTrue(repo.stored.allSatisfy { $0.storeName == "EDEKA" })
        let day = Calendar(identifier: .gregorian).dateComponents([.day, .month], from: repo.stored[0].purchasedAt)
        XCTAssertEqual([day.day, day.month], [24, 9])
    }

    func test_priceBook_offline_keepsQueue_andFlushesLater() async {
        let repo = InMemoryPricePointsRepository()
        repo.failInsert = true
        let book = PriceBook(repository: repo, defaults: defaults)
        let point = PricePoint(itemName: "Butter", storeName: "Lidl", purchasedAt: Date(), price: 2.19)
        await book.save([point])
        XCTAssertEqual(book.pending.count, 1)
        let offlineHistory = await book.history(itemName: "butter")
        XCTAssertEqual(offlineHistory.count, 1, "Warteschlange zählt im Verlauf mit")
        repo.failInsert = false
        await book.flush()
        XCTAssertTrue(book.pending.isEmpty)
        let history = await book.history(itemName: "Butter")
        XCTAssertEqual(history.map(\.id), [point.id], "keine Doppelten")
    }

    func test_shoppingDone_checkedText() {
        XCTAssertEqual(ShoppingDoneView.checkedText(checked: 6, total: 6), "alle 6 Artikel abgehakt")
        XCTAssertEqual(ShoppingDoneView.checkedText(checked: 1, total: 1), "1 Artikel abgehakt")
        XCTAssertEqual(ShoppingDoneView.checkedText(checked: 2, total: 6), "2 von 6 Artikeln abgehakt")
        XCTAssertEqual(ShoppingDoneView.checkedText(checked: 0, total: 0), "0 von 0 Artikeln abgehakt")
        XCTAssertEqual(ShoppingDoneView.checkedText(checked: 0, total: 1), "0 von 1 Artikel abgehakt")
        XCTAssertEqual(ProgressHero.itemWord(total: 1), "Artikel")
        XCTAssertEqual(ProgressHero.itemWord(total: 2), "Artikeln")
    }

    func test_suggestedName_forNewItems() {
        XCTAssertEqual(ReceiptFlowViewModel.suggestedName("KOKOSM. 400ML"), "Kokosm. 400ml")
    }

    // MARK: - Artikelpreise aktualisieren

    private func makePriceFlow(listPrices: [String: Double], bon: [String]) -> ReceiptFlowViewModel {
        let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Kokosmilch"],
                                        listPrices: listPrices, catalog: nil,
                                        priceBook: PriceBook(repository: InMemoryPricePointsRepository(), defaults: defaults))
        flow.apply(ReceiptParser.parse(lines: bon))
        return flow
    }

    func test_priceChanges_onlyDifferingKnownArticles() {
        let flow = makePriceFlow(listPrices: ["Kerrygold, original irische Butter": 2.29, "kokosmilch ": 1.39], bon: bon)
        XCTAssertEqual(flow.priceChanges, [ReceiptPriceChange(name: "Kerrygold, original irische Butter", price: 2.49)],
                       "Kokosmilch hat schon 1,39 €; die Schokolade ist ein neuer Artikel")
    }

    func test_priceChanges_articleWithoutPrice_counts() {
        let flow = makePriceFlow(listPrices: ["Kokosmilch": 0], bon: bon)
        XCTAssertEqual(flow.priceChanges.map(\.name), ["Kokosmilch"])
    }

    func test_priceChanges_ignoredAndConfirmedNewLines_excluded() {
        let flow = makePriceFlow(listPrices: ["Kerrygold, original irische Butter": 1.0, "Kokosmilch": 1.0], bon: bon)
        flow.ignore(flow.lines[0].id)
        flow.confirmNew(flow.lines[2].id)
        XCTAssertEqual(flow.priceChanges.map(\.name), ["Kokosmilch"])
    }

    func test_priceChanges_useUnitPrice() {
        let flow = makePriceFlow(listPrices: ["Kokosmilch": 1.39], bon: ["KOKOSM. 400ML   2,58 A", "2 Stk x 1,29"])
        XCTAssertEqual(flow.priceChanges, [ReceiptPriceChange(name: "Kokosmilch", price: 1.29)])
    }

    func test_savePrices_storesUnitPrice() async {
        let repo = InMemoryPricePointsRepository()
        let flow = ReceiptFlowViewModel(listItemNames: ["Kokosmilch"], catalog: nil,
                                        priceBook: PriceBook(repository: repo, defaults: defaults))
        flow.apply(ReceiptParser.parse(lines: ["KOKOSM. 400ML   2,58 A", "2 Stk x 1,29"]))
        await flow.savePrices()
        XCTAssertEqual(repo.stored.map(\.price), [Decimal(string: "1.29")])
    }

    func test_priceChangeMessage_listsAtMostFive() {
        let changes = (1...7).map { ReceiptPriceChange(name: "Artikel \($0)", price: 1.5) }
        let text = ReceiptFlowViewModel.priceChangeMessage(changes)
        XCTAssertTrue(text.hasPrefix("Bei 7 Artikeln weicht"))
        XCTAssertTrue(text.contains("Artikel 5: 1,50"), "Euro-Format mit geschütztem Leerzeichen")
        XCTAssertFalse(text.contains("Artikel 6:"))
        XCTAssertTrue(text.hasSuffix("und 2 weitere"))
    }
}
