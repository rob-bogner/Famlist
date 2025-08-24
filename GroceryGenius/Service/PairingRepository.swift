// MARK: - PairingRepository Protocol (PII-free)
import Foundation

protocol PairingRepository {
    // Invite code generation and observation
    func generateInviteCode(for user: PublicUserId) async throws -> String
    func observeIncomingRequests(for user: PublicUserId) -> AsyncStream<[PairingRequest]>

    // Lifecycle
    func createRequest(_ request: PairingRequest) async throws
    func updateRequest(_ request: PairingRequest) async throws

    // Partners
    func addPair(a: PublicUserId, b: PublicUserId) async throws
    func listPartners(of user: PublicUserId) async throws -> [PublicUserId]
}
