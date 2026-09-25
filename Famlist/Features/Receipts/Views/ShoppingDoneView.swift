/*
 ShoppingDoneView.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild „Einkauf erledigt“: Hero mit Haken, Summe, Anzahl gespeicherter Preise, Hinweis zum
   Preisverlauf, „Abgehakte löschen & fertig“ / „Liste behalten“.

 🔰 Notes for Beginners:
 - Vorlage: ShoppingDoneScreen in design-handoff/MyListUI/Screens/ReceiptScreens.swift (ShoppingDone.dc.html).
 - „alle n Artikel abgehakt“ nur, wenn alle Artikel der Liste abgehakt sind; sonst „n von m Artikeln abgehakt“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ShoppingDoneView: View {
    let appearance: Appearance
    var listName = "My List"
    var itemCount = 6
    /// Alle Artikel der Liste; nil = wie itemCount (alle abgehakt, Design).
    var totalCount: Int?
    var total: Decimal = 11.51
    var savedPrices = 5
    /// false = noch ohne Kassenzettel (ShoppingDoneScan.dc.html): Angebot „Kassenzettel scannen“ statt Summe.
    var hasReceipt = true
    var onFinish: () -> Void = {}
    var onKeep: () -> Void = {}
    var onScan: () -> Void = {}

    /// Kopfbereich: 420 wie im Design (844 hoch). Auf kleineren Geräten (iPhone SE, 667) niedriger, damit
    /// Karten und Knöpfe darunter Platz haben – vorher lag der Knopf über der Hinweiskarte.
    static func heroHeight(screenHeight: CGFloat) -> CGFloat {
        min(420, max(280, screenHeight - 424))
    }

    var body: some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)
        GeometryReader { geo in
            ZStack(alignment: .top) {
                EKKScreenBackground(t: t)
                ScrollView {
                    VStack(spacing: 0) {
                        hero(t: t, height: Self.heroHeight(screenHeight: geo.size.height))
                        cards(k: k, t: t)
                            .padding(.top, 24)
                        Spacer(minLength: 24)
                        buttons(k: k)
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .ignoresSafeArea()
    }

    private func hero(t: EKKTokens, height: CGFloat) -> some View {
        EKKHero(t: t, height: height) {
            VStack(spacing: 14) {
                SVGIcon(Icon.check, size: 44, color: .white, lineWidth: 2.4)
                    .frame(width: 94, height: 94)
                    .background(EKKGlassBadge(shape: Circle(), size: 94))
                    .accessibilityHidden(true)
                Text("Einkauf erledigt")
                    .font(AppFont.outfit(32, 700))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(1 / AppFont.maxScale)
                    .accessibilityAddTraits(.isHeader)
                Text("\(listName) · \(Self.checkedText(checked: itemCount, total: totalCount ?? itemCount))")
                    .font(AppFont.dm(15, 400))
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 30)
        }
    }

    @ViewBuilder
    private func cards(k: SheetTheme, t: EKKTokens) -> some View {
        let infoFont = AppFont.ui(.dmSans, 14, 400)
        if hasReceipt {
            let totalText = total.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
            receiptSummary(totalText: totalText, infoFont: infoFont, k: k, t: t)
        } else {
            scanOffer(infoFont: infoFont, k: k, t: t)
        }
    }

    @ViewBuilder
    private func buttons(k: SheetTheme) -> some View {
        if hasReceipt {
            VStack(spacing: 8) {
                CTAButton(title: "Abgehakte löschen & fertig", k: k, action: onFinish)
                EKKTextButton(title: "Liste behalten", color: k.accentText, action: onKeep)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
        } else {
            offerButtons(k: k)
        }
    }

    /// Mit Kassenzettel (ShoppingDone.dc.html): Summe, gespeicherte Preise, Hinweis.
    private func receiptSummary(totalText: String, infoFont: UIFont, k: SheetTheme, t: EKKTokens) -> some View {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    statTile("Gesamt", totalText, k: k, t: t)
                    statTile("Preise gespeichert", "\(savedPrices)", k: k, t: t)
                }
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    SVGIcon(EKKIcon.trend, size: 20, color: k.accentText, lineWidth: 1.9)
                        .accessibilityHidden(true)
                    Text("Die Preise fließen in den Preisverlauf der Artikel ein.")
                        .font(AppFont.dm(14, 400))
                        .foregroundStyle(k.sub)
                        .cssLineHeight(19.6, font: infoFont)             // line-height 1.4
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 15)                                   // 1 Rahmen + 14 Padding
                .padding(.horizontal, 17)                                 // 1 Rahmen + 16 Padding
                .background(CSSBox(shape: RR(20), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            }
            .padding(.horizontal, 20)
    }

    /// Ohne Kassenzettel (ShoppingDoneScan.dc.html): Karte „Kassenzettel scannen?“ + Hinweis.
    private func scanOffer(infoFont: UIFont, k: SheetTheme, t: EKKTokens) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                SVGIcon(Icon.camera, size: 24, color: k.accentText, lineWidth: 1.9)
                    .frame(width: 52, height: 52)
                    .background(CSSBox(shape: RR(16), paint: t.tile))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kassenzettel scannen?")
                        .font(AppFont.outfit(17, 600))
                        .foregroundStyle(k.text)
                    Text("Preise werden automatisch erkannt und fließen in den Preisverlauf.")
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(17)
            .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                SVGIcon(EKKIcon.trend, size: 20, color: k.accentText, lineWidth: 1.9)
                    .accessibilityHidden(true)
                Text("Geht auch später über ☰ → Kassenzettel scannen.")
                    .font(AppFont.dm(14, 400))
                    .foregroundStyle(k.sub)
                    .cssLineHeight(19.6, font: infoFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 17)
            .background(CSSBox(shape: RR(20), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
        }
        .padding(.horizontal, 20)
    }

    /// CTA „Kassenzettel scannen“ + zwei Textknöpfe nebeneinander.
    private func offerButtons(k: SheetTheme) -> some View {
        VStack(spacing: 8) {
            CTAButton(title: "Kassenzettel scannen", k: k, icon: Icon.camera, action: onScan)
            HStack(spacing: 8) {
                EKKTextButton(title: "Abgehakte löschen", color: k.accentText, action: onFinish)
                    .frame(maxWidth: .infinity)
                EKKTextButton(title: "Liste behalten", color: k.sub, action: onKeep)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }

    /// Design-Text „alle 6 Artikel abgehakt“ nur, wenn wirklich alle abgehakt sind; sonst „2 von 6 Artikeln abgehakt“.
    static func checkedText(checked: Int, total: Int) -> String {
        if checked == total && total > 0 { return total == 1 ? "1 Artikel abgehakt" : "alle \(total) Artikel abgehakt" }
        return "\(checked) von \(total) Artikeln abgehakt"
    }

    /// Kachel: Padding 16 + Rahmen 1 (content-box), Radius 22, Abstand 4; gleiche Höhe (Grid-Zeile).
    private func statTile(_ label: String, _ value: String, k: SheetTheme, t: EKKTokens) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFont.dm(13, 400))
                .foregroundStyle(k.sub)
            Text(value)
                .font(AppFont.outfit(26, 600))
                .foregroundStyle(k.text)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(17)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Einkauf erledigt", traits: .fixedLayout(width: 390, height: 844)) { ShoppingDoneView(appearance: .light) }
#Preview("Einkauf erledigt – Dark", traits: .fixedLayout(width: 390, height: 844)) { ShoppingDoneView(appearance: .dark) }
#Preview("Einkauf erledigt – ohne Kassenzettel", traits: .fixedLayout(width: 390, height: 844)) {
    ShoppingDoneView(appearance: .light, hasReceipt: false)
}
#Preview("Einkauf erledigt – ohne Kassenzettel – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ShoppingDoneView(appearance: .dark, hasReceipt: false)
}
