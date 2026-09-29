/*
 View+ActionCard.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - `.actionCard(isPresented:k:content:)` – zeigt eine Aktionskarte statt `.confirmationDialog` / `.alert`.

 🔰 Notes for Beginners:
 - Technik: durchsichtiges fullScreenCover ohne System-Animation (Transaction.disablesAnimations);
   Ein- und Ausblenden übernimmt ActionCardHost selbst.
 - Ablauf beim Schließen: Karte blendet aus → `isPresented = false` → Cover weg → erst DANN läuft die
   Knopf-Aktion (onDismiss). So kann eine Aktion gefahrlos ein Sheet (z. B. Bildauswahl) öffnen.
 - `content` wird bei jedem Neuzeichnen gelesen (live, z. B. Eingabefeld); liefert es nil, zeigt die
   Bühne nichts mehr.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension View {
    /// Presents an action card (our replacement for confirmation dialogs and alerts).
    func actionCard(isPresented: Binding<Bool>, k: SheetTheme,
                    content: @escaping () -> ActionCardContent?) -> some View {
        modifier(ActionCardPresenter(isPresented: isPresented, k: k, content: content))
    }
}

/// Drives the transparent full-screen cover that hosts an action card.
private struct ActionCardPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let k: SheetTheme
    let content: () -> ActionCardContent?

    @State private var coverShown = false
    @State private var pending: (() -> Void)?

    func body(content view: Content) -> some View {
        view
            .fullScreenCover(isPresented: $coverShown, onDismiss: runPending) {
                ActionCardHost(k: k, content: isPresented ? content() : nil) { then in
                    pending = then
                    isPresented = false
                }
                .presentationBackground(.clear)
            }
            .onChange(of: isPresented) { _, shown in
                if shown != coverShown { setCover(shown) }
            }
            .onAppear {
                if isPresented { setCover(true) }
            }
    }

    private func setCover(_ shown: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { coverShown = shown }
    }

    private func runPending() {
        let action = pending
        pending = nil
        action?()
    }
}
