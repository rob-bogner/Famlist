/*
 MultiDeviceSyncIntegrationTests.swift
 FamlistTests
 Created on: 22.11.2025
 Last updated on: 22.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Integration tests simulating multi-device sync scenarios.
 
 🛠 Includes:
 - Concurrent modification tests
 - Conflict resolution validation
 - Operation queue behavior
 
 🔰 Notes for Beginners:
 - These tests simulate two devices modifying the same item
 - Validates that CRDT resolves conflicts consistently
 
 📝 Last Change:
 - Initial integration test suite for multi-device sync
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class MultiDeviceSyncIntegrationTests: XCTestCase {
    
    func testConcurrentModifications_shouldResolveConsistently() async {
        // Simulate two devices modifying the same item
        let resolver = ConflictResolver()
        
        // Device 1 modifies at T+100ms
        let device1HLC = HybridLogicalClock(timestamp: 1100, counter: 0, nodeId: "device1")
        let device1Item = ItemModel(id: "item1", name: "Device1", units: 2)
        let device1Meta = CRDTMetadata(hlc: device1HLC, tombstone: false, lastModifiedBy: "device1")
        
        // Device 2 modifies at T+200ms
        let device2HLC = HybridLogicalClock(timestamp: 1200, counter: 0, nodeId: "device2")
        let device2Item = ItemModel(id: "item1", name: "Device2", units: 3)
        let device2Meta = CRDTMetadata(hlc: device2HLC, tombstone: false, lastModifiedBy: "device2")
        
        // Device 1 receives Device 2's update
        let (resolved1, _) = resolver.resolve(
            local: device1Item,
            remote: device2Item,
            localMeta: device1Meta,
            remoteMeta: device2Meta
        )
        
        // Device 2 receives Device 1's update
        let (resolved2, _) = resolver.resolve(
            local: device2Item,
            remote: device1Item,
            localMeta: device2Meta,
            remoteMeta: device1Meta
        )
        
        // Both devices should converge to same state (Device 2 wins)
        XCTAssertEqual(resolved1.name, "Device2")
        XCTAssertEqual(resolved2.name, "Device2")
        XCTAssertEqual(resolved1.units, 3)
        XCTAssertEqual(resolved2.units, 3)
    }
    
    func testDeletionDuringModification_tombstoneWins() async {
        let resolver = ConflictResolver()
        
        // Device 1 modifies item
        let device1HLC = HybridLogicalClock(timestamp: 1100, counter: 0, nodeId: "device1")
        let device1Item = ItemModel(id: "item1", name: "Modified")
        let device1Meta = CRDTMetadata(hlc: device1HLC, tombstone: false, lastModifiedBy: "device1")
        
        // Device 2 deletes item (earlier timestamp but tombstone)
        let device2HLC = HybridLogicalClock(timestamp: 1000, counter: 0, nodeId: "device2")
        let device2Item = ItemModel(id: "item1", name: "Deleted")
        let device2Meta = CRDTMetadata(hlc: device2HLC, tombstone: true, lastModifiedBy: "device2")
        
        let (_, resolvedMeta) = resolver.resolve(
            local: device1Item,
            remote: device2Item,
            localMeta: device1Meta,
            remoteMeta: device2Meta
        )
        
        // Tombstone should win despite older timestamp
        XCTAssertTrue(resolvedMeta.tombstone)
    }
    
    func testHLCClockSkew_shouldMaintainCausality() async {
        // Simulate device with clock 5 minutes ahead
        let generator1 = HybridLogicalClockGenerator(nodeId: "device1")
        let generator2 = HybridLogicalClockGenerator(nodeId: "device2")
        
        // Device 1 creates event
        let clock1 = generator1.tick()
        
        // Device 2 receives and creates new event (even if physical clock is behind)
        let clock2 = generator2.receive(clock1)
        let clock3 = generator2.tick()
        
        // Causal ordering should be maintained
        XCTAssertTrue(clock1 < clock2)
        XCTAssertTrue(clock2 < clock3 || clock2 == clock3)
    }
    
    func testRapidConcurrentUpdates_shouldConverge() async {
        let resolver = ConflictResolver()
        
        var items: [ItemModel] = []
        var metas: [CRDTMetadata] = []
        
        // Simulate 5 devices making rapid updates
        for i in 0..<5 {
            let hlc = HybridLogicalClock(
                timestamp: 1000 + Int64(i * 100),
                counter: i,
                nodeId: "device\(i)"
            )
            let item = ItemModel(id: "item1", name: "Device\(i)", units: i)
            let meta = CRDTMetadata(hlc: hlc, tombstone: false, lastModifiedBy: "device\(i)")
            
            items.append(item)
            metas.append(meta)
        }
        
        // Each device resolves against all others
        var finalStates: [ItemModel] = []
        
        for deviceIndex in 0..<5 {
            var currentItem = items[deviceIndex]
            var currentMeta = metas[deviceIndex]
            
            for otherIndex in 0..<5 where otherIndex != deviceIndex {
                let (resolved, resolvedMeta) = resolver.resolve(
                    local: currentItem,
                    remote: items[otherIndex],
                    localMeta: currentMeta,
                    remoteMeta: metas[otherIndex]
                )
                currentItem = resolved
                currentMeta = resolvedMeta
            }
            
            finalStates.append(currentItem)
        }
        
        // All devices should converge to the same state
        let firstFinal = finalStates[0]
        for finalState in finalStates {
            XCTAssertEqual(finalState.name, firstFinal.name)
            XCTAssertEqual(finalState.units, firstFinal.units)
        }
    }

    // MARK: - RC-1 Regression: Bool-Parsing für Realtime-Events (extractBool AnyJSON-Fallback)

    // setUp/tearDown lifecycle keeps processor + itemStore alive for the duration of each test,
    // using ModelContext(container) instead of container.mainContext to avoid Swift 6
    // actor-isolation precondition failures in the async XCTest runner.
    private var _container: ModelContainer!
    private var _itemStore: SwiftDataItemStore!
    private var _processor: RealtimeEventProcessor!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([ListEntity.self, ItemEntity.self, SyncOperation.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        _container = try ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(_container)
        _itemStore = SwiftDataItemStore(context: ctx)
        _processor = RealtimeEventProcessor(conflictResolver: ConflictResolver(), itemStore: _itemStore)
    }

    override func tearDown() async throws {
        _processor = nil
        _itemStore = nil
        _container = nil
        try await super.tearDown()
    }

    private func insertionPayload(id: String, isChecked: Any, price: Any = Double(0)) -> [String: Any] {
        [
            "record": [
                "id": id,
                "name": "Test",
                "isChecked": isChecked,
                "price": price,
                "hlc_timestamp": Int64(1000),
                "hlc_counter": 0,
                "hlc_node_id": "node1",
                "tombstone": false,
                "last_modified_by": ""
            ] as [String: Any]
        ]
    }

    func test_boolParsing_nativeTrue_parsedAsTrue() async {
        let itemId = UUID().uuidString
        await _processor.processInsertion(insertionPayload(id: itemId, isChecked: true), listId: UUID())
        guard let entity = try? _itemStore.fetchItem(id: UUID(uuidString: itemId)!) else {
            return XCTFail("Item not inserted")
        }
        XCTAssertTrue(entity.isChecked, "Native Bool true must be parsed as true")
    }

    func test_boolParsing_nativeFalse_parsedAsFalse() async {
        let itemId = UUID().uuidString
        await _processor.processInsertion(insertionPayload(id: itemId, isChecked: false), listId: UUID())
        guard let entity = try? _itemStore.fetchItem(id: UUID(uuidString: itemId)!) else {
            return XCTFail("Item not inserted")
        }
        XCTAssertFalse(entity.isChecked, "Native Bool false must be parsed as false")
    }

    func test_boolParsing_stringTrue_parsedAsTrue() async {
        let itemId = UUID().uuidString
        await _processor.processInsertion(insertionPayload(id: itemId, isChecked: "true"), listId: UUID())
        guard let entity = try? _itemStore.fetchItem(id: UUID(uuidString: itemId)!) else {
            return XCTFail("Item not inserted")
        }
        XCTAssertTrue(entity.isChecked, "String 'true' must be parsed as true via AnyJSON fallback")
    }

    func test_boolParsing_stringFalse_parsedAsFalse() async {
        let itemId = UUID().uuidString
        await _processor.processInsertion(insertionPayload(id: itemId, isChecked: "false"), listId: UUID())
        guard let entity = try? _itemStore.fetchItem(id: UUID(uuidString: itemId)!) else {
            return XCTFail("Item not inserted")
        }
        XCTAssertFalse(entity.isChecked, "String 'false' must be parsed as false via AnyJSON fallback")
    }

    // MARK: - Price Bug Regression: Double-Parsing für Realtime-Events (extractDouble AnyJSON-Fallback)

    func test_priceParsing_nativeDouble_parsedCorrectly() async {
        let itemId = UUID().uuidString
        await _processor.processInsertion(insertionPayload(id: itemId, isChecked: false, price: 3.99), listId: UUID())
        guard let entity = try? _itemStore.fetchItem(id: UUID(uuidString: itemId)!) else {
            return XCTFail("Item not inserted")
        }
        XCTAssertEqual(entity.price, 3.99, accuracy: 0.001, "Native Double 3.99 must be parsed correctly")
    }

    func test_priceParsing_stringRepresentation_parsedCorrectly() async {
        let itemId = UUID().uuidString
        // "2.49" simulates AnyJSON string fallback path (String(describing: AnyJSON.number(2.49)))
        await _processor.processInsertion(insertionPayload(id: itemId, isChecked: false, price: "2.49"), listId: UUID())
        guard let entity = try? _itemStore.fetchItem(id: UUID(uuidString: itemId)!) else {
            return XCTFail("Item not inserted")
        }
        XCTAssertEqual(entity.price, 2.49, accuracy: 0.001, "String '2.49' must be parsed as Double via AnyJSON fallback")
    }

    // MARK: - Local Edit Path: Preis nach Edit sofort sichtbar (refreshItemsFromStore-Mechanismus)

    func test_price_localEdit_immediatelyVisibleViaRefresh() {
        // This test validates the mechanism that the fix relies on:
        // storeLocally() writes to SwiftData; refreshItemsFromStore() propagates it to self.items.
        // ListViewModel.updateItem() now calls refreshItemsFromStore() after syncEngine.updateItem().
        let schema = Schema([ListEntity.self, ItemEntity.self, SyncOperation.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let itemStore = SwiftDataItemStore(context: container.mainContext)
        let listId = UUID()
        let itemId = UUID().uuidString
        let vm = ListViewModel(
            listId: listId,
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: container.mainContext),
            listStore: SwiftDataListStore(context: container.mainContext),
            startImmediately: false
        )

        // Seed: item at old price
        let original = ItemModel(id: itemId, name: "Milch", price: 0.0, listId: listId.uuidString)
        _ = try? itemStore.upsert(model: original)
        try? itemStore.save()
        vm.refreshItemsFromStore()
        XCTAssertEqual(vm.items.first?.price ?? -1, 0.0, accuracy: 0.001,
                       "Precondition: item at original price 0.0")

        // Act: simulate storeLocally writing updated price to SwiftData
        let updated = ItemModel(id: itemId, name: "Milch", price: 3.99, listId: listId.uuidString)
        _ = try? itemStore.upsert(model: updated)
        try? itemStore.save()

        // refreshItemsFromStore() is what the fix adds to updateItem()'s Task
        vm.refreshItemsFromStore()

        XCTAssertEqual(vm.items.first?.price ?? -1, 3.99, accuracy: 0.001,
                       "Price must be visible immediately after refreshItemsFromStore()")
    }

    func test_priceParsing_missingPrice_defaultsToZero() async {
        let itemId = UUID().uuidString
        // Payload without price key — ensure no crash and defaults to 0.0
        let payload: [String: Any] = [
            "record": [
                "id": itemId, "name": "Test", "isChecked": false,
                "hlc_timestamp": Int64(1000), "hlc_counter": 0,
                "hlc_node_id": "node1", "tombstone": false, "last_modified_by": ""
            ] as [String: Any]
        ]
        await _processor.processInsertion(payload, listId: UUID())
        guard let entity = try? _itemStore.fetchItem(id: UUID(uuidString: itemId)!) else {
            return XCTFail("Item not inserted")
        }
        XCTAssertEqual(entity.price, 0.0, accuracy: 0.001, "Missing price must default to 0.0")
    }
}

