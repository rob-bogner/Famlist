// HomeView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct HomeView: View {
    enum Section { case lists, pairing, settings }
    let publicId: PublicUserId
    @Binding var pendingInviteCode: String?
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
            case .pairing:
                PairingHostView(publicId: publicId, pendingInviteCode: $pendingInviteCode) {
                    HamburgerMenuButton(section: $section, onImport: onImport)
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
        .onChange(of: pendingInviteCode) { _, new in
            if let code = new, !code.isEmpty { section = .pairing }
        }
    }
}

#if DEBUG
#Preview("Home – Lists (Light)") {
    HomeView(publicId: PreviewData.publicId, pendingInviteCode: .constant(nil), onImport: {})
        .environmentObject(makePreviewListVM())
}
#Preview("Home – Lists (Dark)") {
    HomeView(publicId: PreviewData.publicId, pendingInviteCode: .constant(nil), onImport: {})
        .environmentObject(makePreviewListVM())
        .preferredColorScheme(.dark)
}
#Preview("Home – Pairing (pending code)") {
    HomeView(publicId: PreviewData.publicId, pendingInviteCode: .constant("ABCD1"), onImport: {})
        .environmentObject(makePreviewListVM())
}
#endif
