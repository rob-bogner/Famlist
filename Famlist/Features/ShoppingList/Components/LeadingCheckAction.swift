/*
 LeadingCheckAction.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Grüne Abhak-Aktion (abgehakt: gelbes „Zurück“) links hinter der Artikel-Karte in SwipeableItemRow.

 📝 Last Change:
 - Aus SwipeableItemRow.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Leading Check Action

/// Grüne Abhak-Aktion links hinter der Karte (Rechts-Wischen). Abgehakt: gelbes „Zurück“.
/// Nicht im Design gezeichnet – Stil der Glas-Aktionen, Farben Grün #6EE7A8 → #22C55E → #15803D.
struct LeadingCheckAction: View {
    let t: ListTheme
    let isChecked: Bool
    let progress: CGFloat
    let isArmed: Bool
    let action: () -> Void

    var body: some View {
        let colors = isChecked
            ? ("#FFE38A", "#F5B521", "#C98A06", Color.rgba(201, 138, 6, 0.7))
            : ("#6EE7A8", "#22C55E", "#15803D", Color.rgba(34, 197, 94, 0.6))
        VStack(spacing: 6) {
            Button(action: action) { circle(colors) }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            Text(isChecked ? "Zurück" : "Abhaken")
                .font(AppFont.dm(12, 600))
                .foregroundStyle(t.sub)
                .fixedSize()
        }
        .frame(width: 76, height: 94)
        .padding(.leading, 10)
        .accessibilityHidden(true)
    }

    private func circle(_ colors: (String, String, String, Color)) -> some View {
            SVGIcon(isChecked ? Icon.undo : Icon.check, size: 22,
                    color: isChecked ? .hex("#4A3300") : .white, lineWidth: 2.4)
                .frame(width: 56, height: 56)
                .background(alignment: .top) {
                    GlossEllipse(opacity: 0.6)
                        .frame(height: 20)
                        .padding(.horizontal, 10)
                        .padding(.top, 3)
                }
                .clipShape(Circle())
                .background(CSSBox(
                    shape: Circle(),
                    paint: .radialCircle(UnitPoint(x: 0.32, y: 0.24),
                                         [stop(.hex(colors.0), 0), stop(.hex(colors.1), 0.55), stop(.hex(colors.2), 1)]),
                    shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.55)),
                              .inner(0, -3, 8, 0, .rgba(0, 0, 0, 0.18)),
                              .drop(0, 10, 20, -8, colors.3)]))
                .scaleEffect(isArmed ? 1.12 : 0.7 + 0.3 * progress)
                .contentShape(Circle())
    }
}

#Preview("Abhaken beim Wischen") {
    LeadingCheckAction(t: ListTheme(.light), isChecked: false, progress: 0.6, isArmed: false, action: {})
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Abhaken beim Wischen – Dark") {
    LeadingCheckAction(t: ListTheme(.dark), isChecked: true, progress: 1, isArmed: true, action: {})
        .padding(20)
        .background(Color.hex("#0A1416"))
}
