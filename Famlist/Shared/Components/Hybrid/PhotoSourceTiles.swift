/*
 PhotoSourceTiles.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zwei Glas-Kacheln „Foto aufnehmen“ / „Aus Mediathek“ für die Aktionskarte „Foto hinzufügen“
   (Canvas: PhotoSourceDialog).

 🔰 Notes for Beginners:
 - Kachel: 104 hoch, Radius 24, neutrale Glas-Fläche; innen Symbol-Kachel 44 (Radius 14, Akzent-Ton)
   und Beschriftung 14/600, Abstand 10. Zwischen den Kacheln 10.
 - Ohne Kamera (Simulator) nur „Aus Mediathek“ über die volle Breite.

 📝 Last Change:
 - Initial creation (Designsprache statt Systemdialoge).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Camera / library tiles shown inside the "add photo" action card.
struct PhotoSourceTiles: View {
    let k: SheetTheme
    let hasCamera: Bool
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if hasCamera {
                tile("Foto aufnehmen", icon: Icon.camera, action: onCamera)
            }
            tile("Aus Mediathek", icon: Icon.image, action: onLibrary)
        }
    }

    private func tile(_ title: String, icon: [SVGElement], action: @escaping () -> Void) -> some View {
        let d = ActionCardTokens(k)
        let glass = GlassStyleTokens(style: .neutral, appearance: k.appearance, accent: k.a)
        return Button(action: action) {
            VStack(spacing: 10) {
                SVGIcon(icon, size: 22, color: d.info, lineWidth: 2)
                    .frame(width: 44, height: 44)
                    .background(RR(14).fill(d.infoSoft))
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(d.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background {
                // Glanz wie die neutralen Glas-Pillen (gn.gloss / gn.glow)
                PillGlassReflection(topHeight: 41, topOpacity: k.isDark ? 0.28 : 0.95,
                                    glowHeight: 7, glowOpacity: k.isDark ? 0.1 : 0.6)
                    .clipShape(RR(24))
            }
            .background(CSSBox(shape: RR(24), paint: glass.pillPaint, shadows: glass.shadows))
            .contentShape(RR(24))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PhotoSourceTiles(k: SheetTheme(.light), hasCamera: true, onCamera: {}, onLibrary: {})
        .padding(20)
}

#Preview("Dark") {
    PhotoSourceTiles(k: SheetTheme(.dark), hasCamera: true, onCamera: {}, onLibrary: {})
        .padding(20)
        .background(Color.black)
}
