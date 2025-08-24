// MARK: - FirestoreListRepository (proper file)
import Foundation
@preconcurrency import FirebaseFirestore

final class FirestoreListRepository: ListRepository {
    private let db = Firestore.firestore()
    private let collection = "lists"

    func observeLists(for owner: PublicUserId) -> AsyncStream<[GroceryList]> {
        let ownerId = owner.value
        return AsyncStream { continuation in
            var snapshots: [String: [GroceryList]] = [:]
            func emit() {
                let combined = Array(snapshots.values).flatMap { $0 }
                continuation.yield(dedup(combined))
            }
            let ownedListener = db.collection(collection).whereField("owner", isEqualTo: ownerId)
                .addSnapshotListener { snap, _ in
                    let lists = snap?.documents.compactMap { Self.decode(doc: $0) } ?? []
                    snapshots["owned"] = lists
                    emit()
                }
            let sharedListener = db.collection(collection).whereField("sharedWith", arrayContains: ownerId)
                .addSnapshotListener { snap, _ in
                    let lists = snap?.documents.compactMap { Self.decode(doc: $0) } ?? []
                    snapshots["shared"] = lists
                    emit()
                }
            continuation.onTermination = { _ in ownedListener.remove(); sharedListener.remove() }
        }
    }

    func createList(_ list: GroceryList) async throws {
        try await db.collection(collection).document(list.id).setData(Self.encode(list))
    }
    func updateList(_ list: GroceryList) async throws {
        try await db.collection(collection).document(list.id).setData(Self.encode(list), merge: true)
    }
    func deleteList(id: String) async throws { try await db.collection(collection).document(id).delete() }

    private static func encode(_ list: GroceryList) -> [String: Any] {
        [
            "owner": list.owner.value,
            "name": list.name,
            "items": list.items.map { ["id": $0.id, "title": $0.title, "qty": $0.qty, "unit": $0.unit, "checked": $0.checked] },
            "sharedWith": Array(list.sharedWith.map { $0.value })
        ]
    }
    private static func decode(doc: QueryDocumentSnapshot) -> GroceryList? {
        let data = doc.data()
        guard let owner = data["owner"] as? String, let name = data["name"] as? String else { return nil }
        let itemsArr = data["items"] as? [[String: Any]] ?? []
        let items: [GroceryItem] = itemsArr.compactMap { item in
            guard let id = item["id"] as? String, let title = item["title"] as? String else { return nil }
            let qty = item["qty"] as? Double ?? 1
            let unit = item["unit"] as? String ?? ""
            let checked = item["checked"] as? Bool ?? false
            return GroceryItem(id: id, title: title, qty: qty, unit: unit, checked: checked)
        }
        let shared = Set((data["sharedWith"] as? [String] ?? []).map(PublicUserId.init))
        return GroceryList(id: doc.documentID, owner: PublicUserId(owner), name: name, items: items, sharedWith: shared)
    }
    private func dedup(_ lists: [GroceryList]) -> [GroceryList] {
        var seen = Set<String>()
        var result: [GroceryList] = []
        for l in lists { if !seen.contains(l.id) { seen.insert(l.id); result.append(l) } }
        return result
    }
}
