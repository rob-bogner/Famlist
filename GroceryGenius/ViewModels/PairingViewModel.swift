// MARK: - PairingViewModel
import Foundation

@MainActor
final class PairingViewModel: ObservableObject {
    @Published var myId: PublicUserId
    @Published var inviteCode: String = ""
    @Published var partners: [PublicUserId] = []
    @Published var incoming: [PairingRequest] = []
    @Published var errorMessage: String?
    
    private let pairingRepo: PairingRepository
    private let clock: Clock
    private var incomingTask: Task<Void, Never>?

    init(myId: PublicUserId, pairingRepo: PairingRepository, clock: Clock = SystemClock()) {
        self.myId = myId
        self.pairingRepo = pairingRepo
        self.clock = clock
        self.reloadPartners()
        self.observeIncoming()
    }

    deinit { incomingTask?.cancel() }

    func generateInvite() async {
        do { inviteCode = try await pairingRepo.generateInviteCode(for: myId) } catch { errorMessage = error.localizedDescription }
    }

    func reloadPartners() {
        Task { [weak self] in
            guard let self else { return }
            do { self.partners = try await pairingRepo.listPartners(of: myId).sorted { $0.value < $1.value } }
            catch { self.errorMessage = error.localizedDescription }
        }
    }

    func observeIncoming() {
        incomingTask?.cancel()
        incomingTask = Task { [weak self] in
            guard let self else { return }
            for await reqs in pairingRepo.observeIncomingRequests(for: myId) {
                await MainActor.run { self.incoming = reqs.sorted { $0.createdAt > $1.createdAt } }
            }
        }
    }

    func acceptInvite(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let req = PairingRequest(id: UUID().uuidString, from: myId, toCode: trimmed, status: .pending, createdAt: clock.now())
            try await pairingRepo.createRequest(req)
        } catch { errorMessage = error.localizedDescription }
    }

    func approve(_ request: PairingRequest) async {
        do {
            try await pairingRepo.addPair(a: myId, b: request.from)
            var updated = request
            updated.status = .approved
            try await pairingRepo.updateRequest(updated)
            reloadPartners()
        } catch { errorMessage = error.localizedDescription }
    }

    func deny(_ request: PairingRequest) async {
        do {
            var updated = request
            updated.status = .denied
            try await pairingRepo.updateRequest(updated)
        } catch { errorMessage = error.localizedDescription }
    }
}
