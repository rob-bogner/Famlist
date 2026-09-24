/*
 EKKFlexRow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Waagerechte Zeile mit exakter CSS-Flexbox-Verteilung (flex-grow / flex-shrink) für „Kategorien verwalten“.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/CategoryScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

// MARK: - Flex-Zeile (CSS flex-grow / flex-shrink)

/// Waagerechte Zeile mit exakter CSS-Flexbox-Verteilung:
/// Basis = ideale Breite; Überschuss nach flex-grow, Mangel nach flex-shrink × Basis.
/// Nötig für „Sonstiges“: dort ist der Untertitel breiter als der Platz, und im Browser
/// schrumpfen Nummer (22) und Griff-Button (44) anteilig mit.
struct EKKFlexRow: Layout {
    var spacing: CGFloat
    var grow: [CGFloat]
    var shrink: [CGFloat]

    private func widths(total: CGFloat, subviews: Subviews) -> [CGFloat] {
        let n = subviews.count
        let basis = subviews.map { $0.sizeThatFits(.unspecified).width }
        let free = total - basis.reduce(0, +) - spacing * CGFloat(max(0, n - 1))
        var result = basis
        if free > 0 {
            let g = (0..<n).map { $0 < grow.count ? grow[$0] : 0 }
            let sum = g.reduce(0, +)
            if sum > 0 {
                for i in 0..<n { result[i] += free * g[i] / sum }
            }
        } else if free < 0 {
            let f = (0..<n).map { ($0 < shrink.count ? shrink[$0] : 1) * basis[$0] }
            let sum = f.reduce(0, +)
            if sum > 0 {
                for i in 0..<n { result[i] = max(0, basis[i] + free * f[i] / sum) }
            }
        }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = subviews.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +)
            + spacing * CGFloat(max(0, subviews.count - 1))
        let total: CGFloat
        if let w = proposal.width, w.isFinite { total = w } else { total = natural }
        let ws = widths(total: total, subviews: subviews)
        var height: CGFloat = 0
        for (i, s) in subviews.enumerated() {
            height = max(height, s.sizeThatFits(ProposedViewSize(width: ws[i], height: nil)).height)
        }
        return CGSize(width: total, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ws = widths(total: bounds.width, subviews: subviews)
        var x = bounds.minX
        for (i, s) in subviews.enumerated() {
            s.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                    proposal: ProposedViewSize(width: ws[i], height: nil))
            x += ws[i] + spacing
        }
    }
}

// MARK: - Kategorien verwalten
//
// Quelle: Design/html/ManageCategories.dc.html (Dark: ManageCategoriesDark.dc.html)
//  Sheet 790, Innenabstand 10/20/34. Titelzeile → 16 → Hinweis-Box (Padding 12/14, Radius 16) →
//  20 → „4 Kategorien“ → 10 → Zeilen 68 (Abstand 8, Radius 20, Padding 0/10/0/12, Abstand 12) →
