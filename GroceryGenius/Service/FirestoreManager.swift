// MARK: - FirestoreManager.swift

/*
 FirestoreManager.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 26.04.2025
*/

import Foundation
import FirebaseFirestore

/// A manager responsible for handling Firestore operations related to shopping list items.
final class FirestoreManager: ItemsRepository {
    // MARK: - Properties
    /// Singleton instance of the FirestoreManager.
    static let shared = FirestoreManager()
    
    /// The Firestore database reference.
    private let db = Firestore.firestore() // Creates a Firestore database connection
    
    /// The name of the Firestore collection where items are stored.
    private let collection = "items" // Collection name in Firestore where documents are saved

    // MARK: - Initializer
    
    /// Private initializer to ensure singleton usage.
    private init() {} // Restricts creation to only one shared instance

    // MARK: - Firestore Listener

    /// Starts a real-time listener for item changes in Firestore.
    /// - Parameter onUpdate: Closure to be called with the updated list of items.
    /// - Returns: A ListenerRegistration object that can be used to stop listening.
    @discardableResult
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerToken {
        return db.collection(collection).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                // Print a warning if no documents were found and call the update closure with an empty array
                print("⚠️ Firestore: No documents found — \(error?.localizedDescription ?? "Unknown error")")
                onUpdate([])
                return
            }

            // Try to map documents into ItemModel objects
            let items: [ItemModel] = documents.compactMap { doc in
                try? doc.data(as: ItemModel.self)
            }
            onUpdate(items) // Send updated item list to the caller
        } as ListenerRegistration
    }
    
    // MARK: - CRUD Operations
    
    /// Adds a new item to Firestore.
    /// - Parameters:
    ///   - item: The item to be added.
    ///   - completion: Optional closure called with an optional Error if the operation fails.
    func addItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        do {
            // The imageData property (Base64-encoded) is now also included during Firestore save and update operations.
            try db.collection(collection).document(item.id).setData(from: item) // Save item to Firestore
            completion?(nil) // Call completion handler without error
        } catch {
            print("❌ Firestore Error - Add Item: \(error.localizedDescription)")
            completion?(error) // Pass error to completion handler
        }
    }
    
    /// Updates an existing item in Firestore.
    /// - Parameters:
    ///   - item: The item to be updated.
    ///   - completion: Optional closure called with an optional Error if the operation fails.
    func updateItem(_ item: ItemModel, completion: ((Error?) -> Void)? = nil) {
        do {
            // The imageData property (Base64-encoded) is now also included during Firestore save and update operations.
            try db.collection(collection).document(item.id).setData(from: item, merge: true) // Merge changes into existing document
            completion?(nil) // Call completion handler without error
        } catch {
            print("❌ Firestore Error - Update Item: \(error.localizedDescription)")
            completion?(error) // Pass error to completion handler
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
                completion?(error) // Pass error to completion handler if deletion fails
            } else {
                completion?(nil) // Call completion handler without error if deletion succeeds
            }
        }
    }
}
