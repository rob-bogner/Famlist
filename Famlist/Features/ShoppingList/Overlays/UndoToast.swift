/*
 UndoToast.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Toast „n Artikel gelöscht“ mit „Rückgängig“ und Restzeit-Balken (5 s).

 🔰 Notes for Beginners:
 - Vorlage: UndoToastScreen in design-handoff/MyListUI/Screens/OverlayScreens.swift
   (UndoToast.dc.html): links/rechts 20, unten 114, Höhe 56, padding 0 8 0 16, Radius 20.
 - Der Balken läuft in der App animiert von 100 % auf 0 % (Design-Standbild: 62 %).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct UndoToast: View {
    let k: OverlayTheme
    var count = 1
    /// Restzeit-Balken, Anteil der Padding-Box (0…1).
    var remaining: CGFloat = 0.62
    var onUndo: () -> Void = {}

    var body: some View {
        // links/rechts 20, unten 114, Höhe 56, padding 0 8 0 16, Radius 20, overflow hidden
        GlassToast(k: k, height: 56, radius: 20, leading: 16, trailing: 8) {
            SVGIcon(Icon.trash, size: 20, color: k.toastIcon, lineWidth: 1.9)
            Text("\(count) Artikel gelöscht")
                .font(AppFont.dm(15, 500))
                .foregroundStyle(k.toastText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUndo) {
                HStack(spacing: 6) {
                    SVGIcon(Icon.undo, size: 16, color: k.toastAccent, lineWidth: 2.2)
                    Text("Rückgängig")
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(k.toastAccent)
                        .fixedSize()                     // Knopf nie abschneiden; die Meldung links bricht um
                }
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(RR(14).fill(k.undoBg))
                .contentShape(RR(14))
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
        }
        .overlay {
            // Restzeit: absolute links 0 / unten 0 der Padding-Box, Höhe 3,
            // an der inneren Rundung (20 − 1 = 19) abgeschnitten.
            GeometryReader { g in
                Rectangle()
                    .fill(k.timer)
                    .frame(width: g.size.width * remaining, height: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .clipShape(RR(19))
            .padding(1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Artboard „Gelöscht, Rückgängig“ – leere Liste, kein Scrim, kein Extra-Dock.
struct UndoToastScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil

    var body: some View {
        let k = OverlayTheme(appearance, accentHex: accentHex)
        return OverlayStage(appearance: appearance, accentHex: accentHex, listState: .empty, showsScrim: false) {
            UndoToast(k: k)
                .overlayToastPosition(bottom: 114)
        }
    }
}

#Preview("Rückgängig", traits: .fixedLayout(width: 390, height: 844)) { UndoToastScreen(appearance: .light) }
#Preview("Rückgängig – Dark", traits: .fixedLayout(width: 390, height: 844)) { UndoToastScreen(appearance: .dark) }
