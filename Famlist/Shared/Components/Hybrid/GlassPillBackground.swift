/*
 GlassPillBackground.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Glas-Hintergrund für Pillen-Knöpfe (Chips 34, Nebenknöpfe 52, Gefahr): Verlauf, Glanz-Pille oben,
   weicher Lichtsaum unten, Tiefe per Schatten. Als `.background(...)` hinter den Inhalt legen.

 🔰 Notes for Beginners:
 - Maße skalieren mit der Höhe H (Canvas): Glanz links/rechts max(10, 0,3·H), oben 2 (H < 44) bzw. 3,
   Höhe 0,38·H, blur 1; Schein links/rechts max(18, 0,7·H), Höhe 5 bzw. 7, blur 3.
 - Farben: GlassStyleTokens (gleich wie die runden Glas-Knöpfe).

 📝 Last Change:
 - Initial creation (einheitliche Glas-Knöpfe auf allen Screens).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct GlassPillBackground: View {
    let style: GlassOrb.Style
    let appearance: Appearance
    let accent: AccentScale
    let height: CGFloat
    /// Abweichende Höhe des Lichtsaums, wenn das Board sie anders setzt (z. B. 50-pt-Knöpfe in RestoreAccount: 5).
    var glowHeightOverride: CGFloat? = nil

    var body: some View {
        let t = GlassStyleTokens(style: style, appearance: appearance, accent: accent)
        let glossInset = max(10, (height * 0.3).rounded())
        let edge: CGFloat = height < 44 ? 2 : 3
        let glossHeight = (height * 0.38).rounded()
        let glowInset = max(18, (height * 0.7).rounded())
        let glowHeight: CGFloat = glowHeightOverride ?? (height < 44 ? 5 : 7)
        ZStack {
            Capsule()
                .fill(LinearGradient(stops: [stop(.rgba(255, 255, 255, t.gloss), 0), stop(.rgba(255, 255, 255, 0), 1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: glossHeight)
                .blur(radius: 1)
                .padding(.horizontal, glossInset)
                .padding(.top, edge)
                .frame(maxHeight: .infinity, alignment: .top)
            Capsule()
                .fill(Color.rgba(255, 255, 255, t.glow))
                .frame(height: glowHeight)
                .blur(radius: 3)
                .padding(.horizontal, glowInset)
                .padding(.bottom, edge)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(Capsule())
        .background(CSSBox(shape: Capsule(), paint: t.pillPaint, shadows: t.shadows))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("GlassPillBackground") {
    let a = AccentScale(Appearance.light.defaultAccent, .light)
    VStack(spacing: 16) {
        Text("Zuordnen").font(AppFont.dm(13, 600)).foregroundStyle(.white).padding(.horizontal, 11).frame(height: 34)
            .background(GlassPillBackground(style: .accent, appearance: .light, accent: a, height: 34))
        Text("Teilen").font(AppFont.dm(15, 600)).padding(.horizontal, 40).frame(height: 52)
            .background(GlassPillBackground(style: .neutral, appearance: .light, accent: a, height: 52))
    }
    .padding(24)
}

#Preview("GlassPillBackground – Dark") {
    let a = AccentScale(Appearance.dark.defaultAccent, .dark)
    VStack(spacing: 16) {
        Text("Zuordnen").font(AppFont.dm(13, 600)).foregroundStyle(.white).padding(.horizontal, 11).frame(height: 34)
            .background(GlassPillBackground(style: .accent, appearance: .dark, accent: a, height: 34))
        Text("Löschen").font(AppFont.dm(15, 600)).foregroundStyle(.white).padding(.horizontal, 40).frame(height: 52)
            .background(GlassPillBackground(style: .danger, appearance: .dark, accent: a, height: 52))
    }
    .padding(24)
    .background(Color.hex("#071012"))
}
