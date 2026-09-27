/*
 DevLaunchToast.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nur DEBUG: Startargument `-devToast "Text"` zeigt den Text 4 s oben als StatusToast.

 🔰 Notes for Beginners:
 - Rückmeldung für Robert, wenn er nicht am Mac mini sitzt (z. B. „Uhr installiert“):
   xcrun devicectl device process launch --terminate-existing --device <iPhone> com.roxo.famlist -devToast "Uhr installiert"
 - Startargumente der Form `-schlüssel wert` landen in UserDefaults (Argument-Domäne).
 - Im Release-Build gibt es den Toast nicht (`#if DEBUG`).

 📝 Last Change:
 - Neu.
 ------------------------------------------------------------------------
 */

import SwiftUI

#if DEBUG
private struct DevLaunchToast: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var text = UserDefaults.standard.string(forKey: "devToast")

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let text {
                StatusToast(text: text, isError: false, appearance: Appearance(colorScheme))
                    .padding(.top, 60)
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation { self.text = nil }
                    }
            }
        }
    }
}
#endif

extension View {
    /// Entwickler-Hinweis per Startargument `-devToast` (nur DEBUG, sonst wirkungslos).
    @ViewBuilder
    func devLaunchToast() -> some View {
        #if DEBUG
        modifier(DevLaunchToast())
        #else
        self
        #endif
    }
}
