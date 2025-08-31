// HomeView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct HomeView: View {
    enum Section { case lists, settings }
    let publicId: PublicUserId
    let onImport: () -> Void
    @State private var section: Section = .lists
    @EnvironmentObject private var listViewModel: ListViewModel

    var body: some View {
        Group {
            switch section {
            case .lists:
                ShoppingListView()
                    .overlay(alignment: .topTrailing) {
                        HamburgerMenuButton(section: $section, onImport: onImport)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
            case .settings:
                NavigationStack {
                    SettingsView(publicId: publicId)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { HamburgerMenuButton(section: $section, onImport: onImport) } }
                }
            }
        }
        .onAppear { listViewModel.configure(publicId: publicId, listId: "default") }
    }
}

#if DEBUG
#Preview("Home – Lists (Light)") {
    HomeView(publicId: PreviewData.publicId, onImport: {})
        .environmentObject(makePreviewListVM())
}
#Preview("Home – Lists (Dark)") {
    HomeView(publicId: PreviewData.publicId, onImport: {})
        .environmentObject(makePreviewListVM())
        .preferredColorScheme(.dark)
}
#endif
