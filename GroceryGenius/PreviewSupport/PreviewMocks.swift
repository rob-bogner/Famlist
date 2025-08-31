// MARK: - Preview Mocks & Sample Data (no Firebase)
// Lightweight, in-memory implementations used by SwiftUI previews only.

import Foundation
import SwiftUI

// MARK: - Preview Sample Data
enum PreviewData {
    static let publicId = PublicUserId("genius-999")
    static let items: [ItemModel] = [
        ItemModel(imageData: nil, name: "Milk", units: 1, measure: "l", price: 1.19, isChecked: false, category: "Dairy", productDescription: "Organic whole milk 3.5%", brand: "Brand"),
        ItemModel(imageData: nil, name: "Eggs", units: 10, measure: "pcs", price: 2.49, isChecked: false, category: "Dairy"),
        ItemModel(imageData: nil, name: "Tomatoes", units: 4, measure: "pcs", price: 1.29, isChecked: true, category: "Vegetables")
    ]
    static let lists: [GroceryList] = [
        GroceryList(owner: publicId, name: "Weekly", items: [GroceryItem(title: "Milk", qty: 1, unit: "l"), GroceryItem(title: "Bread", qty: 1)]),
        GroceryList(owner: publicId, name: "BBQ", items: [GroceryItem(title: "Steak", qty: 2, unit: "pcs")])
    ]
}

// MARK: - ItemsRepository (in-memory, scoped)
final class PreviewItemsRepository: ItemsRepository {
    private var userStore: [String: [ItemModel]] = [:] // key = "<owner>#<listId>"
    private var sharedStore: [String: [ItemModel]] = [:] // key = sharedId
    private func ukey(_ owner: PublicUserId, _ listId: String) -> String { "\(owner.value)#\(listId)" }

    // Preview-only seeding helper
    func seed(owner: PublicUserId, listId: String, items: [ItemModel]) {
        userStore[ukey(owner, listId)] = items.map { itm in var i = itm; i.ownerPublicId = owner.value; i.listId = listId; return i }
    }
    func seedShared(sharedId: String, items: [ItemModel]) {
        sharedStore[sharedId] = items
    }

    func observeItems(for owner: PublicUserId, listId: String) -> AsyncStream<[ItemModel]> {
        let snapshot = userStore[ukey(owner, listId)] ?? []
        return AsyncStream { cont in cont.yield(snapshot); cont.finish() }
    }

    // NEW: Context-based APIs for previews (support shared)
    func observeItems(in ctx: ListContext) -> AsyncStream<[ItemModel]> {
        if let sid = ctx.sharedListId { return AsyncStream { $0.yield(self.sharedStore[sid] ?? []); $0.finish() } }
        return observeItems(for: ctx.owner, listId: ctx.listId)
    }
    func createItem(in ctx: ListContext, payload: NewItemPayload) async throws -> ItemModel {
        let new = ItemModel(
            id: payload.id ?? UUID().uuidString,
            ownerPublicId: ctx.owner.value,
            imageData: payload.imageData,
            name: payload.name,
            units: payload.units,
            measure: payload.measure,
            price: payload.price,
            isChecked: payload.isChecked,
            category: payload.category,
            productDescription: payload.productDescription,
            brand: payload.brand,
            listId: ctx.listId
        )
        if let sid = ctx.sharedListId {
            var arr = sharedStore[sid] ?? []
            arr.append(new); sharedStore[sid] = arr
            return new
        } else {
            let k = ukey(ctx.owner, ctx.listId)
            var arr = userStore[k] ?? []
            arr.append(new); userStore[k] = arr
            return new
        }
    }
    func updateItem(in ctx: ListContext, item: ItemModel) async throws {
        if let sid = ctx.sharedListId {
            var arr = sharedStore[sid] ?? []
            if let idx = arr.firstIndex(where: { $0.id == item.id }) { arr[idx] = item }
            sharedStore[sid] = arr
        } else {
            let k = ukey(ctx.owner, ctx.listId)
            var arr = userStore[k] ?? []
            if let idx = arr.firstIndex(where: { $0.id == item.id }) { arr[idx] = item }
            userStore[k] = arr
        }
    }
    func deleteItem(in ctx: ListContext, itemId: String) async throws {
        if let sid = ctx.sharedListId {
            var arr = sharedStore[sid] ?? []
            arr.removeAll { $0.id == itemId }
            sharedStore[sid] = arr
        } else {
            let k = ukey(ctx.owner, ctx.listId)
            var arr = userStore[k] ?? []
            arr.removeAll { $0.id == itemId }
            userStore[k] = arr
        }
    }

    // Legacy owner/listId APIs required by protocol
    func createItem(for owner: PublicUserId, listId: String, payload: NewItemPayload) async throws -> ItemModel {
        try await createItem(in: ListContext(owner: owner, listId: listId, sharedListId: nil), payload: payload)
    }
    func updateItem(for owner: PublicUserId, listId: String, item: ItemModel) async throws {
        try await updateItem(in: ListContext(owner: owner, listId: listId, sharedListId: nil), item: item)
    }
    func deleteItem(for owner: PublicUserId, listId: String, itemId: String) async throws {
        try await deleteItem(in: ListContext(owner: owner, listId: listId, sharedListId: nil), itemId: itemId)
    }
}

// Preview-only: mutable class with Sendable protocol conformance; safe due to single-threaded preview usage.
extension PreviewItemsRepository: @unchecked Sendable {}

// MARK: - ListRepository (preview)
final class PreviewListRepository: ListRepository {
    var lists: [GroceryList]
    var shared: [String: SharedList] = [:]
    init(lists: [GroceryList] = PreviewData.lists) { self.lists = lists }
    func observeLists(for owner: PublicUserId) -> AsyncStream<[GroceryList]> {
        AsyncStream { $0.yield(self.lists.filter { $0.ownerPublicId == owner.value }) }
    }
    func createList(_ list: GroceryList) async throws { lists.append(list) }
    func updateList(_ list: GroceryList) async throws { if let i = lists.firstIndex(where: { $0.id == list.id }) { lists[i] = list } }
    func deleteList(id: String) async throws { lists.removeAll { $0.id == id } }
    func ensureDefaultList(for owner: PublicUserId) async throws {
        if lists.contains(where: { $0.ownerPublicId == owner.value && $0.id == "default" }) { return }
        lists.append(GroceryList(id: "default", owner: owner, name: "My List"))
    }
    // NEW
    func getList(for owner: PublicUserId, listId: String) async throws -> GroceryList {
        if let l = lists.first(where: { $0.id == listId && $0.ownerPublicId == owner.value }) { return l }
        throw ItemsRepositoryError.notFound
    }
    func createSharedList(owners: [PublicUserId]) async throws -> SharedList {
        let id = UUID().uuidString
        let s = SharedList(id: id, owners: owners.map { $0.value }, createdAt: Date())
        shared[id] = s
        return s
    }
    func attachListToShared(owner: PublicUserId, listId: String, sharedId: String) async throws {
        if let idx = lists.firstIndex(where: { $0.id == listId && $0.ownerPublicId == owner.value }) {
            var l = lists[idx]; l.sharedListId = sharedId; lists[idx] = l
        }
    }
    func getSharedList(by id: String) async throws -> SharedList? { shared[id] }
}

// Preview-only: mutable class with Sendable protocol conformance; safe due to single-threaded preview usage.
extension PreviewListRepository: @unchecked Sendable {}

// MARK: - UserIdService (preview)
struct PreviewUserIdService: UserIdService {
    func getOrCreatePublicId() async throws -> PublicUserId { PreviewData.publicId }
    func getOrCreateUserId() async throws -> PublicUserId { PreviewData.publicId }
    func currentLocalId() -> PublicUserId? { PreviewData.publicId }
}

// MARK: - Recipe Import Presenter (no-op)
struct PreviewImportPresenter: RecipeImportPresenting { func presentImport() {} }

// MARK: - Preview VM Helper
@MainActor
func makePreviewListVM() -> ListViewModel {
    let itemsRepo = PreviewItemsRepository()
    let listRepo = PreviewListRepository()
    itemsRepo.seed(owner: PreviewData.publicId, listId: "default", items: PreviewData.items)
    let vm = ListViewModel(itemsRepository: itemsRepo, listRepository: listRepo)
    vm.configure(publicId: PreviewData.publicId, listId: "default")
    return vm
}

// NEW: paired preview helpers
@MainActor
func makePairedListVM_A(sharedId: String) -> ListViewModel {
    let itemsRepo = PreviewItemsRepository()
    let listRepo = PreviewListRepository()
    // Seed shared items so both A and B see same snapshot
    itemsRepo.seedShared(sharedId: sharedId, items: PreviewData.items)
    // Attach the user's default list to the shared id
    let ownerA = PublicUserId("genius-1")
    Task { try? await listRepo.ensureDefaultList(for: ownerA); try? await listRepo.attachListToShared(owner: ownerA, listId: "default", sharedId: sharedId) }
    let vm = ListViewModel(itemsRepository: itemsRepo, listRepository: listRepo)
    vm.configure(publicId: ownerA, listId: "default")
    return vm
}
@MainActor
func makePairedListVM_B(sharedId: String) -> ListViewModel {
    let itemsRepo = PreviewItemsRepository()
    let listRepo = PreviewListRepository()
    itemsRepo.seedShared(sharedId: sharedId, items: PreviewData.items)
    let ownerB = PublicUserId("genius-2")
    Task { try? await listRepo.ensureDefaultList(for: ownerB); try? await listRepo.attachListToShared(owner: ownerB, listId: "default", sharedId: sharedId) }
    let vm = ListViewModel(itemsRepository: itemsRepo, listRepository: listRepo)
    vm.configure(publicId: ownerB, listId: "default")
    return vm
}
