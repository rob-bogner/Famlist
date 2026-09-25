/*
 PriceHistorySheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Preisverlauf“ (Höhe 754): Artikel, Tiefster/Schnitt/Höchster Preis, Diagramm der letzten
   7 Monate, „Nach Laden“ mit Markierung „GÜNSTIGSTER“.

 🔰 Notes for Beginners:
 - Vorlage: PriceHistoryScreen in design-handoff/MyListUI/Screens/ItemExtraScreens.swift (PriceHistory.dc.html).
 - Erreichbar vorerst über das System-Kontextmenü in „Artikel verwalten“ (SPEC §5, Übergangslösung).
 - Der Design-Hinweis „Beispielwerte · …“ erscheint nur ohne Preise, als „Noch keine Preise · …“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct PriceHistorySheet: View {
    @StateObject private var vm: PriceHistoryViewModel
    let appearance: Appearance
    var onClose: () -> Void = {}

    init(viewModel: PriceHistoryViewModel, appearance: Appearance, onClose: @escaping () -> Void = {}) {
        _vm = StateObject(wrappedValue: viewModel)
        self.appearance = appearance
        self.onClose = onClose
    }

    var body: some View {
        let k = SheetTheme(appearance)
        let t = ItemExtraTokens(appearance)
        // Inline-SVG sitzt auf der Grundlinie → darunter bleibt die Unterlänge der Zeile (DM Sans 16, line-height normal).
        let svgDescent = abs(AppFont.ui(.dmSans, 16, 400).descender)
        let stats = vm.stats

        SheetScreen(appearance: appearance, accentHex: nil) {
            SheetSurface(k: k, height: 754) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Preisverlauf", k: k, onClose: onClose)

                    // Produkt
                    HStack(spacing: 14) {
                        SVGIcon(ItemExtraIcon.cartBody, size: 22, color: k.accentText, lineWidth: 1.8)
                            .frame(width: 52, height: 52)
                            .background(CSSBox(shape: RR(16), paint: t.tile))
                        VStack(alignment: .leading, spacing: 2) {
                            Text([vm.entry.brand, vm.entry.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                                .font(AppFont.outfit(17, 600))
                                .foregroundStyle(k.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(vm.subtitle)
                                .font(AppFont.dm(13, 400))
                                .foregroundStyle(k.sub)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 16)

                    // Kennzahlen: grid 3 × 1fr, gap 8
                    HStack(spacing: 8) {
                        statTile("Tiefster", stats.min, k: k)
                        statTile("Schnitt", stats.average, k: k)
                        statTile("Höchster", stats.max, k: k)
                    }
                    .padding(.top, 16)

                    // Diagramm-Karte
                    VStack(spacing: 0) {
                        PriceHistoryChart(line: t.line, areaFill: t.areaFill, accent: k.accent, dotFill: t.dotFill,
                                          values: stats.months.map { $0.average.map { NSDecimalNumber(decimal: $0).doubleValue } },
                                          average: stats.average.map { NSDecimalNumber(decimal: $0).doubleValue })
                            .frame(height: 160)
                            .accessibilityLabel("Preisverlauf der letzten 7 Monate")
                        Color.clear.frame(height: svgDescent)
                        HStack(spacing: 0) {
                            ForEach(Array(vm.monthLabels.enumerated()), id: \.offset) { i, m in
                                if i > 0 { Spacer(minLength: 0) }
                                Text(m)
                                    .font(AppFont.dm(11, 400))
                                    .foregroundStyle(k.sub)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.top, 17)                                  // 1 border + 16 padding
                    .padding(.horizontal, 17)
                    .padding(.bottom, 11)                               // 1 border + 10 padding
                    .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
                    .padding(.top, 16)

                    Text("Nach Laden")
                        .font(AppFont.dm(13, 600))
                        .tracking(0.52)                                 // 0.04em × 13
                        .textCase(.uppercase)
                        .foregroundStyle(k.sub)
                        .padding(.horizontal, 4)
                        .padding(.top, 18)

                    if !stats.stores.isEmpty {
                        // Laden-Liste: Radius 20, Rahmen 1, Zeilen min. 56 (border-box), Trennlinie 1
                        VStack(spacing: 0) {
                            ForEach(Array(stats.stores.prefix(4).enumerated()), id: \.offset) { i, row in
                                if i > 0 { Rectangle().fill(t.line).frame(height: 1) }
                                storeRow(row, minHeight: i == 0 ? 56 : 55, k: k, t: t)
                            }
                        }
                        .padding(1)
                        .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.cardBorder))
                        .clipShape(RR(20))
                        .padding(.top, 10)
                    }

                    if stats.stores.isEmpty {
                        Text(vm.isLoading ? "Preise werden geladen …" : "Noch keine Preise · Preis bei „Artikel bearbeiten“ eintragen oder Kassenzettel scannen")
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task { await vm.load() }
    }

    private func statTile(_ label: String, _ value: Decimal?, k: SheetTheme) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
            Text(PriceHistoryViewModel.euro(value))
                .font(AppFont.outfit(17, 600))
                .foregroundStyle(k.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 11)                     // 1 border + 10 padding
        .padding(.horizontal, 13)                   // 1 border + 12 padding
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
        .accessibilityElement(children: .combine)
    }

    /// Laden-Zeile: Innenabstand 8 / 14, Abstand 12. Badge: 3 / 8, Pille, 11 pt.
    private func storeRow(_ row: PriceStatistics.StoreRow, minHeight: CGFloat, k: SheetTheme, t: ItemExtraTokens) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.store)
                    .font(AppFont.dm(15, 500))
                    .foregroundStyle(k.text)
                Text(PriceHistoryViewModel.lastSeen(row.lastDate))
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if row.isCheapest {
                Text("GÜNSTIGSTER")
                    .font(AppFont.dm(11, 600))
                    .foregroundStyle(t.ok)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule(style: .circular).fill(t.okSoft))
            }
            Text(PriceHistoryViewModel.euro(row.lastPrice))
                .font(AppFont.outfit(16, 600))
                .foregroundStyle(k.text)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(minHeight: minHeight)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Preisverlauf", traits: .fixedLayout(width: 390, height: 844)) {
    PriceHistorySheet(viewModel: PriceHistoryViewModel(entry: .priceHistorySample, priceBook: .designSample),
                      appearance: .light)
}

#Preview("Preisverlauf – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    PriceHistorySheet(viewModel: PriceHistoryViewModel(entry: .priceHistorySample, priceBook: .designSample),
                      appearance: .dark)
}

extension ItemCatalogEntry {
    /// Beispiel aus PriceHistory.dc.html („Kerrygold Butter“).
    static let priceHistorySample = ItemCatalogEntry(id: "sample", ownerPublicId: "", name: "Butter", brand: "Kerrygold",
                                                     category: nil, productDescription: nil, measure: "",
                                                     price: 0, imageData: nil)
}

extension PriceBook {
    /// Beispielwerte aus PriceHistory.dc.html (Mär … Sep, Edeka und Lidl).
    @MainActor static var designSample: PriceBook {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let values: [Decimal] = [2.19, 2.29, 2.29, 2.49, 2.39, 2.59, 2.49]
        let points = values.enumerated().map { i, v in
            PricePoint(itemName: "Butter", storeName: i == 0 ? "Lidl" : "Edeka",
                       purchasedAt: cal.date(byAdding: .month, value: i - 6, to: now) ?? now, price: v)
        }
        return PriceBook(repository: InMemoryPricePointsRepository(points),
                         defaults: UserDefaults(suiteName: "priceBookPreview") ?? .standard)
    }
}
