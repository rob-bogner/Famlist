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

    func observeItems(for owner: PublicUserId, listId: String) -> AsyncStream<[ItemModel]> {
        let col = itemsCollection(owner: owner, listId: listId)
        return AsyncStream { continuation in
            let listener = col.addSnapshotListener { snap, err in
                if err != nil { continuation.yield([]); return }
                let items: [ItemModel] = (snap?.documents ?? []).compactMap { doc in
                    try? doc.data(as: ItemModel.self)
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
        // Encode to dictionary to use async setData(_:merge:) and avoid await-on-sync warnings
        let data = try Firestore.Encoder().encode(item)
        try await itemsCollection(owner: owner, listId: listId)
            .document(id)
            .setData(data, merge: false)
        return item
    }

    func updateItem(for owner: PublicUserId, listId: String, item: ItemModel) async throws {
        // Encode to dictionary to use async setData(_:merge:)
        let data = try Firestore.Encoder().encode(item)
        try await itemsCollection(owner: owner, listId: listId)
            .document(item.id)
            .setData(data, merge: true)
    }

    func deleteItem(for owner: PublicUserId, listId: String, itemId: String) async throws {
        try await itemsCollection(owner: owner, listId: listId)
            .document(itemId)
            .delete()
    }
}
