/*
 PressGesture.swift
 Famlist
 Created on: 14.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Drücken ohne Erkennungsverzögerung: `.onPress(onChanged:onEnded:)` meldet Aufsetzen, Bewegen und Loslassen.

 🔰 Notes for Beginners:
 - iOS 18+: PressGestureRecognizer (UIGestureRecognizerRepresentable). Grund und Quelle stehen dort.
 - iOS 17: SwiftUI-DragGesture mit Mindestweg 0 als Rückfallweg (dort ohne die Verzögerung von iOS 27).
 - `onChanged` liefert den Ort im globalen Koordinatensystem und die Bewegung seit dem Aufsetzen (Punkte).
   Die App läuft bildschirmfüllend in einem Fenster, deshalb sind Fenster- und globale Koordinaten gleich.
 - `onEnded` kommt auch beim Abbruch durch das System → kein hängenbleibender „gedrückt“-Zustand.

 📝 Last Change:
 - Initial creation (ersetzt die DragGesture am Plus-Knopf des Docks).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

extension View {
    /// Press tracking without recognition delay (location in global coordinates, translation since touch-down).
    func onPress(onChanged: @escaping (_ location: CGPoint, _ translation: CGSize) -> Void,
                 onEnded: @escaping () -> Void) -> some View {
        modifier(PressModifier(onChanged: onChanged, onEnded: onEnded))
    }
}

/// Chooses the UIKit recognizer on iOS 18+ and a DragGesture fallback on iOS 17.
private struct PressModifier: ViewModifier {
    let onChanged: (CGPoint, CGSize) -> Void
    let onEnded: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(PressRecognizer(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { onChanged($0.location, $0.translation) }
                .onEnded { _ in onEnded() })
        }
    }
}

/// Wraps PressGestureRecognizer for SwiftUI.
@available(iOS 18.0, *)
private struct PressRecognizer: UIGestureRecognizerRepresentable {
    let onChanged: (CGPoint, CGSize) -> Void
    let onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> PressGestureRecognizer {
        let press = PressGestureRecognizer()
        press.cancelsTouchesInView = false
        press.delaysTouchesEnded = false
        press.delegate = context.coordinator
        press.onChanged = onChanged
        press.onEnded = onEnded
        return press
    }

    /// Rückrufe bei jeder Aktualisierung neu setzen, sonst arbeiten sie mit veralteten Werten der View.
    func updateUIGestureRecognizer(_ recognizer: PressGestureRecognizer, context: Context) {
        recognizer.onChanged = onChanged
        recognizer.onEnded = onEnded
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    /// Leer: Die Rückrufe kommen direkt aus den Touch-Methoden des Erkenners (ohne target-action).
    func handleUIGestureRecognizerAction(_ recognizer: PressGestureRecognizer, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Reiner Beobachter: läuft neben anderen Gesten her.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
