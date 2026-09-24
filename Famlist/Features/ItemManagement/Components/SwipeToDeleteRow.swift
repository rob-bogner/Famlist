/*
 SwipeToDeleteRow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte, die sich nach links wischen lässt und dahinter „Löschen“ zeigt (Artikel verwalten).

 🔰 Notes for Beginners:
 - Gleicher roter Glas-Knopf wie bei den Wisch-Aktionen der Liste (GlassActionButton, Spalte 76).
 - Weit durchwischen (über 60 % der Breite) löscht sofort, sonst rastet die Aktion ein.
 - Die Wischgeste nutzt `onHorizontalPan` (UIKit auf iOS 18+), damit das Scrollen nicht blockiert.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 3).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct SwipeToDeleteRow<Content: View>: View {
    let labelColor: Color
    var columnHeight: CGFloat = 74
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    private let revealWidth: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                GlassActionButton(style: .delete, title: "Löschen", icon: Icon.trashAction,
                                  labelColor: labelColor, columnHeight: columnHeight) { deleteNow() }
                    .opacity(offset < -8 ? 1 : 0)
                content()
                    .offset(x: offset)
                    .onHorizontalPan(onChanged: { dx in
                        offset = min(0, startOffset + dx)
                    }, onEnded: { dx, velocity in
                        let final = startOffset + dx
                        if final < -geo.size.width * 0.6 { deleteNow(); return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            offset = (final < -revealWidth / 2 || velocity < -600) ? -revealWidth : 0
                        }
                        startOffset = offset
                    })
            }
        }
        .frame(height: columnHeight)
        .accessibilityAction(named: "Löschen", deleteNow)
    }

    private func deleteNow() {
        withAnimation(.easeInOut(duration: 0.25)) { offset = 0 }
        startOffset = 0
        onDelete()
    }
}
