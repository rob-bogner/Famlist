// MARK: - FirestoreManager.swift

import Foundation
import FirebaseFirestore

class FirestoreManager {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    private let collection = "items"

    private init() {}

    /// Startet einen Listener, der Änderungen in Firestore in Echtzeit zurückmeldet.
    func addListener(onUpdate: @escaping ([ItemModel]) -> Void) -> ListenerRegistration {
        return db.collection(collection).addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("⚠️ Firestore: Keine Dokumente gefunden — \(error?.localizedDescription ?? "Unbekannt")")
                onUpdate([])
                return
            }

            let items: [ItemModel] = documents.compactMap { doc in
                try? doc.data(as: ItemModel.self)
            }
            onUpdate(items)
        }
    }

    /// Fügt ein Item in Firestore hinzu
    func addItem(_ item: ItemModel) {
        do {
            try db.collection(collection).document(item.id).setData(from: item)
        } catch {
            print("❌ Fehler beim Hinzufügen des Items: \(error.localizedDescription)")
        }
    }

    /// Aktualisiert ein Item in Firestore
    func updateItem(_ item: ItemModel) {
        do {
            try db.collection(collection).document(item.id).setData(from: item, merge: true)
        } catch {
            print("❌ Fehler beim Aktualisieren des Items: \(error.localizedDescription)")
        }
    }

    /// Löscht ein Item aus Firestore
    func deleteItem(_ item: ItemModel) {
        db.collection(collection).document(item.id).delete { error in
            if let error = error {
                print("❌ Fehler beim Löschen: \(error.localizedDescription)")
            }
        }
    }
}
