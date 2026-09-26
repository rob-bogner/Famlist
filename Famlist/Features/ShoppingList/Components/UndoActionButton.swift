/*
 UndoActionButton.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Gelber „Zurück“-Knopf rechts hinter abgehakten Artikel-Karten in SwipeableItemRow.

 📝 Last Change:
 - Aus SwipeableItemRow.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Undo Action

/// Gelber „Zurück“-Knopf 56 in einer 76 breiten Spalte.
struct UndoActionButton: View {
    let t: ListTheme
    var isArmed = false
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                SVGIcon(Icon.undo, size: 22, color: .hex("#4A3300"), lineWidth: 2.2)
                    .frame(width: 56, height: 56)
                    .background(alignment: .top) {
                        GlossEllipse(opacity: 0.65)
                            .frame(height: 20)
                            .padding(.horizontal, 10)
                            .padding(.top, 3)
                    }
                    .clipShape(Circle())
                    .background(CSSBox(
                        shape: Circle(),
                        paint: .radialCircle(UnitPoint(x: 0.32, y: 0.24),
                                             [stop(.hex("#FFE38A"), 0), stop(.hex("#F5B521"), 0.55), stop(.hex("#C98A06"), 1)]),
                        shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.6)),
                                  .inner(0, -3, 8, 0, .rgba(120, 70, 0, 0.25)),
                                  .drop(0, 10, 20, -8, .rgba(201, 138, 6, 0.7))]))
                    .scaleEffect(isArmed ? 1.12 : 1)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Text("Zurück")
                .font(AppFont.dm(12, 600))
                .foregroundStyle(t.sub)
        }
        .frame(width: 76, height: 94)
    }
}

#Preview("Rückgängig-Knopf") {
    UndoActionButton(t: ListTheme(.light), action: {})
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Rückgängig-Knopf – Dark") {
    UndoActionButton(t: ListTheme(.dark), action: {})
        .padding(20)
        .background(Color.hex("#0A1416"))
}
