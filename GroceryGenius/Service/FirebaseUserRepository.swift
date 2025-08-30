// MARK: - FirestoreUserRepository
import Foundation
@preconcurrency import FirebaseFirestore
import CryptoKit

final class FirestoreUserRepository: UserRepository {
    private let db = Firestore.firestore()
    private let users = "users"
    private let authMap = "authMap"

    func lookupPublicId(forAuthUid uid: String) async throws -> PublicUserId? {
        let key = sha256Hex(uid)
        let snap = try await db.collection(authMap).document(key).getDocument()
        guard let data = snap.data(), let value = data["publicUserId"] as? String else { return nil }
        return PublicUserId(value)
    }

    func mapAuthUid(_ uid: String, to publicId: PublicUserId) async throws {
        let key = sha256Hex(uid)
        try await db.collection(authMap).document(key).setData(["publicUserId": publicId.value])
    }

    func reservePublicId(_ id: PublicUserId) async throws -> Bool {
        let doc = db.collection(users).document(id.value)
        let snap = try await doc.getDocument()
        if snap.exists { return false }
        try await doc.setData(["createdAt": FieldValue.serverTimestamp(), "status": "active"])
        return true
    }

    func createProfile(_ profile: UserProfile) async throws {
        try await db.collection(users).document(profile.id).setData([
            "createdAt": Timestamp(date: profile.createdAt),
            "status": profile.status.rawValue
        ], merge: true)
    }

    func getProfile(id: PublicUserId) async throws -> UserProfile? {
        let snap = try await db.collection(users).document(id.value).getDocument()
        guard let data = snap.data() else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let statusRaw = data["status"] as? String ?? UserStatus.active.rawValue
        return UserProfile(id: id.value, createdAt: createdAt, status: UserStatus(rawValue: statusRaw) ?? .active)
    }

    func deleteAccount(forAuthUid uid: String, publicId: PublicUserId) async throws {
        let batch = db.batch()
        // Delete user profile
        let userDoc = db.collection(users).document(publicId.value)
        batch.deleteDocument(userDoc)
        // Delete auth map entry
        let mapDoc = db.collection(authMap).document(sha256Hex(uid))
        batch.deleteDocument(mapDoc)
        // Collect lists owned by user (scoped via ownerPublicId)
        let owned = try await db.collection("lists").whereField("ownerPublicId", isEqualTo: publicId.value).getDocuments()
        for doc in owned.documents { batch.deleteDocument(doc.reference) }
        // Remove user from sharedWith arrays of other lists
        let shared = try await db.collection("lists").whereField("sharedWith", arrayContains: publicId.value).getDocuments()
        for doc in shared.documents { batch.updateData(["sharedWith": FieldValue.arrayRemove([publicId.value])], forDocument: doc.reference) }
        // Delete pairing requests involving user
        let reqFrom = try await db.collection("pairingRequests").whereField("from", isEqualTo: publicId.value).getDocuments()
        for doc in reqFrom.documents { batch.deleteDocument(doc.reference) }
        let reqTo = try await db.collection("pairingRequests").whereField("to", isEqualTo: publicId.value).getDocuments()
        for doc in reqTo.documents { batch.deleteDocument(doc.reference) }
        // Delete pairs containing user
        let p1 = try await db.collection("pairs").whereField("a", isEqualTo: publicId.value).getDocuments()
        for doc in p1.documents { batch.deleteDocument(doc.reference) }
        let p2 = try await db.collection("pairs").whereField("b", isEqualTo: publicId.value).getDocuments()
        for doc in p2.documents { batch.deleteDocument(doc.reference) }
        // Commit
        try await batch.commit()
    }

    private func sha256Hex(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
