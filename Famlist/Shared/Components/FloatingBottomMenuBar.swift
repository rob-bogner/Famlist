/*
 FloatingBottomMenuBar.swift

 Famlist
 Created on: 01.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schwebende Menüleiste am unteren Bildschirmrand im dunklen Pill-Design.
 - Zentraler Add-Button hervorgehoben (erhaben, Accent-Farbe).

 🛠 Includes:
 - Toggle All Button (alle abhaken / alle zurücksetzen)
 - Sort-Menü mit verschiedenen Sortieroptionen
 - Erhabener zentraler Add-Button (Accent-Farbe)
 - Clipboard-Import Button
 - Hamburger-Menü (Profil, Abmelden)

 🔰 Notes for Beginners:
 - Dunkles Pill (Capsule) mit festem Farbwert, funktioniert in Light & Dark Mode.
 - Zentraler Button überragt das Pill via negativem Y-Offset in einem ZStack.
 - onAddTap-Closure wird von ShoppingListView übergeben.

 📝 Last Change:
 - Komplett neu nach dunklem Pill-Design (Screenshot-Referenz).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Schwebende Menüleiste am unteren Bildschirmrand mit dunklem Pill und erhabenem Mitte-Button.
struct FloatingBottomMenuBar: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var session: AppSessionViewModel

    /// Wird aufgerufen wenn der zentrale Add-Button getippt wird.
    var onAddTap: () -> Void

    @State private var showProfileView = false
    @State private var showImportView = false

    private var allChecked: Bool {
        !listViewModel.items.isEmpty && listViewModel.items.allSatisfy { $0.isChecked }
    }

    var body: some View {
        ZStack {
            pill
            centerButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .sheet(isPresented: $showProfileView) {
            if let profile = session.currentProfile {
                ProfileView(profile: profile)
                    .environmentObject(session)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showImportView) {
            ClipboardImportView()
                .environmentObject(listViewModel)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: 0) {
            // 1. Toggle All
            pillButton(
                icon: allChecked ? "checkmark.circle.fill" : "circle",
                label: allChecked ? "Alle zurücksetzen" : "Alle abhaken"
            ) {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    listViewModel.toggleAllItems()
                }
            }

            Spacer()

            // 2. Sort Menu
            Menu {
                Button {
                    listViewModel.setSortOrder(.category)
                } label: {
                    Label("Nach Kategorie", systemImage: "square.grid.2x2")
                }
                Button {
                    listViewModel.setSortOrder(.alphabetical)
                } label: {
                    Label("Alphabetisch", systemImage: "textformat")
                }
                Button {
                    listViewModel.setSortOrder(.dateAdded)
                } label: {
                    Label("Nach Datum", systemImage: "calendar")
                }
            } label: {
                pillIcon(icon: "arrow.up.arrow.down", label: "Sortieren")
            }
            .buttonStyle(PillButtonStyle())

            Spacer()

            // Platzhalter für erhabenen Mitte-Button
            Spacer().frame(width: 64)

            Spacer()

            // 4. Clipboard Import
            pillButton(icon: "doc.on.clipboard", label: "Importieren") {
                showImportView = true
            }

            Spacer()

            // 5. Hamburger Menu
            Menu {
                Button {
                    showProfileView = true
                } label: {
                    Label(String(localized: "menu.profile"), systemImage: "person.circle")
                }
                Divider()
                Button(role: .destructive) {
                    session.signOut()
                } label: {
                    Label(String(localized: "auth.signout.button"), systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                pillIcon(icon: "line.3.horizontal", label: "Menü")
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background {
            Capsule()
                .fill(Color.theme.card)
                .overlay(Capsule().strokeBorder(Color.theme.accent, lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        }
    }

    // MARK: - Center Button

    private var centerButton: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onAddTap()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 78, height: 78)
                .background(Circle().fill(Color.theme.accent))
                .shadow(color: Color.theme.accent.opacity(0.45), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(CenterButtonStyle())
    }

    // MARK: - Helpers

    /// Einfacher Tap-Button für das Pill.
    private func pillButton(
        icon: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            pillIcon(icon: icon, label: label)
        }
        .buttonStyle(PillButtonStyle())
    }

    /// Icon-View innerhalb des Pills.
    private func pillIcon(icon: String, label: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundColor(Color.theme.textColor)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
    }
}

// MARK: - Button Styles

/// Press-Feedback für Pill-Buttons (Scale + Opacity).
private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Press-Feedback für den erhabenen Mitte-Button.
private struct CenterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    let sessionVM = AppSessionViewModel(
        client: nil,
        profiles: PreviewProfilesRepository(),
        lists: PreviewListsRepository(),
        listViewModel: listVM
    )

    ZStack {
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()
            FloatingBottomMenuBar(onAddTap: {})
                .environmentObject(listVM)
                .environmentObject(sessionVM)
        }
    }
}
