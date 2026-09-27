/*
 WatchFontScaling.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Überträgt die Textgröße der Uhr (Einstellungen → Anzeige & Helligkeit → Textgröße) auf WatchFont –
   wie AppFontScaling auf dem iPhone.

 🔰 Notes for Beginners:
 - WatchFont liefert feste Schriften (Variations-Achsen). Damit sie mitwachsen, setzt dieser Modifier
   `WatchFont.scale` und baut die Oberfläche bei einer Änderung neu auf (`.id`).
 - Standard-Textgröße = Faktor 1 = pixelgenau wie im Design; kleiner wird nie skaliert; Obergrenze
   WatchFont.maxScale.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct WatchFontScaling: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Wie stark SwiftUI Fließtext bei der aktuellen Textgröße vergrößert (Basis 100).
    @ScaledMetric(relativeTo: .body) private var bodyMetric: CGFloat = 100

    func body(content: Content) -> some View {
        let _ = WatchFont.scale = WatchFont.scale(bodyMetric: bodyMetric)
        let _ = logVoid(params: (action: "watchFont.scale", size: "\(dynamicTypeSize)", metric: bodyMetric, scale: WatchFont.scale))
        content.id(dynamicTypeSize)
    }
}

extension View {
    /// Schriften wachsen mit der Textgröße der Uhr (begrenzt).
    func watchFontScaling() -> some View { modifier(WatchFontScaling()) }
}
