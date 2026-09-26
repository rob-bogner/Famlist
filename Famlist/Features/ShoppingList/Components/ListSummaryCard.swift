/*
 ListSummaryCard.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Listen-Karte im Sheet „Meine Listen“: Höhe 76, Radius 22, Rahmen 1,5, Inhalt 14 eingerückt.
   [Kachel 48 · 14 · Name Outfit 17/600 + Stern 16 / 3 / „n Artikel“ 13 · Auswahl-Häkchen 32]

 🔰 Notes for Beginners:
 - Aktive Liste: Rahmen in Akzent + 4-pt-Ring und Häkchen. Andere Listen: neutraler Rahmen.
 - Stern = Favorit (profiles.favorite_list_id, öffnet beim App-Start).
 - Famlist-Ergänzung (nicht im Design): Personen-Symbol neben dem Namen, wenn die Liste jemand anderem gehört.
 - Tippen wechselt die Liste, langer Druck öffnet die Listen-Optionen (MyListsSheet).

 📝 Last Change:
 - Stern zeigt den Favoriten; Symbol für geteilte Listen als SVG statt SF Symbol (Handoff 24.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Card for one list in the "Meine Listen" sheet.
struct ListSummaryCard: View {
    let k: SheetTheme
    let list: ListModel
    let itemCount: Int
    let isSelected: Bool
    var isShared = false
    /// Favorit (öffnet beim App-Start) → gelber Stern wie im Design.
    var isFavorite = false

    var body: some View {
        HStack(spacing: 14) {
            tile
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(list.title)
                        .font(AppFont.outfit(17, 600))
                        .foregroundStyle(k.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    if isFavorite {
                        SVGFilledIcon(Icon.star, size: 16, color: .hex("#F5B521"), lineWidth: 1.5)
                            .accessibilityLabel("Favorit")
                    }
                    if isShared {
                        SVGIcon(ListAccountIcon.members, size: 16, color: k.accentText, lineWidth: 1.9)
                            .accessibilityLabel("Geteilte Liste")
                    }
                }
                Text(itemCount == 1 ? "1 Artikel" : "\(itemCount) Artikel")
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(k.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected { selectedCheck }
        }
        .padding(14)                          // 1,5 border + 12,5 padding
        .frame(height: 76)
        .contentShape(RR(22))
        .background(CSSBox(shape: RR(22), paint: cardPaint, border: 1.5, borderColor: borderColor, shadows: shadows))
    }

    // MARK: - Parts

    /// Kachel 48 × 48, Radius 16, Verlauf 150° light → deep.
    private var tile: some View {
        SVGIcon(Icon.listBullets, size: 22, color: .white, lineWidth: 2)
            .frame(width: 48, height: 48)
            .background(CSSBox(shape: RR(16),
                               paint: .linear(150, [stop(k.a.light.color(), 0), stop(k.a.deep.color(), 1)]),
                               shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45)),
                                         .drop(0, 6, 14, -4, k.a.base.color(0.6))]))
    }

    private var selectedCheck: some View {
        SVGIcon(Icon.check, size: 16, color: .white, lineWidth: 2.8)
            .frame(width: 32, height: 32)
            .background(CSSBox(
                shape: Circle(),
                paint: .radialCircle(UnitPoint(x: 0.32, y: 0.22),
                                     [stop(k.a.light.color(), 0), stop(k.a.base.color(), 0.45), stop(k.a.deep.color(), 1)]),
                shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45)),
                          .drop(0, 6, 14, -6, k.a.base.color(0.6))]))
    }

    // MARK: - Styling

    private var cardPaint: Paint {
        k.isDark
            ? .linear(180, [stop(.rgba(255, 255, 255, 0.07), 0), stop(.rgba(255, 255, 255, 0.03), 1)])
            : .color(.white)
    }

    private var cardShadow: [BoxShadow] {
        k.isDark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
            : [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]
    }

    /// Nicht ausgewählte Karten: neutraler Rahmen statt Akzent-Ring.
    private var borderColor: Color {
        isSelected ? k.ring : (k.isDark ? .rgba(255, 255, 255, 0.08) : .hex("#EDF2F2"))
    }

    private var shadows: [BoxShadow] {
        isSelected ? [.drop(0, 0, 0, 4, k.ringSoft)] + cardShadow : cardShadow
    }
}

#Preview {
    let owner = UUID()
    VStack(spacing: 10) {
        ListSummaryCard(k: SheetTheme(.light),
                        list: ListModel(id: UUID(), ownerId: owner, title: "My List", isDefault: true,
                                        createdAt: Date(), updatedAt: Date()),
                        itemCount: 1, isSelected: true)
        ListSummaryCard(k: SheetTheme(.light),
                        list: ListModel(id: UUID(), ownerId: owner, title: "Drogerie", isDefault: false,
                                        createdAt: Date(), updatedAt: Date()),
                        itemCount: 4, isSelected: false, isShared: true)
    }
    .padding(20)
}

#Preview("Dark") {
    let owner = UUID()
    VStack(spacing: 10) {
        ListSummaryCard(k: SheetTheme(.dark),
                        list: ListModel(id: UUID(), ownerId: owner, title: "My List", isDefault: true,
                                        createdAt: Date(), updatedAt: Date()),
                        itemCount: 1, isSelected: true)
        ListSummaryCard(k: SheetTheme(.dark),
                        list: ListModel(id: UUID(), ownerId: owner, title: "Drogerie", isDefault: false,
                                        createdAt: Date(), updatedAt: Date()),
                        itemCount: 4, isSelected: false, isShared: true)
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
