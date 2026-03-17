/*
 ListViewModelMembershipEvictionTests.swift
 FamlistTests
 Created by Robert Bogner on 17.03.26.

 ------------------------------------------------------------------------
 📄 File Overview:
 - Regression-Tests für FAM-21 Bug Fix: Zugriffsentzug bei offener geteilter Liste.
 - Testet handleMembershipRemoval() direkt (internal access).
 ------------------------------------------------------------------------
*/

import XCTest
import SwiftData
@testable import Famlist

@MainActor
final class ListViewModelMembershipEvictionTests: XCTestCase {

    // MARK: - Helpers

    private let ownerId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    private func makeList(id: UUID = UUID(), isDefault: Bool) -> ListModel {
        ListModel(
            id: id,
            ownerId: ownerId,
            title: "List-\(id.uuidString.prefix(4))",
            isDefault: isDefault,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeViewModel(activeListId: UUID) -> ListViewModel {
        let container = PersistenceController.preview.container
        let itemStore = SwiftDataItemStore(context: container.mainContext)
        let listStore = SwiftDataListStore(context: container.mainContext)
        let vm = ListViewModel(
            listId: activeListId,
            repository: PreviewItemsRepository(),
            itemStore: itemStore,
            listStore: listStore,
            startImmediately: false
        )
        vm.configure(listsRepository: PreviewListsRepository())
        return vm
    }

    // MARK: - Tests

    func test_membershipRemoval_nonActiveList_doesNotSwitch() async throws {
        let list1 = makeList(isDefault: true)
        let list2 = makeList(isDefault: false)

        let vm = makeViewModel(activeListId: list1.id)
        vm.allLists = [list1, list2]

        vm.handleMembershipRemoval(listId: list2.id)

        XCTAssertEqual(vm.listId, list1.id, "Active list must not change")
        XCTAssertFalse(vm.allLists.contains(where: { $0.id == list2.id }),
                       "Removed list must be gone from allLists")
        XCTAssertEqual(vm.allLists.count, 1)
    }

    func test_membershipRemoval_activeList_switchesToDefault() async throws {
        let defaultList = makeList(isDefault: true)
        let sharedList  = makeList(isDefault: false)

        let vm = makeViewModel(activeListId: sharedList.id)
        vm.allLists = [defaultList, sharedList]
        vm.defaultList = sharedList

        vm.handleMembershipRemoval(listId: sharedList.id)

        XCTAssertEqual(vm.listId, defaultList.id, "Should switch to default list")
        XCTAssertEqual(vm.defaultList?.id, defaultList.id)
        XCTAssertFalse(vm.allLists.contains(where: { $0.id == sharedList.id }),
                       "Removed list must be gone from allLists")
    }

    func test_membershipRemoval_activeList_noFallback_clearsState() async throws {
        let sharedList = makeList(isDefault: false)

        let vm = makeViewModel(activeListId: sharedList.id)
        vm.allLists = [sharedList]
        vm.defaultList = sharedList
        vm.items = [ItemModel(id: UUID().uuidString, name: "Test")]

        vm.handleMembershipRemoval(listId: sharedList.id)

        XCTAssertTrue(vm.items.isEmpty, "Items must be cleared")
        XCTAssertNil(vm.defaultList, "defaultList must be nil")
        XCTAssertNil(vm.observeTask, "observeTask must be cancelled")
    }

    func test_membershipRemoval_activeList_prefersDefaultOverFirst() async throws {
        let firstList   = makeList(isDefault: false)
        let sharedList  = makeList(isDefault: false)
        let defaultList = makeList(isDefault: true)

        let vm = makeViewModel(activeListId: sharedList.id)
        vm.allLists = [firstList, sharedList, defaultList]
        vm.defaultList = sharedList

        vm.handleMembershipRemoval(listId: sharedList.id)

        XCTAssertEqual(vm.listId, defaultList.id,
                       "Should prefer the list marked isDefault over allLists.first")
    }

    // MARK: - RC-5 Regression: startObservingMemberships startet nur nach configure(listsRepository:)

    func test_startObservingMemberships_withoutConfigure_doesNotStartTask() {
        // listsRepository is nil before configure() → guard exits → membershipTask stays nil
        let vm = makeViewModel(activeListId: UUID())
        vm.startObservingMemberships(userId: ownerId)
        XCTAssertNil(vm.membershipTask, "membershipTask must remain nil when listsRepository is nil")
    }

    func test_startObservingMemberships_afterConfigure_startsTask() {
        let vm = makeViewModel(activeListId: UUID())
        vm.configure(listsRepository: PreviewListsRepository())
        vm.startObservingMemberships(userId: ownerId)
        XCTAssertNotNil(vm.membershipTask, "membershipTask must be set after configure + startObservingMemberships")
    }
}
