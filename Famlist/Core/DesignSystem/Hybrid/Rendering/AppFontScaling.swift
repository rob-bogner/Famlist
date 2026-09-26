/*
 AppFontScaling.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Überträgt die iOS-Schriftgröße (Einstellungen → Anzeige & Helligkeit → Textgröße) auf AppFont.

 🔰 Notes for Beginners:
 - AppFont liefert feste Schriften (Outfit/DM Sans mit Variations-Achsen). Damit sie mitwachsen,
   setzt dieser Modifier `AppFont.scale` und baut die Oberfläche bei einer Änderung neu auf (`.id`).
 - Standard-Textgröße = Faktor 1 = pixelgenau wie im Design. Obergrenze: AppFont.maxScale.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, lesbar auf allen iPhones).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

struct AppFontScaling: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let _ = AppFont.scale = AppFont.scale(for: UIContentSizeCategory(dynamicTypeSize))
        content.id(dynamicTypeSize)
    }
}

extension View {
    /// Schriften wachsen mit der iOS-Textgröße (begrenzt).
    func appFontScaling() -> some View { modifier(AppFontScaling()) }
}
