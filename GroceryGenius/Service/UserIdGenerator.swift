// MARK: - UserIdGenerator
// Deterministic, human-readable, non-PII ID generator: gg-<adj>-<color>-<number>
// Uses HMAC-SHA256 seeded by auth.uid for determinism with retry for uniqueness.

import Foundation
import CryptoKit

struct UserIdGenerator: Sendable {
    private static let adjectives: [String] = [
        "brisk","calm","bright","clever","swift","merry","noble","brave",
        "quiet","rapid","vivid","eager","gentle","bold","keen","lively",
        "proud","ready","sharp","steady","tidy","trusty","witty","zesty",
        "able","agile","apt","breezy","chill","daring","elegant","fair",
        "glad","humble","jolly","kind","light","neat","plucky","prime",
        "sincere","true","upbeat","warm","worthy","young","zen","solid",
        "spry","snug","stout","sturdy","sunny","tidy","brilliant","steadfast",
        "valiant","vibrant","nimble","sprightly","resolute","serene","tacit"
    ]
    private static let colors: [String] = [
        "red","blue","green","yellow","purple","orange","teal","magenta",
        "azure","violet","indigo","crimson","scarlet","amber","gold","silver",
        "bronze","black","white","gray","charcoal","cyan","mint","navy",
        "olive","peach","plum","rose","salmon","taupe","umber","violet",
        "aqua","beige","coral","fuchsia","ivory","jade","khaki","lavender",
        "maroon","mustard","ochre","periwinkle","ruby","saffron","sepia","slate",
        "steel","terracotta","turquoise","ultramarine","vermilion","wisteria","zinc",
        "sand","sky","sea","forest","sunset","dawn","dusk","ember"
    ]
    private let repo: UserRepository

    init(repo: UserRepository) { self.repo = repo }

    func publicId(for uid: String) async throws -> PublicUserId {
        let seed = hmacSeed(uid: uid)
        // Try up to 8 variants by tweaking the counter
        for counter in 0..<8 {
            let comp = components(seed: seed, counter: counter)
            let candidate = PublicUserId("gg-\(comp.adj)-\(comp.color)-\(comp.number)")
            if try await repo.reservePublicId(candidate) { return candidate }
        }
        // Fallback random if collisions persist
        var rng = SystemRandomNumberGenerator()
        let adj = Self.adjectives.randomElement(using: &rng) ?? "able"
        let col = Self.colors.randomElement(using: &rng) ?? "blue"
        let num = Int.random(in: 1000...9999, using: &rng)
        let fallback = PublicUserId("gg-\(adj)-\(col)-\(num)")
        _ = try? await repo.reservePublicId(fallback)
        return fallback
    }

    private func hmacSeed(uid: String) -> Data {
        // Deterministic seed from uid using an app-scoped key (static string suffices; no secret derivation from device)
        let key = SymmetricKey(data: Data("gg-seed-key".utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(uid.utf8), using: key)
        return Data(mac)
    }

    private func components(seed: Data, counter: Int) -> (adj: String, color: String, number: Int) {
        // Expand seed with counter and map to indices
        var data = seed
        data.append(contentsOf: withUnsafeBytes(of: counter.bigEndian, Array.init))
        let digest = SHA256.hash(data: data)
        let bytes = Array(digest)
        func idx(_ start: Int, modulo: Int) -> Int { Int(UInt16(bytes[start]) << 8 | UInt16(bytes[start+1])) % modulo }
        let a = Self.adjectives[idx(0, modulo: Self.adjectives.count)]
        let c = Self.colors[idx(2, modulo: Self.colors.count)]
        // Number: 4 digits from bytes[4..7]
        let raw = Int(UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 8 | UInt32(bytes[7]))
        let n = 1000 + abs(raw) % 9000
        return (a, c, n)
    }
}
