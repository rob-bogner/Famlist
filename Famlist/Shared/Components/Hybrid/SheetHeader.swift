/*
 SheetHeader.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Griff (40 × 5) + Titelzeile mit rundem Schließen-Button.

 🔰 Notes for Beginners:
 - Baustein der Hybrid-Sheets. Maße und Farben 1:1 aus dem Design (siehe Core/DesignSystem/Hybrid/README.md).

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Griff (40 × 5, Radius 3) + Titelzeile (Titel links, runder Schließen-Button rechts, 12 pt Abstand).
struct SheetHeader: View {
    let title: String
    let k: SheetTheme
    var onClose: () -> Void = {}
    /// Optionaler Zurück-Knopf links vom Titel (ReceiptReview.dc.html: 44 rund, Abstand 12). nil = keiner.
    var onBack: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            RR(3)
                .fill(k.grabber)
                .frame(width: 40, height: 5)
            HStack(spacing: 0) {
                if let onBack {
                    CircleCloseButton(k: k, size: 44, iconSize: 18, lineWidth: 2.2, icon: Icon.chevronLeft, action: onBack)
                        .accessibilityLabel("Zurück")
                        .padding(.trailing, 12)
                }
                Text(title)
                    .font(AppFont.outfit(22, 600))
                    .tracking(-0.22)                 // -0.01em × 22
                    .foregroundStyle(k.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                CircleCloseButton(k: k, size: 44, iconSize: 18, lineWidth: 2.2, action: onClose)
                    .accessibilityLabel("Schließen")
            }
            .padding(.top, 12)
        }
    }
}

#Preview("SheetHeader") {
    SheetHeader(title: "Artikel bearbeiten", k: SheetTheme(.light))
        .padding(20)
}

#Preview("SheetHeader – Dark") {
    SheetHeader(title: "Artikel bearbeiten", k: SheetTheme(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
