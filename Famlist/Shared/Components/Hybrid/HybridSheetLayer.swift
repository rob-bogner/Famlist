/*
 HybridSheetLayer.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rahmen jedes Hybrid-Sheets: SheetSurface + Kopf (Griff, Titel, Schließen) + Inhalt.
   Ersetzt `SheetScreen` aus dem Design-Paket.

 🔰 Notes for Beginners:
 - Die Sheets werden bewusst NICHT mit `.sheet()` präsentiert: Systemsheets haben eigene Radien,
   Einzüge und Glasflächen. Die Liste dahinter blendet ShoppingListView weich und dunkel ab.
 - Höhe = Designhöhe (452 / 726 / 790), aber höchstens `maxHeight`. So passt das Sheet auch
   auf kleineren Geräten als dem 390 × 844-Referenzbildschirm.
 - Herunterziehen am Kopf schließt das Sheet (ab 120 pt Weg oder schnellem Wisch).
 - Innenabstand oben 10, seitlich 20 gilt für den Kopf. Der Inhalt bestimmt seine Ränder selbst,
   damit Chip-Reihen bis zur Sheet-Kante laufen können.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid sheet chrome with drag-to-dismiss header.
struct HybridSheetLayer<Content: View>: View {
    let k: SheetTheme
    let title: String
    let designHeight: CGFloat
    let maxHeight: CGFloat
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        SheetSurface(k: k, height: min(designHeight, maxHeight)) {
            VStack(spacing: 0) {
                SheetHeader(title: title, k: k, onClose: onClose)
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                    .gesture(dismissDrag)
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .offset(y: dragOffset)
        .accessibilityAction(.escape, onClose)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 260 {
                    onClose()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragOffset = 0 }
            }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.gray.opacity(0.4)
        HybridSheetLayer(k: SheetTheme(.light), title: "Produktbild", designHeight: 452, maxHeight: 790, onClose: {}) {
            Text("Inhalt").padding(.top, 22)
        }
    }
    .ignoresSafeArea()
}
