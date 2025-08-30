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
    static let partners: [PublicUserId] = [PublicUserId("genius-123"), PublicUserId("genius-456")]
}

// MARK: - ItemsRepository (in-memory, scoped)
final class PreviewItemsRepository: ItemsRepository {
    private var store: [String: [ItemModel]] = [:] // key = "<owner>#<listId>"
    private func key(_ owner: PublicUserId, _ listId: String) -> String { "\(owner.value)#\(listId)" }

    // Preview-only seeding helper
    func seed(owner: PublicUserId, listId: String, items: [ItemModel]) {
        store[key(owner, listId)] = items.map { itm in var i = itm; i.ownerPublicId = owner.value; i.listId = listId; return i }
    }

    func observeItems(for owner: PublicUserId, listId: String) -> AsyncStream<[ItemModel]> {
        let snapshot = store[key(owner, listId)] ?? []
        return AsyncStream { cont in cont.yield(snapshot); cont.finish() }
    }

    func createItem(for owner: PublicUserId, listId: String, payload: NewItemPayload) async throws -> ItemModel {
        let k = key(owner, listId)
        var arr = store[k] ?? []
        let new = ItemModel(
            id: payload.id ?? UUID().uuidString,
            ownerPublicId: owner.value,
            imageData: payload.imageData,
            name: payload.name,
            units: payload.units,
            measure: payload.measure,
            price: payload.price,
            isChecked: payload.isChecked,
            category: payload.category,
            productDescription: payload.productDescription,
            brand: payload.brand,
            listId: listId
        )
        arr.append(new); store[k] = arr
        return new
    }

    func updateItem(for owner: PublicUserId, listId: String, item: ItemModel) async throws {
        let k = key(owner, listId)
        var arr = store[k] ?? []
        if let idx = arr.firstIndex(where: { $0.id == item.id }) { arr[idx] = item }
        store[k] = arr
    }

    func deleteItem(for owner: PublicUserId, listId: String, itemId: String) async throws {
        let k = key(owner, listId)
        var arr = store[k] ?? []
        arr.removeAll { $0.id == itemId }
        store[k] = arr
    }
}

// Preview-only: mutable class with Sendable protocol conformance; safe due to single-threaded preview usage.
extension PreviewItemsRepository: @unchecked Sendable {}

// MARK: - ListRepository (preview)
final class PreviewListRepository: ListRepository {
    var lists: [GroceryList]
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
}

// Preview-only: mutable class with Sendable protocol conformance; safe due to single-threaded preview usage.
extension PreviewListRepository: @unchecked Sendable {}

// MARK: - PairingRepository (preview)
final class PreviewPairingRepository: PairingRepository {
    var partners: [PublicUserId]
    var incoming: [PairingRequest] = []
    init(partners: [PublicUserId] = [PublicUserId("genius-123"), PublicUserId("genius-456")]) { self.partners = partners }

    func generateInviteCode(for user: PublicUserId) async throws -> String { "PREV-1234" }
    func observeIncomingRequests(for user: PublicUserId) -> AsyncStream<[PairingRequest]> { AsyncStream { $0.yield(self.incoming) } }
    func createRequest(_ request: PairingRequest) async throws { incoming.append(request) }
    func updateRequest(_ request: PairingRequest) async throws { if let i = incoming.firstIndex(where: { $0.id == request.id }) { incoming[i] = request } }
    func addPair(a: PublicUserId, b: PublicUserId) async throws { let new = (a == PreviewData.publicId) ? b : a; if !partners.contains(new) { partners.append(new) } }
    func listPartners(of user: PublicUserId) async throws -> [PublicUserId] { partners }
}

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
    let repo = PreviewItemsRepository()
    repo.seed(owner: PreviewData.publicId, listId: "default", items: PreviewData.items)
    let vm = ListViewModel(repository: repo)
    vm.configure(publicId: PreviewData.publicId, listId: "default")
    return vm
}
