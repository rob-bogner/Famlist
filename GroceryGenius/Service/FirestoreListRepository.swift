// MARK: - FirestoreListRepository (proper file)
import Foundation
@preconcurrency import FirebaseFirestore

final class FirestoreListRepository: ListRepository {
    private let db = Firestore.firestore()
    private let collection = "lists"

    func observeLists(for owner: PublicUserId) -> AsyncStream<[GroceryList]> {
        let ownerId = owner.value
        return AsyncStream { continuation in
            let listener = db.collection(collection).whereField("ownerPublicId", isEqualTo: ownerId)
                .addSnapshotListener { snap, _ in
                    let lists = snap?.documents.compactMap { Self.decode(doc: $0) } ?? []
                    continuation.yield(lists)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func createList(_ list: GroceryList) async throws {
        try await db.collection(collection).document(list.id).setData(Self.encode(list))
    }
    func updateList(_ list: GroceryList) async throws {
        try await db.collection(collection).document(list.id).setData(Self.encode(list), merge: true)
    }
    func deleteList(id: String) async throws { try await db.collection(collection).document(id).delete() }

    func ensureDefaultList(for owner: PublicUserId) async throws {
        let defaultId = "default"
        let doc = db.collection(collection).document(defaultId)
        let snap = try await doc.getDocument()
        if snap.exists { return }
        let list = GroceryList(id: defaultId, owner: owner, name: "My List")
        try await doc.setData(Self.encode(list))
    }

    private static func encode(_ list: GroceryList) -> [String: Any] {
        [
            "ownerPublicId": list.ownerPublicId,
            "name": list.name,
            "items": list.items.map { [
                "id": $0.id, "title": $0.title, "qty": $0.qty, "unit": $0.unit, "checked": $0.checked
            ] },
            // Keep sharedWith for compatibility with existing UI; not used for scoping
            "sharedWith": Array(list.sharedWith.map { $0.value })
        ]
    }
    private static func decode(doc: QueryDocumentSnapshot) -> GroceryList? {
        let data = doc.data()
        guard let ownerPid = data["ownerPublicId"] as? String, let name = data["name"] as? String else { return nil }
        let itemsArr = data["items"] as? [[String: Any]] ?? []
        let items: [GroceryItem] = itemsArr.compactMap { item in
            guard let id = item["id"] as? String, let title = item["title"] as? String else { return nil }
            let qty = item["qty"] as? Double ?? 1
            let unit = item["unit"] as? String ?? ""
            let checked = item["checked"] as? Bool ?? false
            return GroceryItem(id: id, title: title, qty: qty, unit: unit, checked: checked)
        }
        let shared = Set((data["sharedWith"] as? [String] ?? []).map(PublicUserId.init))
        return GroceryList(id: doc.documentID, owner: PublicUserId(ownerPid), name: name, items: items, sharedWith: shared, ownerPublicId: ownerPid)
    }
}
