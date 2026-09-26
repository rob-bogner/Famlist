/*
 ReceiptArchiveViewModelTests.swift
 FamlistTests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für die Anzeige des Kassenzettel-Archivs: Texte wie im Design, Filter nach Laden, Monatsgruppen,
   Löschrecht (Ersteller, Listenbesitzer).

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ReceiptArchiveViewModelTests: XCTestCase {
    private func makeViewModel(me: UUID? = nil, owned: Set<UUID> = []) -> ReceiptArchiveViewModel {
        let archive = ReceiptArchive.preview(defaults: UserDefaults(suiteName: "ReceiptArchiveViewModelTests") ?? .standard)
        return ReceiptArchiveViewModel(archive: archive, currentUserId: me, ownedListIds: owned)
    }

    func test_texts_matchDesign() {
        let vm = makeViewModel()
        let edeka = ArchivedReceipt.designSamples[0]
        XCTAssertEqual(vm.subtitle, "12 Bons · 38 MB · für alle in der Liste sichtbar")
        XCTAssertEqual(ReceiptArchiveViewModel.dateAndList(edeka), "24.09.2026 · Liste Edeka")
        XCTAssertEqual(ReceiptArchiveViewModel.positions(edeka), "5 Positionen")
        XCTAssertEqual(ReceiptArchiveViewModel.euro(edeka.total), "11,51\u{00A0}€")
        XCTAssertEqual(ReceiptArchiveViewModel.detailSubtitle(edeka), "24.09.2026 · Liste Edeka · gescannt von Rob")
        XCTAssertEqual(ReceiptArchiveViewModel.detailCounts(edeka), "5 Positionen · 5 Preise gespeichert")
        XCTAssertEqual(ReceiptArchiveViewModel.accessibilityLabel(edeka),
                       "Edeka, 24.09.2026 · Liste Edeka, 5 Positionen, 11,51\u{00A0}€")
    }

    func test_pendingReceipt_showsUploadHint() {
        var receipt = ArchivedReceipt.designSamples[0]
        receipt.isPending = true
        XCTAssertEqual(ReceiptArchiveViewModel.positions(receipt), "5 Positionen · wird hochgeladen")
    }

    func test_filters_andMonthGroups() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.filters, ["Alle", "Edeka", "Rewe", "Lidl", "dm"])
        XCTAssertEqual(vm.groups.map(\.title), ["September 2026", "August 2026", "Juli 2026", "Juni 2026"])
        XCTAssertEqual(vm.groups.first?.receipts.map(\.storeName), ["Edeka", "Rewe", "Lidl"])

        vm.selectedStore = "Edeka"
        XCTAssertEqual(vm.groups.flatMap(\.receipts).map(\.storeName), ["Edeka", "Edeka", "Edeka", "Edeka"])
        XCTAssertEqual(vm.subtitle, "12 Bons · 38 MB · für alle in der Liste sichtbar", "Unterzeile ungefiltert")
    }

    func test_validateFilter_fallsBackToAll() {
        let vm = makeViewModel()
        vm.selectedStore = "Aldi"
        vm.validateFilter()
        XCTAssertEqual(vm.selectedStore, "Alle")
    }

    func test_canDelete_creatorOrListOwner() {
        let me = UUID()
        var mine = ArchivedReceipt.designSamples[1]
        mine.createdBy = me
        var other = ArchivedReceipt.designSamples[2]
        other.createdBy = UUID()

        XCTAssertTrue(makeViewModel(me: me).canDelete(mine))
        XCTAssertFalse(makeViewModel(me: me).canDelete(other))
        XCTAssertTrue(makeViewModel(me: me, owned: [other.listId]).canDelete(other), "Listenbesitzer")
        XCTAssertFalse(makeViewModel(me: nil).canDelete(other))
    }
}
