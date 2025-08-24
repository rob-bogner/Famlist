// MARK: - FirebasePairingRepository
import Foundation
@preconcurrency import FirebaseFirestore
import Security

final class FirebasePairingRepository: PairingRepository {
    private let db = Firestore.firestore()
    private let invites = "invites"          // invites/{code} => { owner: publicUserId, createdAt }
    private let requests = "pairingRequests" // pairingRequests/{id}
    private let pairs = "pairs"              // pairs/{id}

    func generateInviteCode(for user: PublicUserId) async throws -> String {
        // 5 random bytes -> Base32 8 chars (Crockford-like alphabet without confusing chars)
        var bytes = [UInt8](repeating: 0, count: 5)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess { bytes = (0..<5).map { _ in UInt8.random(in: 0...255) } }
        let code = base32(bytes)
        try await db.collection(invites).document(code).setData([
            "owner": user.value,
            "createdAt": FieldValue.serverTimestamp()
        ])
        return code
    }

    func observeIncomingRequests(for user: PublicUserId) -> AsyncStream<[PairingRequest]> {
        // We resolve by requests where "to" == user.value
        return AsyncStream { continuation in
            let listener = db.collection(requests).whereField("to", isEqualTo: user.value)
                .addSnapshotListener { snap, _ in
                    let results: [PairingRequest] = snap?.documents.compactMap { doc in
                        Self.decode(doc: doc)
                    } ?? []
                    continuation.yield(results)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func createRequest(_ request: PairingRequest) async throws {
        // Lookup invite target owner by code
        let invite = try await db.collection(invites).document(request.toCode).getDocument()
        guard let owner = invite.data()? ["owner"] as? String else { throw NSError(domain: "Pair", code: 404) }
        try await db.collection(requests).document(request.id).setData([
            "from": request.from.value,
            "toCode": request.toCode,
            "to": owner,
            "status": request.status.rawValue,
            "createdAt": Timestamp(date: request.createdAt)
        ])
    }

    func updateRequest(_ request: PairingRequest) async throws {
        try await db.collection(requests).document(request.id).setData([
            "status": request.status.rawValue
        ], merge: true)
    }

    func addPair(a: PublicUserId, b: PublicUserId) async throws {
        let id = [a.value, b.value].sorted().joined(separator: "-")
        try await db.collection(pairs).document(id).setData([
            "a": a.value,
            "b": b.value,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func listPartners(of user: PublicUserId) async throws -> [PublicUserId] {
        let q1 = try await db.collection(pairs).whereField("a", isEqualTo: user.value).getDocuments()
        let q2 = try await db.collection(pairs).whereField("b", isEqualTo: user.value).getDocuments()
        let p1 = q1.documents.compactMap { $0.data()["b"] as? String }
        let p2 = q2.documents.compactMap { $0.data()["a"] as? String }
        return Set(p1 + p2).map(PublicUserId.init)
    }

    private static func decode(doc: QueryDocumentSnapshot) -> PairingRequest? {
        let data = doc.data()
        guard let from = data["from"] as? String, let code = data["toCode"] as? String, let statusRaw = data["status"] as? String else { return nil }
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        return PairingRequest(id: doc.documentID, from: PublicUserId(from), toCode: code, status: PairingStatus(rawValue: statusRaw) ?? .pending, createdAt: createdAt)
    }

    // Base32 (Crockford) encode 5 bytes to 8 chars
    private func base32(_ bytes: [UInt8]) -> String {
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ") // excludes I, L, O, U
        var value: UInt64 = 0
        for b in bytes { value = (value << 8) | UInt64(b) }
        var out = ""
        for i in stride(from: 35, through: 0, by: -5) { // 40 bits -> 8 chunks of 5
            let idx = Int((value >> i) & 0x1F)
            out.append(alphabet[idx])
        }
        return out
    }
}
