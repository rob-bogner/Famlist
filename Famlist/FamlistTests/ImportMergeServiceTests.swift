/*
 ImportMergeServiceTests.swift
 FamlistTests

 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for ImportMergeService.merge().
 - Verifies deduplication, unit summation, measure compatibility,
   and createNew / reactivate / update classification.

 🛠 Includes:
 - Duplicate line merging (same measure, different quantities)
 - Measure compatibility and incompatibility handling
 - Correct classification against allLocalItems
 - Invariant: exactly one ImportTarget per canonical item

 🔰 Notes for Beginners:
 - ImportMergeService is a pure struct → no SwiftData needed for most tests.
 - ParsedItem and ItemModel are created directly to isolate merge logic from parser.

 📝 Last Change:
 - Initial creation (FAM-XX): Bulk-Import Merge Refactor.
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

final class ImportMergeServiceTests: XCTestCase {

    private let testListId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    // MARK: - Helpers

    private func parsedItem(
        _ name: String,
        units: Int = 1,
        measure: String = "",
        category: String? = nil,
        brand: String? = nil,
        productDescription: String? = nil
    ) -> ClipboardImportParser.ParsedItem {
        ClipboardImportParser.ParsedItem(
            name: name,
            units: units,
            measure: measure,
            category: category,
            brand: brand,
            productDescription: productDescription
        )
    }

    private func activeItem(name: String, units: Int = 1, measure: String = "") -> ItemModel {
        let id = UUID.deterministicItemID(listId: testListId, name: name).uuidString
        return ItemModel(
            id: id,
            name: name,
            units: units,
            measure: measure,
            listId: testListId.uuidString
        )
    }

    private func deletedItem(name: String, units: Int = 1) -> ItemModel {
        let id = UUID.deterministicItemID(listId: testListId, name: name).uuidString
        return ItemModel(
            id: id,
            name: name,
            units: units,
            listId: testListId.uuidString,
            deletedAt: Date()  // non-nil → soft-deleted
        )
    }

    private func merge(
        selected: [ClipboardImportParser.ParsedItem],
        localItems: [ItemModel] = []
    ) -> ImportMergeService.MergeResult {
        ImportMergeService.merge(
            selected: selected,
            allLocalItems: localItems,
            listId: testListId
        )
    }

    // MARK: - Duplicate lines

    func test_merge_duplicateLines_sumUnits() {
        let result = merge(selected: [
            parsedItem("Milch", units: 1),
            parsedItem("Milch", units: 1)
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 2)
    }

    func test_merge_duplicateLines_differentQuantities() {
        let result = merge(selected: [
            parsedItem("Milch", units: 1),
            parsedItem("Milch", units: 2)
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 3)
    }

    func test_merge_distinctNames_createsSeparateItems() {
        let result = merge(selected: [
            parsedItem("Milch"),
            parsedItem("Brot")
        ])
        XCTAssertEqual(result.targets.count, 2)
        XCTAssertTrue(result.targets.allSatisfy { if case .createNew = $0 { return true }; return false })
    }

    // MARK: - Name normalisation

    func test_merge_nameNormalization_caseInsensitive() {
        let result = merge(selected: [
            parsedItem("MILCH", units: 1),
            parsedItem("milch", units: 1)
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 2)
    }

    func test_merge_nameNormalization_whitespace() {
        let result = merge(selected: [
            parsedItem(" Milch ", units: 1),
            parsedItem("Milch",   units: 1)
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 2)
    }

    // MARK: - Measure compatibility

    func test_merge_compatibleMeasure_sumsUnits() {
        let result = merge(selected: [
            parsedItem("Milch", units: 200, measure: "ml"),
            parsedItem("Milch", units: 300, measure: "ml")
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 500)
        XCTAssertEqual(item.measure, "ml")
    }

    func test_merge_incompatibleMeasures_firstWins() {
        let result = merge(selected: [
            parsedItem("Zucker", units: 200, measure: "g"),
            parsedItem("Zucker", units: 2,   measure: "piece")
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 200)    // first item only
        XCTAssertEqual(item.measure, "g")
    }

    func test_merge_measureEmptyPlusFilled_usesFilledMeasure() {
        let result = merge(selected: [
            parsedItem("Mehl", units: 1,   measure: ""),
            parsedItem("Mehl", units: 500, measure: "g")
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 501)
        XCTAssertEqual(item.measure, "g")
    }

    // MARK: - Metadata inheritance

    func test_merge_categoryInheritance_firstNonNil() {
        let result = merge(selected: [
            parsedItem("Milch", category: nil),
            parsedItem("Milch", category: "Milchprodukte")
        ])
        XCTAssertEqual(result.targets.count, 1)
        XCTAssertEqual(result.targets[0].item.category, "Milchprodukte")
    }

    // MARK: - Classification: update

    func test_merge_existingActiveItem_producesUpdate() {
        let result = merge(
            selected: [parsedItem("Milch", units: 1)],
            localItems: [activeItem(name: "Milch", units: 1)]
        )
        XCTAssertEqual(result.targets.count, 1)
        guard case .update(let item) = result.targets[0] else {
            return XCTFail("Expected .update")
        }
        XCTAssertEqual(item.units, 2)  // 1 existing + 1 imported
    }

    func test_merge_existingActiveItem_pendingCreate_producesUpdate() {
        var local = activeItem(name: "Milch", units: 1)
        // pendingCreate is active (no deletedAt) → should still produce .update
        local.deletedAt = nil
        let result = merge(selected: [parsedItem("Milch", units: 1)], localItems: [local])
        XCTAssertEqual(result.targets.count, 1)
        guard case .update = result.targets[0] else {
            return XCTFail("Expected .update for active pendingCreate item")
        }
    }

    func test_merge_existingActiveItem_pendingUpdate_producesUpdate() {
        let local = activeItem(name: "Milch", units: 2)
        let result = merge(selected: [parsedItem("Milch", units: 1)], localItems: [local])
        XCTAssertEqual(result.targets.count, 1)
        guard case .update(let item) = result.targets[0] else {
            return XCTFail("Expected .update")
        }
        XCTAssertEqual(item.units, 3)  // 2 existing + 1 imported
    }

    // MARK: - Classification: reactivate

    func test_merge_softDeletedItem_producesReactivate() {
        let result = merge(
            selected: [parsedItem("Milch", units: 2)],
            localItems: [deletedItem(name: "Milch", units: 5)]
        )
        XCTAssertEqual(result.targets.count, 1)
        guard case .reactivate(let item) = result.targets[0] else {
            return XCTFail("Expected .reactivate")
        }
        // units = importedUnits only, NOT existingUnits + importedUnits
        XCTAssertEqual(item.units, 2)
    }

    func test_merge_pendingDeleteItem_producesReactivate() {
        let result = merge(
            selected: [parsedItem("Milch", units: 1)],
            localItems: [deletedItem(name: "Milch", units: 3)]
        )
        XCTAssertEqual(result.targets.count, 1)
        guard case .reactivate = result.targets[0] else {
            return XCTFail("Expected .reactivate for pendingDelete item")
        }
    }

    func test_reactivate_usesImportedUnits_notOldPlusImport() {
        let result = merge(
            selected: [parsedItem("Milch", units: 2)],
            localItems: [deletedItem(name: "Milch", units: 5)]
        )
        guard case .reactivate(let item) = result.targets[0] else {
            return XCTFail("Expected .reactivate")
        }
        XCTAssertEqual(item.units, 2)  // NOT 5 + 2 = 7
    }

    // MARK: - Edge cases

    func test_merge_emptySelection_returnsEmpty() {
        let result = merge(selected: [])
        XCTAssertTrue(result.targets.isEmpty)
    }

    func test_merge_allAlreadyExist_returnsOnlyUpdates() {
        let result = merge(
            selected: [parsedItem("Milch"), parsedItem("Brot")],
            localItems: [activeItem(name: "Milch"), activeItem(name: "Brot")]
        )
        XCTAssertEqual(result.targets.count, 2)
        XCTAssertTrue(result.targets.allSatisfy { if case .update = $0 { return true }; return false })
    }

    func test_merge_noDuplicateTargetsForSameId() {
        let result = merge(selected: [
            parsedItem("Milch", units: 1),
            parsedItem("Milch", units: 1),
            parsedItem("Milch", units: 1)
        ])
        XCTAssertEqual(result.targets.count, 1)
        guard case .createNew(let item) = result.targets[0] else {
            return XCTFail("Expected .createNew")
        }
        XCTAssertEqual(item.units, 3)
    }

    func test_merge_multipleNamesSameDescriptions() {
        let result = merge(selected: [
            parsedItem("Milch", units: 1),
            parsedItem("Brot",  units: 1),
            parsedItem("Milch", units: 2)
        ])
        XCTAssertEqual(result.targets.count, 2)
        let milchTarget = result.targets.first { $0.item.name.lowercased() == "milch" }
        XCTAssertNotNil(milchTarget)
        XCTAssertEqual(milchTarget?.item.units, 3)  // 1 + 2
        let brotTarget = result.targets.first { $0.item.name.lowercased() == "brot" }
        XCTAssertNotNil(brotTarget)
        XCTAssertEqual(brotTarget?.item.units, 1)
    }
}
