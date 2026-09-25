/*
 PopoverMenuRow.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Menüzeile: Icon 20 · Titel 15 (+ Untertitel) · rechter Inhalt; regulär 56 oder kompakt 48 hoch.

 🔰 Notes for Beginners:
 - Übernommen aus design-handoff/MyListUI/Components/OverlayComponents.swift.
   Werte 1:1 aus dem Design (1 CSS-px = 1 pt), nicht runden oder „verschönern“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Menüzeile: Icon 20 (Strich 1.9) · 12 · Titel 15 (+ Untertitel 12, Abstand 1) · 12 · Trailing.
/// • `.regular` – min-height 56, padding 8 12 (Zeilen mit Untertitel)
/// • `.compact` – height 48, padding 0 12 (Kontext-Menü)
/// Radius 16, Hintergrund optional (Hervorhebung / Gefahr).
struct PopoverMenuRow: View {
    enum Size {
        case regular
        case compact
    }

    let k: OverlayTheme
    let icon: [SVGElement]
    let title: String
    var subtitle: String? = nil
    var trailing: PopoverMenuTrailing = .empty
    var size: Size = .regular
    var titleWeight: CGFloat = 500
    /// Text- und Icon-Farbe (z. B. `k.danger`); nil → Titel `text`, Icon `accentText`
    var tint: Color? = nil
    var background: Color = .clear
    var isSelected = false
    /// opacity .45 + nicht bedienbar
    var isDisabled = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SVGIcon(icon, size: 20, color: tint ?? k.accentText, lineWidth: 1.9)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(AppFont.dm(15, titleWeight))
                        .foregroundStyle(tint ?? k.text)
                        .lineLimit(size == .compact ? 1 : nil)
                        .minimumScaleFactor(1 / AppFont.maxScale)   // XXL: höchstens bis zur Designgröße schrumpfen
                    if let subtitle {
                        Text(subtitle)
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailingView
            }
            .padding(.horizontal, 12)
            .padding(.vertical, size == .regular ? 8 : 0)
            .frame(maxWidth: .infinity)
            .frame(minHeight: size == .regular ? 56 : 48)
            .frame(height: size == .compact ? 48 : nil)
            .background(RR(16).fill(background))
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .opacity(isDisabled ? 0.45 : 1)
        // Kein `.disabled`: das System könnte den Inhalt zusätzlich abblenden.
        .allowsHitTesting(!isDisabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isDisabled ? .isButton : [])
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .empty:
            EmptyView()
        case .check:
            SVGIcon(Icon.check, size: 18, color: k.accentText, lineWidth: 2.4)
        case .text(let value, let weight, let color):
            Text(value)
                .font(AppFont.dm(13, weight))
                .foregroundStyle(color ?? k.sub)
        }
    }
}

#Preview("PopoverMenuRow") {
    let k = OverlayTheme(.light)
    VStack(spacing: 0) {
        PopoverMenuRow(k: k, icon: Icon.sort, title: "Name", subtitle: "A bis Z", trailing: .check, isSelected: true)
        PopoverMenuRow(k: k, icon: Icon.trash, title: "Löschen", tint: k.danger)
    }
    .frame(width: 270)
    .padding(20)
}

#Preview("PopoverMenuRow – Dark") {
    let k = OverlayTheme(.dark)
    VStack(spacing: 0) {
        PopoverMenuRow(k: k, icon: Icon.sort, title: "Name", subtitle: "A bis Z", trailing: .check, isSelected: true)
        PopoverMenuRow(k: k, icon: Icon.trash, title: "Löschen", tint: k.danger)
    }
    .frame(width: 270)
    .padding(20)
    .background(Color.hex("#0A1416"))
}
