// MARK: - FirestoreManager.swift

import Foundation
import FirebaseFirestore

/// A manager responsible for handling Firestore operations related to shopping list items.
final class FirestoreManager {
    
    // MARK: - Properties
    
    /// Singleton instance of the FirestoreManager.
    static let shared = FirestoreManager()
    
    /// The Firestore database reference.
    private let db = Firestore.firestore()
    
    /// The name of the Firestore collection where items are stored.
    private let collection = "items"
    
    // MARK: - Initializer
    
    /// Private initializer to ensure singleton usage.
    private init() {}
    
    // MARK: - Firestore Listener
    
    /// Starts a real-time listener for item changes in Firestore.
    /// - Parameter onUpdate: Closure to be called with the updated list of items.
    /// - Returns: A ListenerRegistration object that can be used to stop listening.
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerRegistration {
        return db.collection(collection).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("⚠️ Firestore: No documents found — \(error?.localizedDescription ?? "Unknown error")")
                onUpdate([])
                return
            }

            let items: [ItemModel] = documents.compactMap { doc in
                try? doc.data(as: ItemModel.self)
            }
            onUpdate(items)
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new item to Firestore.
    /// - Parameters:
    ///   - item: The item to be added.
    ///   - completion: Optional closure called with an optional Error if the operation fails.
    func addItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        do {
            try db.collection(collection).document(item.id).setData(from: item)
            completion?(nil)
        } catch {
            print("❌ Firestore Error - Add Item: \(error.localizedDescription)")
            completion?(error)
        }
    }
    
    /// Updates an existing item in Firestore.
    /// - Parameters:
    ///   - item: The item to be updated.
    ///   - completion: Optional closure called with an optional Error if the operation fails.
    func updateItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        do {
            try db.collection(collection).document(item.id).setData(from: item, merge: true)
            completion?(nil)
        } catch {
            print("❌ Firestore Error - Update Item: \(error.localizedDescription)")
            completion?(error)
        }
    }
    
    /// Deletes an item from Firestore.
    /// - Parameters:
    ///   - item: The item to be deleted.
    ///   - completion: Optional closure called with an optional Error if the operation fails.
    func deleteItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        db.collection(collection).document(item.id).delete { error in
            if let error = error {
                print("❌ Firestore Error - Delete Item: \(error.localizedDescription)")
                completion?(error)
            } else {
                completion?(nil)
            }
        }
    }
}
