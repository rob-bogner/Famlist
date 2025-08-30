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

    // Deep link pairing code (if any)
    @Published var pendingInviteCode: String?

    init(idService: UserIdService, clock: Clock = SystemClock()) {
        self.idService = idService
        self.clock = clock
        Task { await self.bootstrap() }
    }

    func bootstrap() async {
        do {
            let id = try await idService.getOrCreatePublicId()
            state = .signedIn(id)
        } catch {
            self.errorMessage = error.localizedDescription
            state = .initializing
        }
    }
}

struct SimpleError: LocalizedError { let message: String; init(_ m: String) { message = m } ; var errorDescription: String? { message } }
