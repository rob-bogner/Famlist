/*
 GlassCircleBackground.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Glas-Fläche eines runden Knopfs (ohne Inhalt): radialer Verlauf, Glanz-Ellipse oben, Lichtschein unten,
   Tiefe per Schatten. Für Knöpfe mit beliebigem Inhalt (z. B. „1×“); mit Icon: GlassOrb.

 🔰 Notes for Beginners:
 - Glanz/Schein skalieren mit der Größe (Vorlage: FAB 64 → Glanz 11/4/24, Schein 17/4/8, blur 2).

 📝 Last Change:
 - Initial creation (aus GlassOrb herausgelöst).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct GlassCircleBackground: View {
    let style: GlassOrb.Style
    let appearance: Appearance
    let accent: AccentScale
    let size: CGFloat

    var body: some View {
        let t = GlassStyleTokens(style: style, appearance: appearance, accent: accent)
        let f = size / 64
        ZStack {
            GlossEllipse(opacity: t.gloss)
                .frame(height: (24 * f).rounded())
                .padding(.horizontal, (11 * f).rounded())
                .padding(.top, max(2, (4 * f).rounded()))
                .frame(maxHeight: .infinity, alignment: .top)
            Ellipse()
                .fill(Color.rgba(255, 255, 255, t.glow))
                .frame(height: max(4, (8 * f).rounded()))
                .blur(radius: 2)
                .padding(.horizontal, (17 * f).rounded())
                .padding(.bottom, max(2, (4 * f).rounded()))
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(CSSBox(shape: Circle(), paint: t.orbPaint, shadows: t.shadows))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("GlassCircleBackground") {
    let a = AccentScale(Appearance.light.defaultAccent, .light)
    Text("1×").font(AppFont.dm(13, 600)).frame(width: 56, height: 56)
        .background(GlassCircleBackground(style: .neutral, appearance: .light, accent: a, size: 56))
        .padding(24)
}

#Preview("GlassCircleBackground – Dark") {
    let a = AccentScale(Appearance.dark.defaultAccent, .dark)
    Text("1×").font(AppFont.dm(13, 600)).foregroundStyle(.white).frame(width: 56, height: 56)
        .background(GlassCircleBackground(style: .neutralDark, appearance: .dark, accent: a, size: 56))
        .padding(24)
        .background(Color.hex("#071012"))
}
