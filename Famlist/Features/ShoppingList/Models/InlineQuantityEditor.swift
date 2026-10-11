/*
 InlineQuantityEditor.swift
 Famlist
 Created on: 12.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Menge direkt in der Liste ändern (Design: ListQuantityEdit): Tippen auf den Mengen-Chip der Artikelkarte
   macht daraus eine Eingabe-Pille (− · Zahl · +, wie in „Artikel bearbeiten“). Zahl antippen → Ziffernblock.

 🔰 Notes for Beginners:
 - Höchstens EINE Karte ist gleichzeitig im Eingabe-Modus (`editingId`).
 - Tippen außerhalb der Pille beendet die Eingabe (ShoppingListView meldet jeden Tipp mit Bildschirm-Position,
   `handleTap`). Solange eine Pille offen ist, scrollt die Liste nicht.
 - Gespeichert wird gebündelt: 0,6 s nach der letzten Änderung und spätestens beim Schließen
   (sonst würde jedes ± sofort synchronisiert).
 - `@Observable`: Karten zeichnen sich neu, sobald sich `editingId` ändert.

 📝 Last Change:
 - Initial creation (Wunsch Robert 12.10.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

@MainActor
@Observable
final class InlineQuantityEditor {
    /// Artikel, dessen Mengen-Pille gerade offen ist.
    private(set) var editingId: String?
    /// Rahmen der offenen Pille in globalen Koordinaten (Tippen außerhalb → schließen).
    var pillFrame: CGRect = .zero
    /// true, solange die Zahl per Ziffernblock bearbeitet wird.
    var isTyping = false

    /// Speichert eine neue Menge (Artikel-ID, Menge).
    @ObservationIgnored var onCommit: (@MainActor (String, Double) -> Void)?
    @ObservationIgnored private var pending: (id: String, units: Double)?
    @ObservationIgnored private var commitTask: Task<Void, Never>?

    static let animation = Animation.spring(response: 0.32, dampingFraction: 0.82)

    func begin(_ itemId: String) {
        guard editingId != itemId else { return }
        finish()
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(Self.animation) { editingId = itemId }
    }

    func change(_ itemId: String, to units: Double) {
        pending = (itemId, units)
        commitTask?.cancel()
        commitTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }

    /// Schließt die Pille und speichert eine noch offene Änderung.
    func finish() {
        commitTask?.cancel()
        flush()
        guard editingId != nil else { return }
        withAnimation(Self.animation) {
            editingId = nil
            isTyping = false
            pillFrame = .zero
        }
    }

    /// Tipp irgendwo in der Liste: außerhalb der Pille → schließen.
    func handleTap(at point: CGPoint) {
        guard editingId != nil, !pillFrame.insetBy(dx: -6, dy: -6).contains(point) else { return }
        finish()
    }

    private func flush() {
        guard let p = pending else { return }
        pending = nil
        onCommit?(p.id, p.units)
    }
}

private struct InlineQuantityEditorKey: EnvironmentKey {
    static var defaultValue: InlineQuantityEditor? { nil }
}

extension EnvironmentValues {
    /// nil (Vorschau, Kassenzettel …) → Mengen-Chip ist nicht antippbar.
    var inlineQuantityEditor: InlineQuantityEditor? {
        get { self[InlineQuantityEditorKey.self] }
        set { self[InlineQuantityEditorKey.self] = newValue }
    }
}
