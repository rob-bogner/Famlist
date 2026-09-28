/*
 CategoryTile.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Quadratische Kachel mit Kategorie-Icon in der Kategoriefarbe (Bon-Detail 38, Ausgaben 30, Verbrauch 36).

 🔰 Notes for Beginners:
 - Hintergrund = Kategoriefarbe mit 12 % (Hell) / 18 % (Dunkel), Icon in voller Farbe (InsightPalette).
 - Icon aus CategoryIconCatalog über die Kategorie-Definition; ohne Kategorie das Icon von „Sonstiges“.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct CategoryTile: View {
    let category: CategoryDefinition?
    let rank: Int?
    let size: CGFloat
    let radius: CGFloat
    let iconSize: CGFloat
    let dark: Bool
    var lineWidth: CGFloat = 1.9

    var body: some View {
        SVGIcon(icon, size: iconSize, color: InsightPalette.color(rank: rank, dark: dark), lineWidth: lineWidth)
            .frame(width: size, height: size)
            .background(RR(radius).fill(InsightPalette.soft(rank: rank, dark: dark)))
            .accessibilityHidden(true)
    }

    private var icon: [SVGElement] {
        (category ?? CategoryDefinition.defaults.first(where: \.isFallback))?.svgIcon ?? []
    }
}

#Preview("Kategorie-Kachel") {
    HStack(spacing: 8) {
        ForEach(0..<7) { rank in
            CategoryTile(category: CategoryDefinition.defaults[rank], rank: rank < 6 ? rank : nil,
                         size: 38, radius: 12, iconSize: 19, dark: false)
        }
    }
    .padding()
}

#Preview("Kategorie-Kachel – Dark") {
    HStack(spacing: 8) {
        ForEach(0..<7) { rank in
            CategoryTile(category: CategoryDefinition.defaults[rank], rank: rank < 6 ? rank : nil,
                         size: 38, radius: 12, iconSize: 19, dark: true)
        }
    }
    .padding()
    .background(Color.black)
}
