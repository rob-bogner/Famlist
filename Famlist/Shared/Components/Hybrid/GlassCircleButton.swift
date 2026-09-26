/*
 GlassCircleButton.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder Glas-Knopf mit Aktion (Optik: GlassOrb). Trefferfläche mindestens 44 pt.

 🔰 Notes for Beginners:
 - Für alle runden Knöpfe der App: .accent für Primäraktionen (+), .neutral für ✕, ☰, Suche, Scannen.

 📝 Last Change:
 - Initial creation (einheitliche Glas-Knöpfe).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Round glass button with an action.
struct GlassCircleButton: View {
    let style: GlassOrb.Style
    let appearance: Appearance
    let accent: AccentScale
    let icon: [SVGElement]
    let label: String
    var size: CGFloat = 44
    var iconSize: CGFloat? = nil
    var iconColor: Color? = nil
    var lineWidth: CGFloat = 2.2
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassOrb(style: style, appearance: appearance, accent: accent, icon: icon, size: size,
                     iconSize: iconSize, iconColor: iconColor, lineWidth: lineWidth)
                .frame(width: max(size, 44), height: max(size, 44))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, size < 44 ? -(44 - size) / 2 : 0)     // 44er-Trefferfläche ohne Layout-Versatz
        .padding(.vertical, size < 44 ? -(44 - size) / 2 : 0)
        .accessibilityLabel(label)
    }
}

#Preview {
    let a = AccentScale(Appearance.light.defaultAccent, .light)
    HStack(spacing: 14) {
        GlassCircleButton(style: .accent, appearance: .light, accent: a, icon: Icon.plus, label: "Hinzufügen",
                          size: 40, lineWidth: 2.4) {}
        GlassCircleButton(style: .neutral, appearance: .light, accent: a, icon: Icon.close, label: "Schließen") {}
    }
    .padding(24)
}

#Preview("Dark") {
    let a = AccentScale(Appearance.dark.defaultAccent, .dark)
    HStack(spacing: 14) {
        GlassCircleButton(style: .accent, appearance: .dark, accent: a, icon: Icon.plus, label: "Hinzufügen",
                          size: 40, lineWidth: 2.4) {}
        GlassCircleButton(style: .neutral, appearance: .dark, accent: a, icon: Icon.close, label: "Schließen") {}
    }
    .padding(24)
    .background(Color.hex("#071012"))
}
