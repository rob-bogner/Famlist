/*
 View+WatchLineHeight.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Textbox genau so hoch wie die CSS-Zeile (line-height: normal oder ein fester Wert).

 🔰 Notes for Beginners:
 - SwiftUI rundet die Höhe einer Textbox auf ganze Bildpunkte nach oben (gemessen 26.09.2026:
   DM Sans 12 → 16,0 statt 15,62 pt; Outfit 22 → 28,0 statt 27,72 pt). Untereinander summiert sich das
   auf 1–2 pt. Mit fester CSS-Höhe liegen alle folgenden Elemente wieder an der Stelle des Designs.
 - Der Text wird in der Box senkrecht zentriert, wie der Browser (half-leading).
 - Einzeilige Texte: für mehrzeilige Texte (Dynamic Type) passt Phase 7 die Höhen an.
 ------------------------------------------------------------------------
 */

import SwiftUI

extension View {
    /// - Parameter lineHeight: CSS-Zeilenhöhe in pt, z. B. WatchFont.dmLineHeight(12) oder 22 × 1.1.
    /// Standard-Textgröße: genau eine Zeile in CSS-Höhe (pixelgenau). Größere Textgröße: bis zu zwei Zeilen,
    /// mindestens die Zeilenhöhe – nichts wird abgeschnitten.
    func watchLineBox(_ lineHeight: CGFloat) -> some View {
        modifier(WatchLineBox(lineHeight: lineHeight))
    }
}

private struct WatchLineBox: ViewModifier {
    let lineHeight: CGFloat

    func body(content: Content) -> some View {
        if WatchFont.scale == 1 {
            content.lineLimit(1).frame(height: lineHeight)
        } else {
            content.lineLimit(2).fixedSize(horizontal: false, vertical: true).frame(minHeight: lineHeight)
        }
    }
}
