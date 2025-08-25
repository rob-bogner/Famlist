// HamburgerMenuButton.swift
// Extracted from original SessionGateView.swift
import SwiftUI

struct HamburgerMenuButton: View {
    @Binding var section: HomeView.Section
    var onImport: () -> Void = {}
    var body: some View {
        Menu {
            Button(action: { section = .lists }) {
                Label { Text("menu.lists", tableName: "Localizable") } icon: { Image(systemName: "list.bullet") }
            }
            Button(action: { section = .pairing }) {
                Label { Text("menu.pairing", tableName: "Localizable") } icon: { Image(systemName: "person.2") }
            }
            Button(action: { section = .settings }) {
                Label { Text("menu.settings", tableName: "Localizable") } icon: { Image(systemName: "gearshape") }
            }
            // Import Recipe Keeper via VM
            Button(action: { onImport() }) {
                Label { Text("menu.importRecipeKeeper", tableName: "Localizable") } icon: { Image(systemName: "tray.and.arrow.down") }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.title3.weight(.semibold))
                .padding(10)
                .background(Circle().fill(Color.theme.accent))
                .foregroundColor(Color.theme.background)
        }
    }
}
