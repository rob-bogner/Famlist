// filepath: GroceryGenius/ViewModels/SessionGateViewModel.swift
// MARK: - SessionGateViewModel

import Foundation
import Combine

protocol RecipeImportPresenting {
    func presentImport()
}

@MainActor
final class SessionGateViewModel: ObservableObject {
    enum Section { case lists, settings }

    // Exposed state for the View
    @Published private(set) var sessionState: SessionViewModel.State = .initializing
    @Published var errorMessage: String?

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
    }

    // MARK: - Intents
    func presentImport() {
        recipeImportPresenter.presentImport()
    }
}
