/*
 InlineSearchResultRow.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Trefferzeile im Hinzufügen-Pop-up (AddInline.dc.html).

 🔰 Notes for Beginners:
 - 56 hoch, Innenabstand 0 6 0 8, Radius 16: Bild 40 (Radius 13), Name Outfit 16/500 mit hervorgehobenem
   Suchbegriff (700, Akzentfarbe), darunter „Marke · Größe“ DM 12 und ggf. „Auf der Liste“, rechts Glas-„+“ 40.
 - Steht der Artikel schon auf der Liste, erhöht „+“ die Menge (ListViewModel.addItem erkennt das).

 📝 Last Change:
 - Bild-Kachel nur mit „Artikelbilder anzeigen“ (30.09.2026).
 - Maße aus AddInline, „+“ als Glas-Knopf (GlassOrb, Akzent).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InlineSearchResultRow: View {
    let k: SheetTheme
    let result: SearchResult
    let query: String
    var isInList = false
    /// Kurz nach dem Hinzufügen: Haken statt „+“.
    var justAdded = false
    var onAdd: () -> Void = {}
    @AppStorage(ItemImageSetting.storageKey) private var showImages = ItemImageSetting.defaultValue

    private var subtitle: String {
        let measure = result.entry.measure
        let size = Measure(rawValue: measure)?.localizedName ?? measure
        return [result.entry.brand, size].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            if showImages {
                thumbnail
                    .frame(width: 40, height: 40)
                    .clipShape(RR(13))
                    .background(CSSBox(shape: RR(13), paint: thumbPaint, shadows: k.isDark
                        ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.12))]
                        : [.inner(0, 1, 0, 0, .white)]))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(highlightedName)
                    .font(AppFont.outfit(16, 500))
                    .foregroundStyle(k.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if !subtitle.isEmpty {
                        Text(subtitle).font(AppFont.dm(12, 400)).foregroundStyle(k.sub).lineLimit(1)
                    }
                    if isInList {
                        Text("Auf der Liste")
                            .font(AppFont.dm(12, 600))
                            .foregroundStyle(k.accentText)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 7)
                            .background(Capsule().fill(k.a.base.color(k.isDark ? 0.22 : 0.16)))
                            .fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            addButton
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .frame(height: 56)
        .contentShape(RR(16))
        .onTapGesture(perform: onAdd)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([result.entry.name, subtitle, isInList ? "auf der Liste" : ""].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityHint(isInList ? "Menge erhöhen" : "Zur Liste hinzufügen")
        .accessibilityAddTraits(.isButton)
    }

    /// Suchbegriff im Namen: fett (700) in Akzentfarbe, ohne Groß/klein.
    private var highlightedName: AttributedString {
        var text = AttributedString(result.entry.name)
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty, let range = text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
            text[range].font = AppFont.outfit(16, 700)
            text[range].foregroundColor = k.accentText
        }
        return text
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = ImageCache.shared.image(fromBase64: result.entry.imageData) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if let urlString = result.imageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFill() } else { placeholderIcon }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        SVGIcon(Icon.cart, size: 18, color: k.isDark ? k.a.light.color() : .hex("#7D9498"), lineWidth: 1.8)
    }

    private var addButton: some View {
        Button(action: onAdd) {
            GlassOrb(style: .accent, appearance: k.appearance, accent: k.a, icon: justAdded ? Icon.check : Icon.plus,
                     size: 40, lineWidth: 2.4)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(-2)                                   // Optik 40, Trefferfläche 44
        .accessibilityHidden(true)
    }

    private var thumbPaint: Paint {
        k.isDark
            ? .linear(150, [stop(k.a.base.color(0.22), 0), stop(k.a.base.color(0.06), 1)])
            : .linear(150, [stop(.hex("#F2F7F7"), 0), stop(.hex("#E4EEEF"), 1)])
    }
}
