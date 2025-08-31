// MARK: - FirestoreManager.swift

/*
 File: FirestoreManager.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 Concrete Firestore-backed implementation of ItemsRepository. Provides a singleton used by view models to observe and mutate shopping list items in real time.

 Responsibilities / Includes:
 - Real-time snapshot listener producing [ItemModel]
 - CRUD (add / update / delete) with Codable mapping
 - Simple error logging (console)
 - Encapsulates collection naming & Firestore access

 Key Points:
 - Uses ItemModel.id (UUID) as Firestore document ID (stable & deterministic)
 - updateItem applies merge:true to avoid overwriting untouched fields
 - Listener emits empty array on failure so UI can gracefully degrade

 Error Handling:
 - Snapshot errors logged, caller receives empty list
 - Encoding failures surface via completion(Error)
 - Delete completion passes underlying Firestore error

 Notes:
 - Consider enhancing logging with a structured logger for production
 - For unit tests provide a mock conforming to ItemsRepository
*/

import Foundation
@preconcurrency import FirebaseFirestore

/// Firestore-backed legacy helper for ItemModel entities (unscoped). Kept for backward compatibility in isolated flows.
final class FirestoreManager {
    // MARK: - Constants
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    private let collection = "items"

    private init() {}

    // Manual encode/decode for ItemModel (no FirebaseFirestoreSwift)
    private func encode(_ item: ItemModel) -> [String: Any] {
        var dict: [String: Any] = [
            "id": item.id,
            "ownerPublicId": item.ownerPublicId as Any,
            "imageData": item.imageData as Any,
            "name": item.name,
            "units": item.units,
            "measure": item.measure,
            "price": item.price,
            "isChecked": item.isChecked,
            "category": item.category as Any,
            "productDescription": item.productDescription as Any,
            "brand": item.brand as Any,
            "listId": item.listId
        ]
        // Remove nil Any values that Firestore doesn't accept
        dict = dict.filter { !($0.value is NSNull) }
        return dict
    }
    private func decode(_ data: [String: Any], docId: String) -> ItemModel? {
        guard let name = data["name"] as? String,
              let unitsNum = data["units"],
              let measure = data["measure"] as? String,
              let priceNum = data["price"],
              let isChecked = data["isChecked"] as? Bool,
              let listId = data["listId"] as? String else { return nil }
        let units = (unitsNum as? Int) ?? (unitsNum as? NSNumber)?.intValue ?? 1
        let price = (priceNum as? Double) ?? (priceNum as? NSNumber)?.doubleValue ?? 0.0
        return ItemModel(
            id: (data["id"] as? String) ?? docId,
            ownerPublicId: data["ownerPublicId"] as? String,
            imageData: data["imageData"] as? String,
            name: name,
            units: units,
            measure: measure,
            price: price,
            isChecked: isChecked,
            category: data["category"] as? String,
            productDescription: data["productDescription"] as? String,
            brand: data["brand"] as? String,
            listId: listId
        )
    }

    // MARK: - Real-time Listener (legacy)
    @discardableResult
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerRegistration {
        db.collection(collection).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("⚠️ Firestore snapshot empty – \(error?.localizedDescription ?? "unknown error")")
                onUpdate([])
                return
            }
            let items: [ItemModel] = documents.compactMap { doc in
                self.decode(doc.data(), docId: doc.documentID)
            }
            onUpdate(items)
        }
    }

    // MARK: - CRUD (legacy, unscoped)
    func addItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        db.collection(collection).document(item.id).setData(encode(item)) { error in
            if let error { print("❌ Firestore add: \(error.localizedDescription)") }
            completion?(error)
        }
    }

    func updateItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        let doc = db.collection(collection).document(item.id)
        // If imageData is nil or empty, explicitly delete the field in Firestore. Codable omits nils which won't clear with merge: true.
        let shouldDeleteImageField = (item.imageData == nil) || (item.imageData?.isEmpty == true)
        if shouldDeleteImageField { doc.updateData(["imageData": FieldValue.delete()]) }
        doc.setData(encode(item), merge: true) { error in
            if let error { print("❌ Firestore update: \(error.localizedDescription)") }
            completion?(error)
        }
    }

    func deleteItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        db.collection(collection).document(item.id).delete { error in
            if let error { print("❌ Firestore delete: \(error.localizedDescription)") }
            completion?(error)
        }
    }
}
