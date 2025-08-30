// filepath: GroceryGenius/Service/IdAllocationRepository.swift
// MARK: - IdAllocationRepository
// Provides atomic allocation of public user ids "genius-<n>" using Firestore transactions.

import Foundation
@preconcurrency import FirebaseFirestore

protocol IdAllocationRepository: Sendable {
    /// Atomically allocate a new public id. Optionally include a deviceKey for audit mapping.
    func allocatePublicId(deviceKey: String?) async throws -> PublicUserId
}

struct FirestoreIdAllocationRepository: IdAllocationRepository {
    private let db = Firestore.firestore()
    private let counters = "counters"
    private let allocations = "allocations"
    private let counterDocId = "publicId"

    func allocatePublicId(deviceKey: String?) async throws -> PublicUserId {
        let counterRef = db.collection(counters).document(counterDocId)
        let anyResult = try await db.runTransaction { (txn, _) -> Any? in
            let snap = try? txn.getDocument(counterRef)
            let current = (snap?.data()? ["next"] as? NSNumber)?.intValue ?? 0
            let next = current + 1
            // Update next pointer
            if snap?.exists == true {
                txn.updateData(["next": next], forDocument: counterRef)
            } else {
                txn.setData(["next": next], forDocument: counterRef)
            }
            return next
        }
        let number: Int
        if let n = anyResult as? Int { number = n } else if let n = (anyResult as? NSNumber)?.intValue { number = n } else { throw SimpleError("Allocation transaction failed") }
        let id = PublicUserId("genius-\(number)")
        // Optional: write allocation audit document (best-effort; do not wrap in the same transaction)
        var audit: [String: Any] = [
            "createdAt": FieldValue.serverTimestamp(),
            "counter": number
        ]
        if let dk = deviceKey { audit["deviceKey"] = dk }
        try? await db.collection(allocations).document(id.value).setData(audit, merge: true)
        // Also ensure users profile exists
        try? await db.collection("users").document(id.value).setData([
            "createdAt": FieldValue.serverTimestamp(),
            "status": "active"
        ], merge: true)
        return id
    }
}
