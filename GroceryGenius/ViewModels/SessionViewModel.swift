// MARK: - SessionViewModel
// Handles onboarding/auth and provisioning of PublicUserId.

import Foundation

@MainActor
final class SessionViewModel: ObservableObject {
    enum State: Equatable { case initializing, signedIn(PublicUserId) }

    @Published private(set) var state: State = .initializing
    @Published var errorMessage: String?

    private let idService: UserIdService
    private let clock: Clock
    private let listRepo: ListRepository

    // Deep link pairing code (if any)
    @Published var pendingInviteCode: String?

    init(idService: UserIdService, listRepo: ListRepository, clock: Clock = SystemClock()) {
        self.idService = idService
        self.listRepo = listRepo
        self.clock = clock
        Task { await self.bootstrap() }
    }

    func bootstrap() async {
        do {
            let id = try await idService.getOrCreatePublicId()
            // Ensure exactly one default list for this user (idempotent)
            do { try await listRepo.ensureDefaultList(for: id) } catch { self.errorMessage = error.localizedDescription }
            state = .signedIn(id)
        } catch {
            self.errorMessage = error.localizedDescription
            state = .initializing
        }
    }
}

struct SimpleError: LocalizedError { let message: String; init(_ m: String) { message = m } ; var errorDescription: String? { message } }
