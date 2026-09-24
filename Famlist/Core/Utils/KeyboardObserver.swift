/*
 KeyboardObserver.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Veröffentlicht die aktuelle Höhe der Bildschirmtastatur (0 = ausgeblendet).

 🔰 Notes for Beginners:
 - Die Hybrid-Sheets liegen als eigene Ebene über der Liste und ignorieren die Safe Area,
   damit sie beim Einblenden der Tastatur nicht springen. Ihr Primär-Button muss trotzdem
   14 pt über der Tastatur sitzen – dafür liefert dieser Beobachter die Höhe.
 - Die Höhe wird ab der Bildschirmunterkante gemessen (inklusive Home-Indikator-Bereich).

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import SwiftUI
import Combine
import UIKit

/// Tracks the on-screen keyboard height from UIKit keyboard notifications.
@MainActor
final class KeyboardObserver: ObservableObject {
    @Published private(set) var height: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        let center = NotificationCenter.default
        center.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .merge(with: center.publisher(for: UIResponder.keyboardWillHideNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] note in self?.update(from: note) }
            .store(in: &cancellables)
    }

    private func update(from note: Notification) {
        guard note.name != UIResponder.keyboardWillHideNotification,
              let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            height = 0
            return
        }
        let screenHeight = (note.object as? UIScreen)?.bounds.height ?? frame.maxY
        height = max(0, screenHeight - frame.minY)
    }
}
