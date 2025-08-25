// HomeView.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct HomeView: View {
    enum Section { case lists, pairing, settings }
    let publicId: PublicUserId
    @Binding var pendingInviteCode: String?
    let onImport: () -> Void
    @State private var section: Section = .lists

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
        .onChange(of: pendingInviteCode) { _, new in
            if let code = new, !code.isEmpty { section = .pairing }
        }
    }
}
