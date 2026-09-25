/*
 DesignListTopBar.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kopfzeile der statischen Design-Liste (Titel „My List“ und runder Mehr-Knopf) für DesignListScreen.

 📝 Last Change:
 - Aus DesignListScreen.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Kopfzeile

struct DesignListTopBar: View {
    let t: ListTheme

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Button(action: {}) {
                HStack(spacing: 6) {
                    Text("My List")
                        .font(AppFont.outfit(30, 700))
                        .tracking(-0.6)                      // -0.02em × 30
                        .foregroundStyle(t.text)
                    SVGIcon(Icon.chevronDown, size: 18, color: t.sub, lineWidth: 2.2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Liste wechseln")

            Spacer(minLength: 0)

            // Nur noch EIN runder Knopf („Ansicht wechseln“ entfällt)
            DesignRoundHeaderButton(t: t, icon: Icon.menu, label: "Mehr")
        }
    }
}

private struct DesignRoundHeaderButton: View {
    let t: ListTheme
    let icon: [SVGElement]
    let label: String

    var body: some View {
        Button(action: {}) {
            SVGIcon(icon, size: 20, color: t.icon, lineWidth: 1.9)
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: Circle(), paint: t.round, border: 1, borderColor: t.roundBorder, shadows: t.roundShadow))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview("Kopfzeile") {
    DesignListTopBar(t: ListTheme(.light))
        .padding(20)
        .background(Color.hex("#F4F8F8"))
}

#Preview("Kopfzeile – Dark") {
    DesignListTopBar(t: ListTheme(.dark))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
