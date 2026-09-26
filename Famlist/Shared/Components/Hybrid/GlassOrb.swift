/*
 GlassOrb.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Runder Glas-Knopf (nur Optik) in der Designsprache des Plus-Knopfs im Dock:
   radialer Verlauf mit Lichtpunkt oben links, Glanz-Ellipse oben, weicher Lichtschein unten, Tiefe per Schatten.

 🔰 Notes for Beginners:
 - Varianten (Canvas: Token gp / gn / gnd / gd):
   • .accent      – Primäraktion (+ usw.): Akzent-Verlauf, weißes Icon mit leichtem Schatten.
   • .neutral     – Nebenfunktion (✕, ☰, Suche, Scannen, Zurück): heller bzw. dunkler Verlauf, Icon in Textfarbe.
   • .neutralDark – wie .neutral dunkel, unabhängig vom Modus (Kamera, über Fotos).
   • .danger      – Löschen: roter Verlauf, weißes Icon.
   • .apple       – „Mit Apple anmelden“: Schwarz (hell) bzw. Weiß (dunkel) mit Glanz (Canvas-Token ga).
 - Werte liegen in GlassStyleTokens (auch für GlassPillBackground).
 - Glanz/Schein skalieren mit der Größe (Vorlage: FAB 64 → Glanz 11/4/24, Schein 17/4/8).
 - Knopf mit Aktion: GlassCircleButton.

 📝 Last Change:
 - Initial creation (einheitliche Glas-Knöpfe in der ganzen App).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Visual of a round glass button (accent or neutral).
struct GlassOrb: View {
    enum Style { case accent, neutral, neutralDark, danger, apple }

    let style: Style
    let appearance: Appearance
    let accent: AccentScale
    let icon: [SVGElement]
    var size: CGFloat = 44
    var iconSize: CGFloat? = nil
    /// Abweichende Icon-Farbe (z. B. Scannen: Akzenttext auf neutralem Glas).
    var iconColor: Color? = nil
    var lineWidth: CGFloat = 2.2


    var body: some View {
        let tokens = GlassStyleTokens(style: style, appearance: appearance, accent: accent)
        SVGIcon(icon, size: iconSize ?? (size <= 44 ? 18 : 22), color: iconColor ?? tokens.icon, lineWidth: lineWidth)
            .shadow(color: tokens.iconShadow, radius: 1, y: 1)
            .frame(width: size, height: size)
            .background(GlassCircleBackground(style: style, appearance: appearance, accent: accent, size: size))
            .accessibilityHidden(true)
    }
}

#Preview("GlassOrb") {
    let a = AccentScale(Appearance.light.defaultAccent, .light)
    HStack(spacing: 14) {
        GlassOrb(style: .accent, appearance: .light, accent: a, icon: Icon.plus, size: 40, lineWidth: 2.4)
        GlassOrb(style: .neutral, appearance: .light, accent: a, icon: Icon.close, size: 44)
        GlassOrb(style: .neutral, appearance: .light, accent: a, icon: Icon.menu, size: 44, iconSize: 20, lineWidth: 1.9)
    }
    .padding(24)
}

#Preview("GlassOrb – Dark") {
    let a = AccentScale(Appearance.dark.defaultAccent, .dark)
    HStack(spacing: 14) {
        GlassOrb(style: .accent, appearance: .dark, accent: a, icon: Icon.plus, size: 40, lineWidth: 2.4)
        GlassOrb(style: .neutral, appearance: .dark, accent: a, icon: Icon.close, size: 44)
        GlassOrb(style: .neutral, appearance: .dark, accent: a, icon: Icon.menu, size: 44, iconSize: 20, lineWidth: 1.9)
    }
    .padding(24)
    .background(Color.hex("#071012"))
}
