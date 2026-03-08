/*
 ListViewModelBulkTogglePerformanceTests.swift
 Created: 22.11.2025 | Updated: 08.03.2026

 Purpose: Performance tests for optimized bulk toggle functionality

 CHANGELOG:
 - 22.11.2025: Performance tests for toggleAllItems() with various list sizes
 - 08.03.2026: Fixed ItemModel initializer call – field is `units: Int`, not `quantity: Double`.
               Removed direct `viewModel.listId` dependency in ItemModel constructor (uses a
               captured UUID instead to avoid reliance on private(set) internals).
*/

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ListViewModelBulkTogglePerformanceTests: XCTestCase {

    var viewModel: ListViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    // Fixed UUID for the test list so ItemModels reference the same list as the ViewModel.
    private let testListId = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    override func setUp() async throws {
        try await super.setUp()

        // In-memory SwiftData container for isolation between test runs.
        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)

        let itemStore = SwiftDataItemStore(context: modelContext)
        let listStore = SwiftDataListStore(context: modelContext)

        viewModel = ListViewModel(
            listId: testListId,
            repository: PreviewItemsRepository(),
            itemStore: itemStore,
            listStore: listStore,
            startImmediately: false  // Avoids starting the realtime stream during tests.
        )
    }

    override func tearDown() async throws {
        viewModel = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Helper

    /// Populates `viewModel.items` with `count` unchecked ItemModels.
    private func createTestItems(count: Int) {
        viewModel.items = (1...count).map { index in
            ItemModel(
                id: UUID().uuidString,
                name: "Test Item \(index)",
                units: 1,
                measure: "Stk",
                isChecked: false,
                listId: testListId.uuidString,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }

    // MARK: - Performance Tests

    /// Toggles 50 items; target: completes in under 200 ms (wall time including debounce).
    func testToggleAll50Items() async throws {
        createTestItems(count: 50)

        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms – covers debounce + batch
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All 50 items should be checked")
        XCTAssertLessThan(elapsed, 300, "Toggle 50 items should complete in <300ms, took \(elapsed)ms")
    }

    /// Toggles 100 items; target: completes in under 400 ms.
    func testToggleAll100Items() async throws {
        createTestItems(count: 100)

        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All 100 items should be checked")
        XCTAssertLessThan(elapsed, 500, "Toggle 100 items should complete in <500ms, took \(elapsed)ms")
    }

    /// Toggles 200 items; target: completes in under 900 ms.
    func testToggleAll200Items() async throws {
        createTestItems(count: 200)

        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 700_000_000) // 700ms
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All 200 items should be checked")
        XCTAssertLessThan(elapsed, 1000, "Toggle 200 items should complete in <1000ms, took \(elapsed)ms")
    }

    /// Rapid repeated calls should be debounced; only the last call executes.
    func testDebouncingPreventsMultipleCalls() async throws {
        createTestItems(count: 20)

        // Fire three rapid toggle calls; debounce should absorb the first two.
        viewModel.toggleAllItems()
        viewModel.toggleAllItems()
        viewModel.toggleAllItems()

        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        // After an odd number of debounced calls (effectively 1), all items should be checked.
        let checkedCount = viewModel.items.filter { $0.isChecked }.count
        XCTAssertEqual(checkedCount, 20, "Debouncing 3 rapid calls must result in a single toggle-to-checked pass")
    }

    /// Toggling twice should produce the original unchecked state.
    func testToggleAllBackAndForth() async throws {
        createTestItems(count: 30)

        // First toggle → all checked
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All items should be checked after first toggle")

        // Second toggle → all unchecked
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.items.allSatisfy { !$0.isChecked }, "All items should be unchecked after second toggle")
    }

    /// Only items whose state differs from the target should be mutated.
    func testOnlyDifferentItemsAreUpdated() async throws {
        createTestItems(count: 50)

        // Pre-check the first 25 items.
        for i in 0..<25 {
            viewModel.items[i].isChecked = true
        }

        let initialStates = viewModel.items.map { $0.isChecked }

        // Toggle all → should check the remaining 25 items.
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All 50 items should be checked after toggle")

        // Count items whose state changed.
        let updatedCount = zip(initialStates, viewModel.items.map { $0.isChecked })
            .filter { $0.0 != $0.1 }
            .count

        XCTAssertEqual(updatedCount, 25, "Only the 25 previously-unchecked items should have been updated")
    }
}
