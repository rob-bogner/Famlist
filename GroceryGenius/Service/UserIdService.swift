// MARK: - UserIdService
// Provides creation and retrieval of the app's user identifier ("genius-<n>").
// New unified API getOrCreatePublicId() with backward-compat getOrCreateUserId().

import Foundation
@preconcurrency import FirebaseFirestore

protocol UserIdService: Sendable {
    // Preferred API: returns local id if present; otherwise provisions a new id (atomically) and returns it.
    func getOrCreatePublicId() async throws -> PublicUserId
    // Backward-compat: default forwards to getOrCreatePublicId()
    func getOrCreateUserId() async throws -> PublicUserId
    // Returns local id if one exists.
    func currentLocalId() -> PublicUserId?
}

extension UserIdService {
    func getOrCreateUserId() async throws -> PublicUserId { try await getOrCreatePublicId() }
}

// Legacy implementation kept for reference; not used by app wiring anymore.
final class FirestoreUserIdService: UserIdService {
    private let db = Firestore.firestore()
    private let counters = "counters"
    private let users = "users"
    private let localKey = "gg.userId"

    func currentLocalId() -> PublicUserId? {
        if let raw = UserDefaults.standard.string(forKey: localKey), !raw.isEmpty { return PublicUserId(raw) }
        return nil
    }

    func getOrCreatePublicId() async throws -> PublicUserId {
        if let existing = currentLocalId() { return existing }
        let nextNumber = try await nextCounterValue()
        let id = "genius-\(nextNumber)"
        // Persist in Firestore profile
        try await db.collection(users).document(id).setData([
            "createdAt": FieldValue.serverTimestamp(),
            "status": "active"
        ], merge: true)
        // Persist locally
        UserDefaults.standard.set(id, forKey: localKey)
        return PublicUserId(id)
    }

    // Back-compat name
    func getOrCreateUserId() async throws -> PublicUserId { try await getOrCreatePublicId() }

    private func nextCounterValue() async throws -> Int {
        let ref = db.collection(counters).document("users")
        let anyResult = try await db.runTransaction { (txn, _) -> Any? in
            let snap = try? txn.getDocument(ref)
            if let snap, snap.exists, let data = snap.data(), let current = (data["value"] as? NSNumber)?.intValue {
                let next = current + 1
                txn.updateData(["value": FieldValue.increment(Int64(1))], forDocument: ref)
                return next
            } else {
                // Initialize counter at 1 if missing
                txn.setData(["value": 1], forDocument: ref)
                return 1
            }
        }
        if let number = anyResult as? Int { return number }
        if let num = anyResult as? NSNumber { return num.intValue }
        throw SimpleError("Counter transaction failed")
    }
}
