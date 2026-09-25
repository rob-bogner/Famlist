/*
 DockGeometry.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Rechnet die Pillen-Mitte des Docks aus, damit der Zeiger der Dock-Menüs auf jeder Bildschirmbreite auf den gewählten Knopf zeigt.

 📝 Last Change:
 - Aus DockView.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Geometrie (für die Zeiger der Dock-Menüs)

/// Rechnet die Pillen-Mitte aus, damit der Zeiger der Popover-Menüs auf jeder Bildschirmbreite
/// auf den gewählten Knopf zeigt. Bei 390 pt ergeben sich exakt die Design-Werte 104,33 / 155,67 / 211.
enum DockGeometry {
    /// Leistenbreite: Bildschirm − 20 − 20 − Plus 64 − Abstand 10.
    static func navWidth(screenWidth: CGFloat) -> CGFloat { screenWidth - 114 }

    /// CSS-`left` des Zeigers im Menü (Menü sitzt bei x 20; Rahmen 1; Zeiger 14 breit).
    static func pointerLeft(for active: DockActive, screenWidth: CGFloat) -> CGFloat {
        let widths: [CGFloat]
        let index: Int
        switch active {
        case .sort: widths = [44, 112, 44, 44]; index = 1
        case .copy, .copied: widths = [44, 44, 112, 44]; index = 2
        case .delete: widths = [44, 44, 44, 104]; index = 3
        case .none: widths = [124, 44, 44, 44]; index = 0
        }
        let inner = navWidth(screenWidth: screenWidth) - 10          // Rahmen 1 + padding 4, beidseitig
        let gap = (inner - widths.reduce(0, +)) / 3                  // justify-content: space-between
        let center = widths.prefix(index).reduce(0, +) + CGFloat(index) * gap + widths[index] / 2
        return center - 3                                            // 20 + 5 + center − (20 + 1 + 7)
    }
}
