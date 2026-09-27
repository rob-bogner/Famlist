/*
 RevealWhenFocusedModifier.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - `.revealsWhenFocused(isFocused)`: Ein Eingabefeld meldet sich, solange es fokussiert ist, bei der
   umgebenden `KeyboardRevealScrollView`. Die holt es dann über Tastatur und schwebende Knöpfe.

 🔰 Notes for Beginners:
 - Außerhalb einer `KeyboardRevealScrollView` wirkt der Modifier nicht (niemand liest die Meldung).
 - Das Feld bekommt eine feste `.id`, damit `ScrollViewProxy.scrollTo` es findet.

 📝 Last Change:
 - Neu.
 ------------------------------------------------------------------------
 */

import SwiftUI

extension View {
    /// Meldet dieses Eingabefeld an die umgebende `KeyboardRevealScrollView`, solange `isFocused` wahr ist.
    func revealsWhenFocused(_ isFocused: Bool) -> some View {
        modifier(RevealWhenFocusedModifier(isFocused: isFocused))
    }
}

private struct RevealWhenFocusedModifier: ViewModifier {
    let isFocused: Bool
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .id(id)
            .background {
                if isFocused {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: FocusedFieldFrame.Key.self,
                            value: FocusedFieldFrame(id: id, frame: geo.frame(in: .named(FocusedFieldFrame.space))))
                    }
                }
            }
    }
}
