/*
 ListSectionBuilderTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für ListSectionBuilder (Sortieren im Dock) und ListSortSettings (Speichern pro Liste).

 🔰 Notes for Beginners:
 - Reine Funktion: keine SwiftData, kein ViewModel nötig.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ListSectionBuilderTests: XCTestCase {

    private func item(_ name: String, _ category: ItemCategory, checked: Bool = false, age: TimeInterval = 0) -> ItemModel {
        ItemModel(id: name, name: name, isChecked: checked, category: category.rawValue,
                  createdAt: Date(timeIntervalSince1970: 1_000_000 - age))
    }

    private var sample: [ItemModel] {
        [item("Milch", .milch, age: 30), item("Äpfel", .obstGemuese, age: 20),
         item("Butter", .milch, checked: true, age: 10), item("Brot", .backwaren, age: 0)]
    }

    // MARK: - Nach Kategorie

    func test_category_groupsInStoreOrder_andCheckedAtBottom() {
        let sections = ListSectionBuilder.sections(items: sample, settings: .default, filter: .all)
        XCTAssertEqual(sections.map(\.kind), [.category(.obstGemuese), .category(.milch), .category(.backwaren), .checked])
        XCTAssertEqual(sections.last?.items.map(\.name), ["Butter"])
    }

    func test_category_withoutDoneAtBottom_keepsCheckedInGroup() {
        let settings = ListSortSettings(order: .category, doneAtBottom: false)
        let sections = ListSectionBuilder.sections(items: sample, settings: settings, filter: .all)
        XCTAssertFalse(sections.contains { $0.kind == .checked })
        XCTAssertEqual(sections.first { $0.kind == .category(.milch) }?.items.map(\.name), ["Butter", "Milch"])
    }

    // MARK: - Flache Sortierungen

    func test_alphabetical_isFlatAndSorted() {
        let settings = ListSortSettings(order: .alphabetical, doneAtBottom: false)
        let sections = ListSectionBuilder.sections(items: sample, settings: settings, filter: .all)
        XCTAssertEqual(sections.map(\.kind), [.flat])
        XCTAssertEqual(sections[0].items.map(\.name), ["Äpfel", "Brot", "Butter", "Milch"])
    }

    func test_dateAdded_newestFirst_checkedSeparated() {
        let settings = ListSortSettings(order: .dateAdded, doneAtBottom: true)
        let sections = ListSectionBuilder.sections(items: sample, settings: settings, filter: .all)
        XCTAssertEqual(sections.map(\.kind), [.flat, .checked])
        XCTAssertEqual(sections[0].items.map(\.name), ["Brot", "Äpfel", "Milch"])
    }

    func test_manual_usesStoredOrder_unknownItemsAfterwards() {
        let settings = ListSortSettings(order: .manual, doneAtBottom: false)
        let sections = ListSectionBuilder.sections(items: sample, settings: settings, filter: .all,
                                                   manualOrder: ["Milch", "Butter"])
        XCTAssertEqual(sections[0].items.map(\.name), ["Milch", "Butter", "Brot", "Äpfel"])
    }

    // MARK: - Tab-Filter

    func test_openFilter_hidesCheckedSection() {
        let sections = ListSectionBuilder.sections(items: sample, settings: .default, filter: .open)
        XCTAssertFalse(sections.contains { $0.kind == .checked })
        XCTAssertEqual(sections.flatMap(\.items).count, 3)
    }

    func test_doneFilter_showsOnlyChecked() {
        let sections = ListSectionBuilder.sections(items: sample, settings: .default, filter: .done)
        XCTAssertEqual(sections.map(\.kind), [.checked])
    }

    func test_emptyItems_noSections() {
        XCTAssertTrue(ListSectionBuilder.sections(items: [], settings: .default, filter: .all).isEmpty)
    }

    // MARK: - Speichern pro Liste

    func test_sortSettings_persistPerList() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "ListSectionBuilderTests"))
        defaults.removePersistentDomain(forName: "ListSectionBuilderTests")
        let listA = UUID(), listB = UUID()
        ListSortSettings(order: .alphabetical, doneAtBottom: false).save(listId: listA, defaults: defaults)

        XCTAssertEqual(ListSortSettings.load(listId: listA, defaults: defaults),
                       ListSortSettings(order: .alphabetical, doneAtBottom: false))
        XCTAssertEqual(ListSortSettings.load(listId: listB, defaults: defaults), .default)
    }
}
