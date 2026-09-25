/*
 ReceiptMissingItemCard.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Karte in „Kassenzettel prüfen“ → „Nicht auf dem Bon gefunden“: abgehakter Artikel ohne Bon-Zeile.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptReview.dc.html (Ansicht „missing“, Canvas 26.09.2026). Oben wie die Artikelkarte der
   Liste (Bild 64, Name Outfit 19/600, Mengen-Chip), rechts „Fehlt auf dem Bon“ statt der Checkbox.
 - Darunter drei Knöpfe: Zuordnen (freie Bon-Zeilen, ähnlichste zuerst), Preis eingeben, Nicht gekauft.
 - Erledigt: „Nicht gekauft“ blendet Bild/Name/Menge ab (55 %), „Rückgängig“ bleibt voll sichtbar.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptMissingItemCard: View {
    let item: ItemModel
    let resolution: ReceiptMissingResolution?
    let suggestions: [ReceiptReviewLine]
    let appearance: Appearance
    var onAssign: (UUID) -> Void = { _ in }
    var onPrice: (Decimal) -> Void = { _ in }
    var onNotBought: () -> Void = {}
    var onUndo: () -> Void = {}

    private enum Mode { case none, assign, price }
    @State private var mode: Mode = .none
    @State private var priceText = "0.0"

    var body: some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)
        let lt = ListTheme(appearance)
        let dimmed = resolution == .notBought

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ItemThumbnailTile(t: lt, image: item.image)
                    .opacity(dimmed ? 0.55 : 1)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(AppFont.outfit(19, 600))
                        .foregroundStyle(k.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(item.quantityText)
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(lt.accentText)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 11)
                        .background(CSSBox(shape: Pill, paint: .color(lt.chipBg), shadows: lt.chipInset))
                        .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(dimmed ? 0.55 : 1)
                trailing(k: k, t: t)
            }

            switch resolution {
            case .some(.notBought):
                resolvedLine(icon: Icon.rotateBack, color: k.sub, text: "Nicht gekauft · wieder offen auf der Liste", k: k)
            case .some(.priced(let price)):
                resolvedLine(icon: Icon.check, color: t.ok, text: "Preis \(Self.euro(price)) eingegeben", k: k)
            case .none:
                actions(k: k)
                if mode == .assign { assignList(k: k) }
                if mode == .price { priceEntry(k: k) }
            }
        }
        .padding(15)                                            // 1 Rahmen + 14 Padding
        .background(CSSBox(shape: RR(24), paint: t.card, border: 1,
                           borderColor: mode != .none && resolution == nil ? k.ring : t.cardBorder,
                           shadows: t.cardShadow))
        .animation(.easeOut(duration: 0.2), value: mode)
        .animation(.easeOut(duration: 0.2), value: resolution)
    }

    // MARK: - Teile

    @ViewBuilder
    private func trailing(k: SheetTheme, t: EKKTokens) -> some View {
        if resolution == nil {
            HStack(spacing: 4) {
                SVGIcon(EKKIcon.alert, size: 14, color: t.warn, lineWidth: 2.4)
                Text("Fehlt auf dem Bon")
                    .font(AppFont.dm(12, 600))
                    .foregroundStyle(t.warn)
            }
            .fixedSize()
        } else {
            Button(resolution == .notBought ? "Rückgängig" : "Ändern", action: {
                mode = resolution == .notBought ? .none : .price
                onUndo()
            })
            .font(AppFont.dm(13, 600))
            .foregroundStyle(k.accentText)
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            .fixedSize()
        }
    }

    /// Chips 34 hoch, Padding 11, Abstand 6; der aktive in CTA-Farbe.
    private func actions(k: SheetTheme) -> some View {
        HStack(spacing: 6) {
            chip("Zuordnen", active: mode == .assign, k: k) { mode = mode == .assign ? .none : .assign }
            chip("Preis eingeben", active: mode == .price, k: k) { mode = mode == .price ? .none : .price }
            chip("Nicht gekauft", active: false, muted: true, k: k) { mode = .none; onNotBought() }
        }
    }

    private func chip(_ title: String, active: Bool, muted: Bool = false, k: SheetTheme,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(active ? k.ctaText : (muted ? k.sub : k.accentText))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(CSSBox(shape: Pill, paint: active ? k.ctaPaint : .color(muted ? k.field : k.chip)))
                .contentShape(Pill)
                .fixedSize()
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// „Bon-Zeilen ohne Artikel“: je Zeile Rohtext (Mono 12), Preis, runder Haken 28.
    @ViewBuilder
    private func assignList(k: SheetTheme) -> some View {
        Text("Bon-Zeilen ohne Artikel")
            .font(AppFont.dm(12, 600))
            .foregroundStyle(k.sub)
            .padding(.horizontal, 2)
        if suggestions.isEmpty {
            Text("Keine freien Bon-Zeilen – trag den Preis selbst ein.")
                .font(AppFont.dm(13, 400))
                .foregroundStyle(k.sub)
                .padding(.horizontal, 2)
        }
        ForEach(suggestions) { line in
            Button(action: { mode = .none; onAssign(line.id) }) {
                HStack(spacing: 10) {
                    Text(line.raw)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(k.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Self.euro(line.price))
                        .font(AppFont.outfit(15, 600))
                        .foregroundStyle(k.text)
                        .fixedSize()
                    SVGIcon(Icon.check, size: 14, color: k.ctaText, lineWidth: 2.8)
                        .frame(width: 28, height: 28)
                        .background(CSSBox(shape: Circle(), paint: k.ctaPaint))
                }
                .padding(.vertical, 10)
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .background(CSSBox(shape: RR(14), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                .contentShape(RR(14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(line.raw), \(Self.euro(line.price)), \(item.name) zuordnen")
        }
    }

    /// Preisfeld wie in „Artikel bearbeiten“ (148 × 52) + „Übernehmen“.
    private func priceEntry(k: SheetTheme) -> some View {
        let value = Decimal(string: priceText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
        return HStack(spacing: 10) {
            SheetPriceField(k: k, price: $priceText)
            Button(action: { onPrice(value); mode = .none }) {
                Text("Übernehmen")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.ctaText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(CSSBox(shape: RR(16), paint: k.ctaPaint, shadows: k.ctaShadow))
                    .contentShape(RR(16))
            }
            .buttonStyle(.plain)
            .disabled(value <= 0)
            .opacity(value > 0 ? 1 : 0.45)
        }
    }

    private func resolvedLine(icon: [SVGElement], color: Color, text: String, k: SheetTheme) -> some View {
        HStack(spacing: 6) {
            SVGIcon(icon, size: 14, color: color, lineWidth: 2.2)
            Text(text)
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
        }
        .padding(.horizontal, 2)
    }

    static func euro(_ value: Decimal) -> String {
        value.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
    }
}

#Preview("Nicht gefunden", traits: .fixedLayout(width: 390, height: 700)) {
    let line = ReceiptReviewLine(id: UUID(), raw: "FAIRGL.VM SCHOKO", price: 3.49, itemName: nil, status: .new)
    VStack(spacing: 12) {
        ReceiptMissingItemCard(item: ItemModel(name: "Schokolade", units: 1), resolution: nil,
                               suggestions: [line], appearance: .light)
        ReceiptMissingItemCard(item: ItemModel(name: "Toastbrot", units: 1, measure: "pack"),
                               resolution: .notBought, suggestions: [], appearance: .light)
    }
    .padding(20)
}

#Preview("Nicht gefunden – Dark", traits: .fixedLayout(width: 390, height: 700)) {
    VStack(spacing: 12) {
        ReceiptMissingItemCard(item: ItemModel(name: "Bananen", units: 6), resolution: nil,
                               suggestions: [], appearance: .dark)
        ReceiptMissingItemCard(item: ItemModel(name: "Milch", units: 1), resolution: .priced(1.19),
                               suggestions: [], appearance: .dark)
    }
    .padding(20)
    .background(Color.hex("#0A1416"))
}
