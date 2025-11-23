/*
 ListViewModelBulkTogglePerformanceTests.swift
 Created: 22.11.2025 | Updated: 22.11.2025
 
 Purpose: Performance tests for optimized bulk toggle functionality
 
 CHANGELOG:
 - 22.11.2025: Performance tests for toggleAllItems() with various list sizes
*/

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ListViewModelBulkTogglePerformanceTests: XCTestCase {
    
    var viewModel: ListViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup in-memory SwiftData container for testing
        let schema = Schema([ItemEntity.self, ListEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        
        // Create view model with preview repository
        let itemStore = SwiftDataItemStore(context: modelContext)
        let listStore = SwiftDataListStore(context: modelContext)
        let defaultListId = UUID()
        
        viewModel = ListViewModel(
            listId: defaultListId,
            repository: PreviewItemsRepository(),
            itemStore: itemStore,
            listStore: listStore
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates test items with specified count
    private func createTestItems(count: Int) {
        viewModel.items = (1...count).map { index in
            ItemModel(
                id: UUID().uuidString,
                listId: viewModel.listId.uuidString,
                name: "Test Item \(index)",
                quantity: 1.0,
                measure: "Stk",
                category: "Test",
                isChecked: false,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
    }
    
    // MARK: - Performance Tests
    
    /// Tests performance with 50 items (target: <100ms)
    func testToggleAll50Items() async throws {
        // Given
        createTestItems(count: 50)
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.toggleAllItems()
        
        // Wait for debounce and completion
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to ms
        
        // Then
        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All items should be checked")
        XCTAssertLessThan(timeElapsed, 200, "Toggle 50 items should complete in <200ms, took \(timeElapsed)ms")
        
        print("✅ 50 items toggled in \(String(format: "%.2f", timeElapsed))ms")
    }
    
    /// Tests performance with 100 items (target: <250ms)
    func testToggleAll100Items() async throws {
        // Given
        createTestItems(count: 100)
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.toggleAllItems()
        
        // Wait for debounce and completion
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Then
        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All items should be checked")
        XCTAssertLessThan(timeElapsed, 400, "Toggle 100 items should complete in <400ms, took \(timeElapsed)ms")
        
        print("✅ 100 items toggled in \(String(format: "%.2f", timeElapsed))ms")
    }
    
    /// Tests performance with 200 items (target: <600ms)
    func testToggleAll200Items() async throws {
        // Given
        createTestItems(count: 200)
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        viewModel.toggleAllItems()
        
        // Wait for debounce and completion
        try await Task.sleep(nanoseconds: 700_000_000) // 700ms
        
        let timeElapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        // Then
        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All items should be checked")
        XCTAssertLessThan(timeElapsed, 900, "Toggle 200 items should complete in <900ms, took \(timeElapsed)ms")
        
        print("✅ 200 items toggled in \(String(format: "%.2f", timeElapsed))ms")
    }
    
    /// Tests debouncing: rapid calls should cancel previous ones
    func testDebouncingPreventsMultipleCalls() async throws {
        // Given
        createTestItems(count: 20)
        
        // When - trigger multiple rapid calls
        viewModel.toggleAllItems()
        viewModel.toggleAllItems()
        viewModel.toggleAllItems()
        
        // Wait for debounce
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        
        // Then - should have executed only once (all checked)
        let checkedCount = viewModel.items.filter { $0.isChecked }.count
        XCTAssertEqual(checkedCount, 20, "All items should be checked after debounced calls")
        
        print("✅ Debouncing works correctly - 3 rapid calls resulted in 1 execution")
    }
    
    /// Tests toggle back and forth
    func testToggleAllBackAndForth() async throws {
        // Given
        createTestItems(count: 30)
        
        // When - toggle to checked
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All items should be checked")
        
        // When - toggle back to unchecked
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        XCTAssertTrue(viewModel.items.allSatisfy { !$0.isChecked }, "All items should be unchecked")
        
        print("✅ Toggle back and forth works correctly")
    }
    
    /// Tests that only items with different state are updated
    func testOnlyDifferentItemsAreUpdated() async throws {
        // Given
        createTestItems(count: 50)
        
        // Check half the items manually
        for i in 0..<25 {
            viewModel.items[i].isChecked = true
        }
        
        let initialState = viewModel.items.map { $0.isChecked }
        
        // When - toggle all (should check all)
        viewModel.toggleAllItems()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        XCTAssertTrue(viewModel.items.allSatisfy { $0.isChecked }, "All items should be checked")
        
        // Verify that the previously checked items remained stable
        let updatedCount = zip(initialState, viewModel.items.map { $0.isChecked })
            .filter { $0.0 != $0.1 }
            .count
        
        XCTAssertEqual(updatedCount, 25, "Only the 25 unchecked items should have been updated")
        
        print("✅ Selective update works - only \(updatedCount) items were updated")
    }
}

