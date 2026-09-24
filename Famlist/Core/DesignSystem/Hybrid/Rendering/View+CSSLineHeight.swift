/*
 View+CSSLineHeight.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - CSS line-height als View-Modifier.

 🔰 Notes for Beginners:
 - Teil des Hybrid-Designs (Canvas „My List – Redesign“). Übersetzt CSS-Werte 1:1 nach SwiftUI.
   Umrechnungsregeln: siehe Core/DesignSystem/Hybrid/README.md.

 📝 Last Change:
 - Aus dem Design-Paket MyListUI übernommen.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

extension View {
    /// CSS `line-height: <lineHeight>px` – Zeilenabstand + halbes Leading oben/unten.
    func cssLineHeight(_ lineHeight: CGFloat, font: UIFont) -> some View {
        let extra = max(0, lineHeight - font.lineHeight)
        return self.lineSpacing(extra).padding(.vertical, extra / 2)
    }
}
