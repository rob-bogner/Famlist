// filepath: GroceryGenius/PreviewSupport/PreviewMocks.swift
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

// MARK: - ItemsRepository (in-memory)
final class PreviewItemsRepository: ItemsRepository {
    private var items: [ItemModel]
    private var listeners: [UUID: ([ItemModel]) -> Void] = [:]

    init(items: [ItemModel] = PreviewData.items) { self.items = items }

    @discardableResult
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerToken {
        let id = UUID()
        listeners[id] = onUpdate
        // push immediately
        onUpdate(items)
        return PreviewToken { [weak self] in self?.listeners.removeValue(forKey: id) }
    }

    func addItem(_ item: ItemModel, completion: ((Error?) -> Void)?) {
        items.append(item)
        broadcast()
        completion?(nil)
    }
    func updateItem(_ item: ItemModel, completion: ((Error?) -> Void)?) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) { items[idx] = item; broadcast() }
        completion?(nil)
    }
    func deleteItem(_ item: ItemModel, completion: ((Error?) -> Void)?) {
        items.removeAll { $0.id == item.id }
        broadcast()
        completion?(nil)
    }

    private func broadcast() { for cb in listeners.values { cb(items) } }
}

private final class PreviewToken: NSObject {
    private let onDeinit: () -> Void
    init(_ onDeinit: @escaping () -> Void) { self.onDeinit = onDeinit }
    deinit { onDeinit() }
}

// MARK: - ListRepository (preview)
final class PreviewListRepository: ListRepository {
    private var lists: [GroceryList]
    init(lists: [GroceryList] = PreviewData.lists) { self.lists = lists }
    func observeLists(for owner: PublicUserId) -> AsyncStream<[GroceryList]> {
        AsyncStream { continuation in
            let owned = self.lists.filter { $0.owner == owner }
            continuation.yield(owned)
        }
    }
    func createList(_ list: GroceryList) async throws { lists.append(list) }
    func updateList(_ list: GroceryList) async throws { if let i = lists.firstIndex(where: { $0.id == list.id }) { lists[i] = list } }
    func deleteList(id: String) async throws { lists.removeAll { $0.id == id } }
}

extension PreviewListRepository: @unchecked Sendable {}

// MARK: - PairingRepository (preview)
final class PreviewPairingRepository: PairingRepository {
    var partners: [PublicUserId]
    var incoming: [PairingRequest] = []
    init(partners: [PublicUserId] = PreviewData.partners) { self.partners = partners }

    func generateInviteCode(for user: PublicUserId) async throws -> String { "PREV-1234" }
    func observeIncomingRequests(for user: PublicUserId) -> AsyncStream<[PairingRequest]> { AsyncStream { $0.yield(self.incoming) } }
    func createRequest(_ request: PairingRequest) async throws { incoming.append(request) }
    func updateRequest(_ request: PairingRequest) async throws { if let i = incoming.firstIndex(where: { $0.id == request.id }) { incoming[i] = request } }
    func addPair(a: PublicUserId, b: PublicUserId) async throws { let new = (a == PreviewData.publicId) ? b : a; if !partners.contains(new) { partners.append(new) } }
    func listPartners(of user: PublicUserId) async throws -> [PublicUserId] { partners }
}

// MARK: - UserIdService (preview)
struct PreviewUserIdService: UserIdService {
    func getOrCreateUserId() async throws -> PublicUserId { PreviewData.publicId }
    func currentLocalId() -> PublicUserId? { PreviewData.publicId }
}

// MARK: - Recipe Import Presenter (no-op)
struct PreviewImportPresenter: RecipeImportPresenting { func presentImport() {} }
