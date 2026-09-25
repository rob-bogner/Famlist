/*
 CTAButton.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Primär-Button der Hybrid-Sheets: Höhe 56, Pille, Glanz-Ellipse, Text 16/600.

 🔰 Notes for Beginners:
 - `isEnabled = false` blendet den Button auf 45 % ab und sperrt ihn (z. B. bei ungültigem Formular).
   Das Design zeigt keinen deaktivierten Zustand; 45 % ist eine Famlist-Ergänzung.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen, um isEnabled ergänzt.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Primär-Button: Höhe 56, Pille, Glanz (links/rechts 24, oben 2, Höhe 22), Text 16/600.
struct CTAButton: View {
    let title: String
    let k: SheetTheme
    var isEnabled = true
    /// Optionales Icon links vom Text (20 pt, Strich 2, Farbe wie der Text), z. B. Kamera bei „Kassenzettel scannen“.
    var icon: [SVGElement]? = nil
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    SVGIcon(icon, size: 20, color: k.ctaText, lineWidth: 2)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AppFont.dm(16, 600))
                    .foregroundStyle(k.ctaText)
                    .lineLimit(1)
            }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(alignment: .top) {
                    GlossEllipse(opacity: 0.45)
                        .frame(height: 22)
                        .padding(.horizontal, 24)
                        .padding(.top, 2)
                }
                .clipShape(Pill)
                .background(CSSBox(shape: Pill, paint: k.ctaPaint, shadows: k.ctaShadow))
                .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

#Preview {
    VStack(spacing: 20) {
        CTAButton(title: "Zur Liste hinzufügen", k: SheetTheme(.light))
        CTAButton(title: "Speichern", k: SheetTheme(.light), isEnabled: false)
        CTAButton(title: "Kassenzettel scannen", k: SheetTheme(.dark), icon: Icon.camera)
    }
    .padding(20)
}
