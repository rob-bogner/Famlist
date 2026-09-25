/*
 SearchResultCard.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Treffer-Karte der Sheet „Artikel suchen“: Padding 10, Rahmen 1, Radius 22, Bild 52, Plus-Knopf 44.
   Ersetzt ItemCatalogRow.

 🔰 Notes for Beginners:
 - Bildquelle: Base64 aus dem persönlichen Katalog, sonst die OpenFoodFacts-URL (nur online),
   sonst das Einkaufswagen-Icon.
 - Unterzeile „Marke · Menge“ wie im Design. Der ★ für persönliche Einträge entfällt (nicht im Design).

 📝 Last Change:
 - Aus SearchScreen des Design-Pakets MyListUI übernommen, an SearchResult angebunden.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Result card with thumbnail, name, "brand · size" and add button.
struct SearchResultCard: View {
    let k: SheetTheme
    let result: SearchResult
    var onAdd: () -> Void = {}

    private var subtitle: String {
        let measure = result.entry.measure
        let size = Measure(rawValue: measure)?.localizedName ?? measure
        return [result.entry.brand, size].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        let dark = k.isDark
        HStack(spacing: 14) {
            thumbnail
                .frame(width: 52, height: 52)
                .clipShape(RR(16))
                .background(CSSBox(shape: RR(16), paint: thumbPaint, shadows: dark
                    ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.12))]
                    : [.inner(0, 1, 0, 0, .white)]))
            VStack(alignment: .leading, spacing: 3) {
                Text(result.entry.name)
                    .font(AppFont.outfit(16, 600))
                    .foregroundStyle(k.text)
                    .cssLineHeight(20, font: AppFont.ui(.outfit, 16, 600))   // line-height 1.25
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            addButton
        }
        .padding(11)                       // 10 padding + 1 border (content-box)
        .background(CSSBox(shape: RR(22), paint: cardPaint, border: 1,
                           borderColor: dark ? .rgba(255, 255, 255, 0.08) : .hex("#EDF2F2"),
                           shadows: dark
                               ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 12, 24, -14, .rgba(0, 0, 0, 0.7))]
                               : [.drop(0, 1, 2, 0, .rgba(12, 40, 44, 0.05)), .drop(0, 10, 22, -14, .rgba(12, 40, 44, 0.22))]))
        .contentShape(RR(22))
        .onTapGesture(perform: onAdd)
    }

    // MARK: - Parts

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ImageCache.shared.image(fromBase64: result.entry.imageData) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let urlString = result.imageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        SVGIcon(Icon.cart, size: 22, color: k.isDark ? k.a.light.color() : .hex("#7D9498"), lineWidth: 1.8)
    }

    private var addButton: some View {
        let dark = k.isDark
        let a = k.a
        return Button(action: onAdd) {
            SVGIcon(Icon.plus, size: 20, color: k.accentText, lineWidth: 2.4)
                .frame(width: 44, height: 44)
                .background(CSSBox(shape: Circle(),
                                   paint: dark ? .color(a.base.color(0.14)) : .linear(180, [stop(.white, 0), stop(a.base.color(0.1), 1)]),
                                   border: 1,
                                   borderColor: a.base.color(dark ? 0.35 : 0.25),
                                   shadows: dark
                                       ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.12))]
                                       : [.inner(0, 1, 0, 0, .white), .drop(0, 6, 14, -8, a.base.color(0.6))]))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.entry.name) hinzufügen")
    }

    private var cardPaint: Paint {
        k.isDark
            ? .linear(180, [stop(.rgba(255, 255, 255, 0.07), 0), stop(.rgba(255, 255, 255, 0.03), 1)])
            : .color(.white)
    }

    private var thumbPaint: Paint {
        k.isDark
            ? .linear(150, [stop(k.a.base.color(0.22), 0), stop(k.a.base.color(0.06), 1)])
            : .linear(150, [stop(.hex("#F2F7F7"), 0), stop(.hex("#E4EEEF"), 1)])
    }
}

#Preview("SearchResultCard") {
    SearchResultCard(k: SheetTheme(.light), result: SearchResult(
        entry: ItemCatalogEntry(id: "preview-1", ownerPublicId: "owner", name: "Butter", brand: "Kerrygold",
                                category: nil, productDescription: nil, measure: "pack", price: 2.49, imageData: nil),
        source: .personal, imageUrl: nil))
        .padding(20)
}

#Preview("SearchResultCard – Dark") {
    SearchResultCard(k: SheetTheme(.dark), result: SearchResult(
        entry: ItemCatalogEntry(id: "preview-1", ownerPublicId: "owner", name: "Butter", brand: "Kerrygold",
                                category: nil, productDescription: nil, measure: "pack", price: 2.49, imageData: nil),
        source: .personal, imageUrl: nil))
        .padding(20)
        .background(Color.hex("#0A1416"))
}
