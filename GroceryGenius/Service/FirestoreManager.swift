//
//  FirestoreManager 2.swift
//  GroceryGenius
//
//  Created by Robert Bogner on 23.04.25.
//


import Foundation
import FirebaseFirestore

/// Verwaltet alle Firestore-Operationen für Items
class FirestoreManager {
    static let shared = FirestoreManager()
    
    private let db = Firestore.firestore()
    private let collection = "items"

    private init() {}

    // MARK: - Live-Listener für Items
    
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerRegistration {
        return db.collection(collection).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("⚠️ Firestore: Keine Dokumente gefunden – \(error?.localizedDescription ?? "Unbekannt")")
                onUpdate([])
                return
            }

            let items = documents.compactMap { doc -> ItemModel? in
                let data = doc.data()
                guard
                    let name = data["name"] as? String,
                    let image = data["image"] as? String,
                    let units = data["units"] as? Int,
                    let measure = data["measure"] as? String,
                    let price = data["price"] as? Double,
                    let isChecked = data["isChecked"] as? Bool
                else {
                    return nil
                }

                return ItemModel(
                    id: doc.documentID,
                    image: image,
                    name: name,
                    units: units,
                    measure: measure,
                    price: price,
                    isChecked: isChecked
                )
            }

            onUpdate(items)
        }
    }

    // MARK: - Item hinzufügen
    
    func addItem(_ item: ItemModel) {
        do {
            let data = try JSONEncoder().encode(item)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            db.collection(collection).document(item.id).setData(json ?? [:])
        } catch {
            print("❌ Fehler beim Hinzufügen: \(error)")
        }
    }

    // MARK: - Item aktualisieren
    
    func updateItem(_ item: ItemModel) {
        do {
            let data = try JSONEncoder().encode(item)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            db.collection(collection).document(item.id).setData(json ?? [:], merge: true)
        } catch {
            print("❌ Fehler beim Aktualisieren: \(error)")
        }
    }

    // MARK: - Item löschen
    
    func deleteItem(_ item: ItemModel) {
        db.collection(collection).document(item.id).delete()
    }
}