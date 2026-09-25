/*
 ManageItemsShrinkRow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Flexbox-Nachbau: Textspalte + Chevron schrumpfen proportional wie im Browser (Artikel verwalten).

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Screens/ItemExtraScreens.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Flexbox-Nachbau für [Textspalte (flex-grow 1, min-width 0) · gap · SVG (flex-shrink 1, Basis 18)].
/// Passt der Text nicht, schrumpfen beide proportional zu ihrer Basisbreite – wie im Browser.
/// Dadurch wird der Chevron bei sehr langen Namen („Kerrygold, …“) sichtbar kleiner, exakt wie im Design.
struct ManageItemsShrinkRow: Layout {
    var gap: CGFloat
    var trailingBasis: CGFloat

    private func widths(_ subviews: Subviews, available: CGFloat) -> (text: CGFloat, trailing: CGFloat) {
        let textBasis = subviews[0].sizeThatFits(.unspecified).width
        let free = max(0, available - gap)
        let sum = textBasis + trailingBasis
        if sum <= free || sum <= 0 {
            return (max(0, free - trailingBasis), trailingBasis)
        }
        let overflow = sum - free
        let trailing = max(0, trailingBasis - overflow * trailingBasis / sum)
        let text = max(0, textBasis - overflow * textBasis / sum)
        return (text, trailing)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let ideal = subviews[0].sizeThatFits(.unspecified).width + gap + trailingBasis
        var available = proposal.width ?? ideal
        if !available.isFinite { available = ideal }
        let w = widths(subviews, available: available)
        let textHeight = subviews[0].sizeThatFits(ProposedViewSize(width: w.text, height: nil)).height
        return CGSize(width: available, height: max(textHeight, trailingBasis))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let w = widths(subviews, available: bounds.width)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: w.text, height: nil))
        subviews[1].place(at: CGPoint(x: bounds.maxX, y: bounds.midY), anchor: .trailing,
                          proposal: ProposedViewSize(width: w.trailing, height: trailingBasis))
    }
}
