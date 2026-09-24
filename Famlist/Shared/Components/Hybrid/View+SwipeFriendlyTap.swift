/*
 View+SwipeFriendlyTap.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - `.swipeFriendlyTap(label, action:)`: tippbare Fläche für Bedienelemente INNERHALB einer Wisch-Zeile.

 🔰 Notes for Beginners:
 - Ein SwiftUI-`Button` behält eine Berührung für sich, auch wenn der Finger danach wischt.
   Eine Tipp-Erkennung scheitert dagegen, sobald sich der Finger bewegt, und gibt die Berührung an
   die Wischgeste weiter (per UI-Test nachgewiesen).
 - Zusätzlich lösen mehrere Buttons in einer List-Zeile sonst beim Tippen irgendwo auf der Zeile aus.
 - Für VoiceOver bleibt es ein Button: Trait .isButton, Label und Standard-Aktion.

 📝 Last Change:
 - Initial creation (Wischen startet auch auf Abhak-Kreis und Bild).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension View {
    /// Tap target that does not block a surrounding swipe gesture.
    func swipeFriendlyTap(_ label: String, action: @escaping () -> Void) -> some View {
        self
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
            .accessibilityAction { action() }
    }
}
