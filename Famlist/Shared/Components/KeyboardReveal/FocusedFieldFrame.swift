/*
 FocusedFieldFrame.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lage des gerade fokussierten Eingabefelds, gemeldet an die umgebende `KeyboardRevealScrollView`.

 🔰 Notes for Beginners:
 - Felder melden sich mit `.revealsWhenFocused(isFocused)`. Gemessen wird im Koordinatenraum `space`,
   den die ScrollView setzt: y = 0 ist die Oberkante ihres sichtbaren Bereichs.

 📝 Last Change:
 - Neu: Grundlage dafür, dass fokussierte Felder nie hinter Tastatur oder schwebenden Knöpfen liegen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Lage des fokussierten Eingabefelds relativ zum sichtbaren Bereich einer `KeyboardRevealScrollView`.
struct FocusedFieldFrame: Equatable {
    /// Name des Koordinatenraums, den `KeyboardRevealScrollView` auf ihre ScrollView setzt.
    static let space = "keyboardRevealViewport"

    /// Scroll-Ziel (`.id`) des Felds.
    let id: UUID
    /// Rahmen des Felds; y = 0 ist die Oberkante des sichtbaren Bereichs.
    let frame: CGRect

    /// Sammelt den Rahmen des fokussierten Felds. Es ist höchstens ein Feld fokussiert.
    struct Key: PreferenceKey {
        static let defaultValue: FocusedFieldFrame? = nil

        static func reduce(value: inout FocusedFieldFrame?, nextValue: () -> FocusedFieldFrame?) {
            value = value ?? nextValue()
        }
    }
}
