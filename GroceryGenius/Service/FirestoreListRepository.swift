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

    // NEW: Fetch single list
    func getList(for owner: PublicUserId, listId: String) async throws -> GroceryList {
        let doc = try await db.collection(collection).document(listId).getDocument()
        guard let data = doc.data(), let list = Self.decodeRaw(id: doc.documentID, data: data) else { throw ItemsRepositoryError.notFound }
        guard list.ownerPublicId == owner.value else { throw ItemsRepositoryError.notFound }
        return list
    }

    // NEW: Shared lists support (we use a top-level collection shared_lists due to Firestore path constraints)
    private var sharedLists: CollectionReference { db.collection("shared_lists") }

    func createSharedList(owners: [PublicUserId]) async throws -> SharedList {
        let id = UUID().uuidString
        let shared = SharedList(id: id, owners: owners.map { $0.value }, createdAt: Date())
        try await sharedLists.document(id).setData([
            "owners": shared.owners,
            "createdAt": Timestamp(date: shared.createdAt)
        ])
        return shared
    }

    func attachListToShared(owner: PublicUserId, listId: String, sharedId: String) async throws {
        try await db.collection(collection).document(listId).setData([
            "sharedListId": sharedId,
            "ownerPublicId": owner.value
        ], merge: true)
    }

    func getSharedList(by id: String) async throws -> SharedList? {
        let doc = try await sharedLists.document(id).getDocument()
        guard let data = doc.data() else { return nil }
        let owners = data["owners"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return SharedList(id: doc.documentID, owners: owners, createdAt: createdAt)
    }

    private static func encode(_ list: GroceryList) -> [String: Any] {
        var dict: [String: Any] = [
            "ownerPublicId": list.ownerPublicId,
            "name": list.name,
            "items": list.items.map { [
                "id": $0.id, "title": $0.title, "qty": $0.qty, "unit": $0.unit, "checked": $0.checked
            ] },
            // Keep sharedWith for compatibility with existing UI; not used for scoping
            "sharedWith": Array(list.sharedWith.map { $0.value })
        ]
        if let sid = list.sharedListId { dict["sharedListId"] = sid }
        return dict
    }
    private static func decode(doc: QueryDocumentSnapshot) -> GroceryList? {
        decodeRaw(id: doc.documentID, data: doc.data())
    }
    private static func decodeRaw(id: String, data: [String: Any]) -> GroceryList? {
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
        let sharedListId = data["sharedListId"] as? String
        return GroceryList(id: id, owner: PublicUserId(ownerPid), name: name, items: items, sharedWith: shared, ownerPublicId: ownerPid, sharedListId: sharedListId)
    }
}
