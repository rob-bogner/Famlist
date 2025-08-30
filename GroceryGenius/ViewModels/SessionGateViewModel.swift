// filepath: GroceryGenius/ViewModels/SessionGateViewModel.swift
// MARK: - SessionGateViewModel

import Foundation
import Combine

protocol RecipeImportPresenting {
    func presentImport()
}

@MainActor
final class SessionGateViewModel: ObservableObject {
    enum Section { case lists, pairing, settings }

    // Exposed state for the View
    @Published private(set) var sessionState: SessionViewModel.State = .initializing
    @Published var errorMessage: String?
    @Published var pendingInviteCode: String?
    @Published var section: Section = .lists

    // Dependencies
    private let sessionVM: SessionViewModel
    private let recipeImportPresenter: RecipeImportPresenting

    private var cancellables: Set<AnyCancellable> = []

    init(idService: UserIdService, listRepo: ListRepository, recipeImportPresenter: RecipeImportPresenting) {
        self.sessionVM = SessionViewModel(idService: idService, listRepo: listRepo)
        self.recipeImportPresenter = recipeImportPresenter
        bindSession()
    }

    private func bindSession() {
        // Bridge inner session VM state outward in a lightweight way
        sessionVM.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.sessionState = $0 }
            .store(in: &cancellables)

        sessionVM.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.errorMessage = $0 }
            .store(in: &cancellables)

        sessionVM.$pendingInviteCode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] code in
                self?.pendingInviteCode = code
                // Navigation decision: jump to pairing if a code arrives
                if let c = code, !c.isEmpty { self?.section = .pairing }
            }
            .store(in: &cancellables)
    }

    // MARK: - Intents
    func handleOpenURL(_ url: URL) {
        // Delegate deep link parsing to the same helper
        if let code = DeepLinkParser.pairCode(from: url) {
            pendingInviteCode = code
        }
    }

    func presentImport() {
        recipeImportPresenter.presentImport()
    }
}
