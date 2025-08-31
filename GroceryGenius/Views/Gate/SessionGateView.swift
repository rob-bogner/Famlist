// SessionGateView.swift
// Extracted from original combined file. Keeps IdentifiedAlert and preview.
import SwiftUI

struct SessionGateView: View {
    @StateObject private var vm: SessionGateViewModel

    init(idService: UserIdService, listRepo: ListRepository = FirestoreListRepository(), recipeImportPresenter: RecipeImportPresenting = RecipeImportPresenter()) {
        _vm = StateObject(wrappedValue: SessionGateViewModel(idService: idService, listRepo: listRepo, recipeImportPresenter: recipeImportPresenter))
    }

    var body: some View {
        Group {
            switch vm.sessionState {
            case .initializing:
                ProgressView().controlSize(.large)
            case .signedIn(let pubId):
                HomeView(publicId: pubId, onImport: { vm.presentImport() })
            }
        }
        .alert(item: Binding(get: {
            if let msg = vm.errorMessage { return IdentifiedAlert(message: msg) }
            return nil
        }, set: { _ in vm.errorMessage = nil })) { ia in
            Alert(title: Text("Error"), message: Text(ia.message), dismissButton: .default(Text("OK")))
        }
    }
}

// Keep internal for cross-file alert binding
struct IdentifiedAlert: Identifiable { let id = UUID(); let message: String }

#Preview {
    SessionGateView(idService: PreviewUserIdService(), listRepo: PreviewListRepository(), recipeImportPresenter: PreviewImportPresenter())
        .environmentObject(makePreviewListVM())
}
