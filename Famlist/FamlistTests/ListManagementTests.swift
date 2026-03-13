/*
 ListManagementTests.swift
 FamlistTests

 Famlist
 Created on: 13.03.2026
 Last updated on: 13.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit tests for FAM-34 (Listen-Übersicht) and FAM-35 (Listen-Management).
 - Tests ListViewModel+ListManagement.swift logic in isolation.

 🛠 Includes:
 - MockListsRepository: records calls, supports shouldThrow
 - loadAllLists: fetches + populates allLists / listItemCounts
 - createNewList: appends, empty title guard
 - renameList: optimistic update + rollback on remote failure
 - deleteList: removes list, last-list guard, switches active list
 - setDefaultList: clears previous default, optimistic + rollback
 - switchToList: updates defaultList and listId

 🔰 Notes for Beginners:
 - @MainActor ensures all @Published mutations run on the UI thread.
 - PersistenceController.preview provides an isolated in-memory SwiftData container.

 📝 Last Change:
 - Initial creation for FAM-34 & FAM-35 QA.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

// MARK: - Mock

@MainActor
final class MockListsRepository: ListsRepository {

    // MARK: Call tracking
    private(set) var fetchAllListsCalled = false
    private(set) var createListCalled = false
    private(set) var renameListCalled = false
    private(set) var deleteListCalled = false
    private(set) var setDefaultListCalled = false

    // MARK: Stubs
    var stubbedLists: [ListModel] = []
    var shouldThrowOnCreate = false
    var shouldThrowOnRename = false
    var shouldThrowOnDelete = false
    var shouldThrowOnSetDefault = false

    // MARK: - ListsRepository

    func ensureDefaultListExists(for owner: UUID) async throws -> List {
        List(id: owner, owner_id: owner, title: "Default", is_default: true, created_at: nil, updated_at: nil)
    }

    func observeLists(for owner: UUID) -> AsyncStream<[List]> {
        AsyncStream { $0.finish() }
    }

    func createList(for owner: UUID, title: String) async throws -> List {
        createListCalled = true
        if shouldThrowOnCreate { throw NSError(domain: "Mock", code: 500) }
        return List(id: UUID(), owner_id: owner, title: title, is_default: false, created_at: nil, updated_at: nil)
    }

    func addMember(listId: UUID, profileId: UUID) async throws {}
    func removeMember(listId: UUID, profileId: UUID) async throws {}

    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel {
        stubbedLists.first(where: { $0.isDefault }) ?? ListModel(
            id: ownerId, ownerId: ownerId, title: "Default",
            isDefault: true, createdAt: Date(), updatedAt: Date()
        )
    }

    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel] {
        fetchAllListsCalled = true
        return stubbedLists
    }

    func renameList(listId: UUID, title: String) async throws -> ListModel {
        renameListCalled = true
        if shouldThrowOnRename { throw NSError(domain: "Mock", code: 500) }
        guard let existing = stubbedLists.first(where: { $0.id == listId }) else {
            throw NSError(domain: "Mock", code: 404)
        }
        return ListModel(id: existing.id, ownerId: existing.ownerId, title: title,
                         isDefault: existing.isDefault, createdAt: existing.createdAt, updatedAt: Date())
    }

    func deleteList(listId: UUID) async throws {
        deleteListCalled = true
        if shouldThrowOnDelete { throw NSError(domain: "Mock", code: 500) }
    }

    func setDefaultList(listId: UUID, ownerId: UUID) async throws {
        setDefaultListCalled = true
        if shouldThrowOnSetDefault { throw NSError(domain: "Mock", code: 500) }
    }
}

// MARK: - Helpers

@MainActor
private func makeViewModel(repo: MockListsRepository) -> ListViewModel {
    let container = PersistenceController.preview.container
    let itemStore = SwiftDataItemStore(context: container.mainContext)
    let listStore = SwiftDataListStore(context: container.mainContext)
    let listId = UUID()
    let vm = ListViewModel(
        listId: listId,
        repository: PreviewItemsRepository(),
        itemStore: itemStore,
        listStore: listStore,
        startImmediately: false
    )
    vm.configure(listsRepository: repo)
    return vm
}

private func makeListModel(id: UUID = UUID(), ownerId: UUID = UUID(),
                           title: String = "Test Liste", isDefault: Bool = false) -> ListModel {
    ListModel(id: id, ownerId: ownerId, title: title,
              isDefault: isDefault, createdAt: Date(), updatedAt: Date())
}

// MARK: - loadAllLists

@MainActor
final class LoadAllListsTests: XCTestCase {

    func test_loadAllLists_populatesAllLists() async throws {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        repo.stubbedLists = [
            makeListModel(ownerId: ownerId, title: "Liste A"),
            makeListModel(ownerId: ownerId, title: "Liste B")
        ]
        let vm = makeViewModel(repo: repo)

        // Act
        vm.loadAllLists(ownerId: ownerId)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertEqual(vm.allLists.count, 2)
        XCTAssertTrue(repo.fetchAllListsCalled)
    }

    func test_loadAllLists_populatesItemCounts() async throws {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        let listId = UUID()
        repo.stubbedLists = [makeListModel(id: listId, ownerId: ownerId, title: "Liste")]
        let vm = makeViewModel(repo: repo)

        // Act
        vm.loadAllLists(ownerId: ownerId)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertNotNil(vm.listItemCounts[listId])
    }

    func test_loadAllLists_withEmptyResult_setsEmptyAllLists() async throws {
        // Arrange
        let repo = MockListsRepository()
        repo.stubbedLists = []
        let vm = makeViewModel(repo: repo)

        // Act
        vm.loadAllLists(ownerId: UUID())
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertTrue(vm.allLists.isEmpty)
    }

    func test_loadAllLists_withoutRepository_doesNothing() {
        // Arrange
        let container = PersistenceController.preview.container
        let vm = ListViewModel(
            listId: UUID(),
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: container.mainContext),
            listStore: SwiftDataListStore(context: container.mainContext),
            startImmediately: false
        )
        // no listsRepository configured

        // Act + Assert (no crash)
        vm.loadAllLists(ownerId: UUID())
        XCTAssertTrue(vm.allLists.isEmpty)
    }
}

// MARK: - createNewList

@MainActor
final class CreateNewListTests: XCTestCase {

    func test_createNewList_appendsToAllLists() async throws {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        let vm = makeViewModel(repo: repo)
        vm.defaultList = makeListModel(ownerId: ownerId, isDefault: true)

        // Act
        vm.createNewList(title: "Neue Liste", ownerId: ownerId)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertEqual(vm.allLists.count, 1)
        XCTAssertEqual(vm.allLists.first?.title, "Neue Liste")
        XCTAssertTrue(repo.createListCalled)
    }

    func test_createNewList_initializesItemCountToZero() async throws {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        let vm = makeViewModel(repo: repo)
        vm.defaultList = makeListModel(ownerId: ownerId, isDefault: true)

        // Act
        vm.createNewList(title: "Leere Liste", ownerId: ownerId)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        let newId = vm.allLists.first?.id
        XCTAssertNotNil(newId)
        XCTAssertEqual(vm.listItemCounts[newId!], 0)
    }

    func test_createNewList_withEmptyTitle_doesNotCreate() async throws {
        // Arrange
        let repo = MockListsRepository()
        let vm = makeViewModel(repo: repo)

        // Act
        vm.createNewList(title: "   ", ownerId: UUID())
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertFalse(repo.createListCalled)
        XCTAssertTrue(vm.allLists.isEmpty)
    }

    func test_createNewList_onRemoteError_setsErrorMessage() async throws {
        // Arrange
        let repo = MockListsRepository()
        repo.shouldThrowOnCreate = true
        let ownerId = UUID()
        let vm = makeViewModel(repo: repo)
        vm.defaultList = makeListModel(ownerId: ownerId, isDefault: true)

        // Act
        vm.createNewList(title: "Fehler Liste", ownerId: ownerId)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.allLists.isEmpty)
    }
}

// MARK: - renameList

@MainActor
final class RenameListTests: XCTestCase {

    func test_renameList_optimisticallyUpdatesTitle() async throws {
        // Arrange
        let repo = MockListsRepository()
        let listId = UUID()
        let ownerId = UUID()
        let list = makeListModel(id: listId, ownerId: ownerId, title: "Alter Name")
        repo.stubbedLists = [list]
        let vm = makeViewModel(repo: repo)
        vm.allLists = [list]

        // Act
        vm.renameList(list, to: "Neuer Name")

        // Assert immediately (optimistic)
        XCTAssertEqual(vm.allLists.first?.title, "Neuer Name")
    }

    func test_renameList_onRemoteError_rollsBackTitle() async throws {
        // Arrange
        let repo = MockListsRepository()
        repo.shouldThrowOnRename = true
        let listId = UUID()
        let ownerId = UUID()
        let list = makeListModel(id: listId, ownerId: ownerId, title: "Original")
        vm_helper: do {
            let vm = makeViewModel(repo: repo)
            vm.allLists = [list]

            // Act
            vm.renameList(list, to: "Fehlgeschlagen")
            XCTAssertEqual(vm.allLists.first?.title, "Fehlgeschlagen") // optimistic

            try await Task.sleep(nanoseconds: 100_000_000)

            // Assert rollback
            XCTAssertEqual(vm.allLists.first?.title, "Original")
            XCTAssertNotNil(vm.errorMessage)
        }
    }

    func test_renameList_withEmptyTitle_doesNotRename() async throws {
        // Arrange
        let repo = MockListsRepository()
        let list = makeListModel(title: "Beibehalt")
        let vm = makeViewModel(repo: repo)
        vm.allLists = [list]

        // Act
        vm.renameList(list, to: "   ")
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertFalse(repo.renameListCalled)
        XCTAssertEqual(vm.allLists.first?.title, "Beibehalt")
    }

    func test_renameList_updatesDefaultListIfActive() async throws {
        // Arrange
        let repo = MockListsRepository()
        let listId = UUID()
        let ownerId = UUID()
        let list = makeListModel(id: listId, ownerId: ownerId, title: "Standard", isDefault: true)
        repo.stubbedLists = [list]
        let vm = makeViewModel(repo: repo)
        vm.allLists = [list]
        vm.defaultList = list

        // Act
        vm.renameList(list, to: "Umbenannt")
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertEqual(vm.defaultList?.title, "Umbenannt")
    }
}

// MARK: - deleteList

@MainActor
final class DeleteListTests: XCTestCase {

    func test_deleteList_removesFromAllLists() async throws {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        let list1 = makeListModel(ownerId: ownerId, title: "Liste A")
        let list2 = makeListModel(ownerId: ownerId, title: "Liste B", isDefault: true)
        let vm = makeViewModel(repo: repo)
        vm.allLists = [list1, list2]

        // Act
        vm.deleteList(list1)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertFalse(vm.allLists.contains(where: { $0.id == list1.id }))
        XCTAssertTrue(repo.deleteListCalled)
    }

    func test_deleteList_preventsLastList() {
        // Arrange
        let repo = MockListsRepository()
        let list = makeListModel(title: "Einzige Liste")
        let vm = makeViewModel(repo: repo)
        vm.allLists = [list]

        // Act
        vm.deleteList(list)

        // Assert
        XCTAssertFalse(repo.deleteListCalled)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertEqual(vm.allLists.count, 1)
    }

    func test_deleteList_switchesActiveListWhenDeleted() async throws {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        let activeList = makeListModel(ownerId: ownerId, title: "Aktiv", isDefault: false)
        let otherList = makeListModel(ownerId: ownerId, title: "Andere", isDefault: true)
        let container = PersistenceController.preview.container
        let vm = ListViewModel(
            listId: activeList.id,
            repository: PreviewItemsRepository(),
            itemStore: SwiftDataItemStore(context: container.mainContext),
            listStore: SwiftDataListStore(context: container.mainContext),
            startImmediately: false
        )
        vm.configure(listsRepository: repo)
        vm.allLists = [activeList, otherList]
        vm.defaultList = activeList

        // Act
        vm.deleteList(activeList)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertNotEqual(vm.defaultList?.id, activeList.id)
    }

    func test_deleteList_onRemoteError_rollsBackList() async throws {
        // Arrange
        let repo = MockListsRepository()
        repo.shouldThrowOnDelete = true
        let ownerId = UUID()
        let list1 = makeListModel(ownerId: ownerId, title: "Zu löschen")
        let list2 = makeListModel(ownerId: ownerId, title: "Bleibt", isDefault: true)
        let vm = makeViewModel(repo: repo)
        vm.allLists = [list1, list2]

        // Act
        vm.deleteList(list1)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert: list1 wird nach Rollback wieder eingefügt
        XCTAssertTrue(vm.allLists.contains(where: { $0.id == list1.id }))
        XCTAssertNotNil(vm.errorMessage)
    }
}

// MARK: - setDefaultList

@MainActor
final class SetDefaultListTests: XCTestCase {

    func test_setDefaultList_optimisticallyUpdatesIsDefault() {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        let previous = makeListModel(ownerId: ownerId, title: "Alt Standard", isDefault: true)
        let newDefault = makeListModel(ownerId: ownerId, title: "Neu Standard", isDefault: false)
        let vm = makeViewModel(repo: repo)
        vm.allLists = [previous, newDefault]

        // Act
        vm.setDefaultList(newDefault)

        // Assert immediately (optimistic)
        XCTAssertTrue(vm.allLists.first(where: { $0.id == newDefault.id })?.isDefault == true)
        XCTAssertTrue(vm.allLists.first(where: { $0.id == previous.id })?.isDefault == false)
    }

    func test_setDefaultList_callsRepository() async throws {
        // Arrange
        let repo = MockListsRepository()
        let ownerId = UUID()
        let list = makeListModel(ownerId: ownerId, title: "Neue Standard")
        let vm = makeViewModel(repo: repo)
        vm.allLists = [makeListModel(ownerId: ownerId, isDefault: true), list]

        // Act
        vm.setDefaultList(list)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertTrue(repo.setDefaultListCalled)
    }

    func test_setDefaultList_onRemoteError_rollsBackDefault() async throws {
        // Arrange
        let repo = MockListsRepository()
        repo.shouldThrowOnSetDefault = true
        let ownerId = UUID()
        let previous = makeListModel(ownerId: ownerId, title: "Original Standard", isDefault: true)
        let candidate = makeListModel(ownerId: ownerId, title: "Kandidat", isDefault: false)
        let vm = makeViewModel(repo: repo)
        vm.allLists = [previous, candidate]

        // Act
        vm.setDefaultList(candidate)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert rollback
        XCTAssertTrue(vm.allLists.first(where: { $0.id == previous.id })?.isDefault == true)
        XCTAssertTrue(vm.allLists.first(where: { $0.id == candidate.id })?.isDefault == false)
        XCTAssertNotNil(vm.errorMessage)
    }
}

// MARK: - switchToList

@MainActor
final class SwitchToListTests: XCTestCase {

    func test_switchToList_updatesDefaultList() {
        // Arrange
        let repo = MockListsRepository()
        let list = makeListModel(title: "Neue Aktive Liste")
        let vm = makeViewModel(repo: repo)

        // Act
        vm.switchToList(list)

        // Assert
        XCTAssertEqual(vm.defaultList?.id, list.id)
        XCTAssertEqual(vm.defaultList?.title, list.title)
    }
}
