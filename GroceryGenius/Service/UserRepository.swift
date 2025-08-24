// MARK: - UserRepository Protocol (PII-free)
import Foundation

protocol UserRepository: Sendable {
    // Maps auth uid -> PublicUserId
    func lookupPublicId(forAuthUid uid: String) async throws -> PublicUserId?
    func mapAuthUid(_ uid: String, to publicId: PublicUserId) async throws

    // Reserve a public id; returns true if reservation succeeded (unique)
    func reservePublicId(_ id: PublicUserId) async throws -> Bool

    // Profile lifecycle
    func createProfile(_ profile: UserProfile) async throws
    func getProfile(id: PublicUserId) async throws -> UserProfile?

    // Account deletion (remove profile, auth map, lists, pairs, pairing requests)
    func deleteAccount(forAuthUid uid: String, publicId: PublicUserId) async throws
}
