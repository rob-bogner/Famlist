//  MyListsScreen.swift
//  MyListUI
//
//  Sheet „Meine Listen“ (Listenverwaltung) – Höhe 790 (oben 54 pt Luft auf 844), unten bündig.
//  Quelle: Design/html/MyLists.dc.html (Dark: MyListsDark.dc.html)
//  Wird auch als Hintergrund von CreateListScreen und ListOptionsScreen eingebettet.
//
//  Innenabstand oben 1 (Rahmen) + 10, seitlich 20:
//    Griff 5 → 12 → Titelzeile 44 → 20 → „1 Liste“ 13/600 in Großbuchstaben → 10 → Listen-Karten (Abstand 10)
//  Listen-Karte: Höhe 76, Radius 22, Rahmen 1,5, Padding 12,5 (→ Inhalt 14 eingerückt)
//    [Kachel 48 · 14 · Name Outfit 17/600 + Stern 16 (Abstand 6) / 3 / „n Artikel“ 13 · Auswahl-Häkchen 32]
//  Aktive Liste: Rahmen in Akzent + 4-pt-Ring.
//  Primär-Button „Neue Liste erstellen“: unten 34, links/rechts 20.

import SwiftUI

struct ShoppingListSummary: Identifiable, Hashable {
    let id: UUID
    let name: String
    let itemCount: Int
    let isFavorite: Bool

    init(id: UUID = UUID(), name: String, itemCount: Int, isFavorite: Bool) {
        self.id = id
        self.name = name
        self.itemCount = itemCount
        self.isFavorite = isFavorite
    }

    static let samples = [ShoppingListSummary(name: "My List", itemCount: 1, isFavorite: true)]
}

struct MyListsScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var lists: [ShoppingListSummary] = ShoppingListSummary.samples
    var selectedID: UUID? = ShoppingListSummary.samples.first?.id
    var onSelect: (ShoppingListSummary) -> Void = { _ in }
    var onClose: () -> Void = {}
    var onCreate: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)

        // Hintergrund Hybrid (ListScreen, Zustand .normal) + blur(3) + Abdunkelung
        return ListAccountBackdrop(scrim: k.scrim) {
            ListScreen(appearance: appearance, accentHex: accentHex)
        } content: {
            SheetSurface(k: k, height: 790) {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        SheetHeader(title: "Meine Listen", k: k, onClose: onClose)
                            .padding(.top, 10)
                            .padding(.horizontal, 20)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(lists.count == 1 ? "1 Liste" : "\(lists.count) Listen")
                                    .font(AppFont.dm(13, 600))
                                    .tracking(0.52)                              // 0.04em × 13
                                    .textCase(.uppercase)
                                    .foregroundStyle(k.sub)
                                    .padding(.horizontal, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(lists) { list in
                                    ListSummaryCard(k: k, list: list, isSelected: list.id == selectedID) {
                                        onSelect(list)
                                    }
                                }
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 128)   // Platz unter dem Button
                        }
                        .scrollIndicators(.hidden)
                    }

                    CTAButton(title: "Neue Liste erstellen", k: k, action: onCreate)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 34)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

private struct ListSummaryCard: View {
    let k: SheetTheme
    let list: ShoppingListSummary
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let dark = k.isDark
        let a = k.a
        let card: Paint = dark
            ? .linear(180, [stop(.rgba(255, 255, 255, 0.07), 0), stop(.rgba(255, 255, 255, 0.03), 1)])
            : .color(.white)
        let cardShadow: [BoxShadow] = dark
            ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
            : [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]
        // Nicht ausgewählte Karten: neutraler Rahmen statt Akzent-Ring
        let borderColor: Color = isSelected ? k.ring : (dark ? .rgba(255, 255, 255, 0.08) : .hex("#EDF2F2"))
        let shadows: [BoxShadow] = isSelected ? [.drop(0, 0, 0, 4, k.ringSoft)] + cardShadow : cardShadow

        return Button(action: action) {
            HStack(spacing: 14) {
                // Kachel 48 × 48, Radius 16, Verlauf 150° light → deep
                SVGIcon(Icon.listBullets, size: 22, color: .white, lineWidth: 2)
                    .frame(width: 48, height: 48)
                    .background(CSSBox(shape: RR(16),
                                       paint: .linear(150, [stop(a.light.color(), 0), stop(a.deep.color(), 1)]),
                                       shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45)),
                                                 .drop(0, 6, 14, -4, a.base.color(0.6))]))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(list.name)
                            .font(AppFont.outfit(17, 600))
                            .foregroundStyle(k.text)
                            .lineLimit(1)
                        if list.isFavorite {
                            SVGFilledIcon(Icon.star, size: 16, color: .hex("#F5B521"), lineWidth: 1.5)
                                .accessibilityLabel("Favorit")
                        }
                    }
                    Text(list.itemCount == 1 ? "1 Artikel" : "\(list.itemCount) Artikel")
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    SVGIcon(Icon.check, size: 16, color: .white, lineWidth: 2.8)
                        .frame(width: 32, height: 32)
                        .background(CSSBox(
                            shape: Circle(),
                            paint: .radialCircle(UnitPoint(x: 0.32, y: 0.22),
                                                 [stop(a.light.color(), 0), stop(a.base.color(), 0.45), stop(a.deep.color(), 1)]),
                            shadows: [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.45)),
                                      .drop(0, 6, 14, -6, a.base.color(0.6))]))
                }
            }
            .padding(14)                          // 1,5 border + 12,5 padding
            .frame(height: 76)
            .background(CSSBox(shape: RR(22), paint: card, border: 1.5, borderColor: borderColor, shadows: shadows))
            .contentShape(RR(22))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
