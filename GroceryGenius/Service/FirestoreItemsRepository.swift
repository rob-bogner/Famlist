// MARK: - FirestoreItemsRepository (scoped items)

import Foundation
@preconcurrency import FirebaseFirestore

final class FirestoreItemsRepository: ItemsRepository {
    private let db = Firestore.firestore()

    private func itemsCollection(owner: PublicUserId, listId: String) -> CollectionReference {
        db.collection("users")
            .document(owner.value)
            .collection("lists")
            .document(listId)
            .collection("items")
    }
    // NEW: shared items path
    private func sharedItemsCollection(sharedId: String) -> CollectionReference {
        db.collection("shared_lists").document(sharedId).collection("items")
    }
    // NEW: choose collection from context
    private func itemsCollection(for ctx: ListContext) -> CollectionReference {
        if let sid = ctx.sharedListId { return sharedItemsCollection(sharedId: sid) }
        return itemsCollection(owner: ctx.owner, listId: ctx.listId)
    }

    // Manual encode/decode (no FirebaseFirestoreSwift)
    private func encode(_ item: ItemModel) -> [String: Any] {
        var dict: [String: Any] = [
            "id": item.id,
            "ownerPublicId": item.ownerPublicId as Any,
            "name": item.name,
            "units": item.units,
            "measure": item.measure,
            "price": item.price,
            "isChecked": item.isChecked,
            "listId": item.listId
        ]
        if let img = item.imageData { dict["imageData"] = img }
        if let cat = item.category { dict["category"] = cat }
        if let desc = item.productDescription { dict["productDescription"] = desc }
        if let brand = item.brand { dict["brand"] = brand }
        return dict
    }
    private func decode(_ data: [String: Any], docId: String) -> ItemModel? {
        guard let name = data["name"] as? String,
              let units = data["units"] as? Int,
              let measure = data["measure"] as? String,
              let price = data["price"] as? Double,
              let isChecked = data["isChecked"] as? Bool,
              let listId = data["listId"] as? String
        else { return nil }
        let ownerPid = data["ownerPublicId"] as? String
        let imageData = data["imageData"] as? String
        let category = data["category"] as? String
        let productDescription = data["productDescription"] as? String
        let brand = data["brand"] as? String
        return ItemModel(
            id: data["id"] as? String ?? docId,
            ownerPublicId: ownerPid,
            imageData: imageData,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId
        )
    }

    func observeItems(for owner: PublicUserId, listId: String) -> AsyncStream<[ItemModel]> {
        let col = itemsCollection(owner: owner, listId: listId)
        return AsyncStream { continuation in
            let listener = col.addSnapshotListener { snap, err in
                if err != nil { continuation.yield([]); return }
                let items: [ItemModel] = (snap?.documents ?? []).compactMap { doc in
                    self.decode(doc.data(), docId: doc.documentID)
                }
                continuation.yield(items)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // NEW: Context-based observe
    func observeItems(in ctx: ListContext) -> AsyncStream<[ItemModel]> {
        let col = itemsCollection(for: ctx)
        return AsyncStream { continuation in
            let listener = col.addSnapshotListener { snap, err in
                if err != nil { continuation.yield([]); return }
                let items: [ItemModel] = (snap?.documents ?? []).compactMap { doc in
                    self.decode(doc.data(), docId: doc.documentID)
                }
                continuation.yield(items)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func createItem(for owner: PublicUserId, listId: String, payload: NewItemPayload) async throws -> ItemModel {
        let id = payload.id ?? UUID().uuidString
        let item = ItemModel(
            id: id,
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
        try await itemsCollection(owner: owner, listId: listId)
            .document(id)
            .setData(encode(item), merge: false)
        return item
    }

    // NEW: Context-based create
    func createItem(in ctx: ListContext, payload: NewItemPayload) async throws -> ItemModel {
        let id = payload.id ?? UUID().uuidString
        let item = ItemModel(
            id: id,
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
        try await itemsCollection(for: ctx).document(id).setData(encode(item), merge: false)
        return item
    }

    func updateItem(for owner: PublicUserId, listId: String, item: ItemModel) async throws {
        try await itemsCollection(owner: owner, listId: listId)
            .document(item.id)
            .setData(encode(item), merge: true)
    }

    // NEW: Context-based update
    func updateItem(in ctx: ListContext, item: ItemModel) async throws {
        try await itemsCollection(for: ctx).document(item.id).setData(encode(item), merge: true)
    }

    func deleteItem(for owner: PublicUserId, listId: String, itemId: String) async throws {
        try await itemsCollection(owner: owner, listId: listId)
            .document(itemId)
            .delete()
    }

    // NEW: Context-based delete
    func deleteItem(in ctx: ListContext, itemId: String) async throws {
        try await itemsCollection(for: ctx).document(itemId).delete()
    }
}
