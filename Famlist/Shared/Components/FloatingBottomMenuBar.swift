/*
 FloatingBottomMenuBar.swift
 
 Famlist
 Created on: 22.11.2025
 
 ------------------------------------------------------------------------
 📄 File Overview:
 - Schwebende Menüleiste am unteren Bildschirmrand mit Apple Glass-Optik (visionOS-inspiriert).
 
 🛠 Includes:
 - Check/Uncheck all Button
 - Sort-Menü mit verschiedenen Sortieroptionen
 - Hamburger-Menü mit App-Aktionen
 
 🔰 Notes for Beginners:
 - Verwendet .ultraThinMaterial mit Capsule-Form für Frosted Glass Look
 - Subtile weiße Kontur und weicher Schatten für Tiefe
 - Buttons mit Touch Targets ≥44pt und visuellem Feedback
 - Horizontal zentriert und gleichmäßig verteilt
 
 📝 Last Change:
 - Komplett überarbeitet nach visionOS Glass Design Guidelines
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Schwebende Menüleiste am unteren Bildschirmrand mit visionOS-inspiriertem Glas-Look
struct FloatingBottomMenuBar: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var session: AppSessionViewModel
    
    @State private var showProfileView: Bool = false
    @State private var showImportView: Bool = false
    
    // Berechne ob alle Items gecheckt sind
    private var allItemsChecked: Bool {
        !listViewModel.items.isEmpty && listViewModel.items.allSatisfy { $0.isChecked }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Links: Check/Uncheck All Button
            menuButton(
                icon: allItemsChecked ? "checkmark.circle.fill" : "circle",
                accessibilityLabel: allItemsChecked ? "Alle Abhaken" : "Alle Markieren"
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    listViewModel.toggleAllItems()
                }
            }
            
            Spacer()
            
            // Optionaler subtiler Divider
            divider
            
            Spacer()
            
            // Mitte: Sort Menu
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
                menuButtonContent(
                    icon: "arrow.up.arrow.down",
                    accessibilityLabel: "Sortieren"
                )
            }
            
            Spacer()
            
            // Optionaler subtiler Divider
            divider
            
            Spacer()
            
            // Rechts: Hamburger Menu
            Menu {
                Button {
                    showProfileView = true
                } label: {
                    Label(String(localized: "menu.profile"), systemImage: "person.circle")
                }
                
                Button {
                    showImportView = true
                } label: {
                    Label(String(localized: "menu.import"), systemImage: "doc.on.clipboard")
                }
                
                Divider()
                
                Button(role: .destructive) {
                    session.signOut()
                } label: {
                    Label(String(localized: "auth.signout.button"), systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                menuButtonContent(
                    icon: "line.3.horizontal",
                    accessibilityLabel: "Menü"
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background {
            // Frosted Glass Container mit Capsule-Form
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    // Subtile weiße Kontur für Tiefe
                    Capsule()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .sheet(isPresented: $showProfileView) {
            if let profile = session.currentProfile {
                ProfileView(profile: profile)
                    .environmentObject(session)
                    .presentationDragIndicator(.visible)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showImportView) {
            ClipboardImportView()
                .environmentObject(listViewModel)
                .presentationDragIndicator(.visible)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    // MARK: - Button Components
    
    /// Erstellt einen interaktiven Button mit visuellem Feedback
    private func menuButton(
        icon: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            menuButtonContent(icon: icon, accessibilityLabel: accessibilityLabel)
        }
        .buttonStyle(GlassButtonStyle())
    }
    
    /// Erstellt den Button-Inhalt (Icon in Touch Target)
    private func menuButtonContent(
        icon: String,
        accessibilityLabel: String
    ) -> some View {
        Image(systemName: icon)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.85))
            .frame(width: 44, height: 44) // Min. Touch Target 44pt
            .contentShape(Rectangle())
            .accessibilityLabel(accessibilityLabel)
    }
    
    /// Subtiler vertikaler Divider zwischen Buttons
    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 24)
    }
}

// MARK: - Glass Button Style

/// Button Style mit visuellem Feedback (Scale + Opacity)
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
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
    
    return ZStack {
        // Gradient Background für besseren Glass-Effekt
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack {
            Spacer()
            FloatingBottomMenuBar()
                .environmentObject(listVM)
                .environmentObject(sessionVM)
        }
    }
}

