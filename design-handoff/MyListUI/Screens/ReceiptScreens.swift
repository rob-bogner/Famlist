//  ReceiptScreens.swift
//  MyListUI
//
//  „Kassenzettel“ (Kamera, immer dunkel), „Kassenzettel prüfen“ (Sheet 790) und „Einkauf erledigt“.
//  Gemeinsame EKK-Bausteine: siehe OnboardingScreens.swift.

import SwiftUI

// MARK: - Kassenzettel (Kamera)
//
// Quelle: Design/html/ReceiptCapture.dc.html (nur Light-Artboard; die Kamera ist in beiden Modi dunkel)
//  Hintergrund radial-gradient(90% 60% at 50% 40%, #2B3A3C 0, #121A1B 70 %, #0A0F10 100 %)
//  Leiste top 62, links/rechts 20: Kreis 48 · „Kassenzettel“-Pille · Kreis 48
//  Sucher left 70, top 140, 250 × 470: Ecken 34 (Rahmen 4, Radius 18) + gestrichelte Fläche (Einzug 22, Radius 6)
//  Hinweis top 630 (links/rechts 30), Auslöser-Reihe unten 48 (Padding 0/40, space-around)

struct ReceiptCaptureScreen: View {
    /// Ohne Wirkung: die Kamera-Ansicht ist immer dunkel (für API-Gleichheit mit den übrigen Screens).
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var pageCount = 0
    var onClose: () -> Void = {}
    var onToggleLight: () -> Void = {}
    var onPickPhoto: () -> Void = {}
    var onCapture: () -> Void = {}
    var onPages: () -> Void = {}

    var body: some View {
        let hintFont = AppFont.ui(.dmSans, 14, 400)

        return ZStack(alignment: .top) {
            // Kamerabild-Platzhalter (in der App: Kamera-Vorschau)
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 0.4), extent: .ellipse(rx: 0.9, ry: 0.6),
                              stops: [stop(.hex("#2B3A3C"), 0), stop(.hex("#121A1B"), 0.7), stop(.hex("#0A0F10"), 1)])

            // Obere Leiste
            HStack(spacing: 0) {
                glassButton(label: "Schließen", action: onClose) {
                    SVGIcon(Icon.close, size: 20, color: .white, lineWidth: 2.2)
                }
                Spacer(minLength: 0)
                Text("Kassenzettel")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(RR(18).fill(Color.rgba(0, 0, 0, 0.35)))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                glassButton(label: "Licht", action: onToggleLight) {
                    SVGIcon(EKKIcon.flash, size: 20, color: .white, lineWidth: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 62)

            // „Kamerabild“ (liegt im Design unter der Sucher-Fläche)
            Text("Kamerabild")
                .font(AppFont.dm(12, 400))
                .tracking(0.96)                                          // 0.08em × 12
                .textCase(.uppercase)
                .foregroundStyle(Color.rgba(255, 255, 255, 0.25))
                .frame(maxWidth: .infinity)
                .padding(.top, 330)
                .accessibilityHidden(true)

            // Sucher 250 × 470, horizontal mittig (left 70 bei 390)
            ZStack {
                RR(6)
                    .fill(Color.rgba(255, 255, 255, 0.06))
                    .overlay(RR(6).strokeBorder(Color.rgba(255, 255, 255, 0.3),
                                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    .padding(22)
                ViewfinderCorner().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                ViewfinderCorner().rotationEffect(.degrees(90))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                ViewfinderCorner().rotationEffect(.degrees(180))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                ViewfinderCorner().rotationEffect(.degrees(270))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            .frame(width: 250, height: 470)
            .padding(.top, 140)
            .accessibilityHidden(true)

            Text("Ganzen Bon ins Bild · bei langen Bons in mehreren Teilen")
                .font(AppFont.dm(14, 400))
                .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                .multilineTextAlignment(.center)
                .cssLineHeight(20.3, font: hintFont)                     // line-height 1.45
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .padding(.top, 630)

            // Auslöser-Reihe: justify-content: space-around → 6 gleiche Halbabstände
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                glassButton(label: "Aus Fotos wählen", action: onPickPhoto) {
                    SVGIcon(EKKIcon.gallery, size: 22, color: .white, lineWidth: 1.9)
                }
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                Button(action: onCapture) {
                    // 80 border-box, Rahmen 4 weiß .9, Padding 5 → Innenkreis 62
                    Circle()
                        .fill(Color.white)
                        .padding(9)
                        .frame(width: 80, height: 80)
                        .overlay(Circle().strokeBorder(Color.rgba(255, 255, 255, 0.9), lineWidth: 4))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Foto aufnehmen")
                Spacer(minLength: 0)
                Spacer(minLength: 0)
                glassButton(label: "Seiten", action: onPages) {
                    Text("\(pageCount)")
                        .font(AppFont.dm(14, 700))
                        .foregroundStyle(Color.white)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 80)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    /// Glas-Kreis 48 (border-box): weiß .14, Rahmen 1 weiß .28.
    /// `backdrop-filter: blur(20px)` entfällt – über dem Verlauf ohne sichtbare Wirkung
    /// (über einer echten Kamera-Vorschau ggf. `.background(.ultraThinMaterial, in: Circle())` ergänzen).
    private func glassButton<Label: View>(label: String, action: @escaping () -> Void,
                                          @ViewBuilder content: () -> Label) -> some View {
        Button(action: action) {
            content()
                .frame(width: 48, height: 48)
                .background(CSSBox(shape: Circle(), paint: .color(.rgba(255, 255, 255, 0.14)), border: 1,
                                   borderColor: .rgba(255, 255, 255, 0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Sucher-Ecke oben links: 34 × 34, Rahmen 4 oben + links, äußerer Radius 18 (innen 14).
/// Umsetzung: Rahmen einer 38 × 38-Box (rechte/untere Kante liegen außerhalb) auf 34 × 34 beschnitten.
private struct ViewfinderCorner: View {
    var body: some View {
        UnevenRoundedRectangle(topLeadingRadius: 18, style: .circular)
            .strokeBorder(Color.white, lineWidth: 4)
            .frame(width: 38, height: 38)
            .frame(width: 34, height: 34, alignment: .topLeading)
            .clipped()
    }
}

// MARK: - Kassenzettel prüfen
//
// Quelle: Design/html/ReceiptReview.dc.html (Dark: ReceiptReviewDark.dc.html)
//  Sheet 790, Innenabstand 10/20/34. Titelzeile → 16 → Summen-Karte (Padding 14/16, Radius 20, Hero-Verlauf) →
//  18 → „Zuordnung“ → 10 → Positionen (Abstand 8; Padding 12/14, Radius 20, innen Abstand 6) → auto (min. 16) → CTA

struct EKKReceiptLine: Identifiable {
    enum Match { case matched, check, new }

    let raw: String
    let price: String
    let item: String
    let match: Match
    var id: String { raw }
}

extension EKKReceiptLine {
    static let samples: [EKKReceiptLine] = [
        EKKReceiptLine(raw: "KERRYGOLD BUTTER", price: "2,49 €", item: "Kerrygold, original irische Butter", match: .matched),
        EKKReceiptLine(raw: "ALPRO SOJA DRINK", price: "2,29 €", item: "Soyamilch · alpro", match: .matched),
        EKKReceiptLine(raw: "KOKOSM. 400ML", price: "1,39 €", item: "Kokosmilch · Freshona?", match: .check),
        EKKReceiptLine(raw: "MANDELDR.O.Z.", price: "1,85 €", item: "Milch Mandel ohne Zucker", match: .matched),
        EKKReceiptLine(raw: "FAIRGL.VM SCHOKO", price: "3,49 €", item: "Bio Vollmilch-Schokolade", match: .new)
    ]
}

struct ReceiptReviewScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var storeAndDate = "[Laden] · [Datum]"
    var total = "11,51 €"
    var lines: [EKKReceiptLine] = EKKReceiptLine.samples
    var onClose: () -> Void = {}
    var onSelect: (EKKReceiptLine) -> Void = { _ in }
    var onSave: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = EKKTokens(appearance, accentHex: accentHex)

        return EKKSheetStage(k: k, background: {
            ListScreen(appearance: appearance, accentHex: accentHex, state: .normal)
        }) {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Kassenzettel prüfen", k: k, onClose: onClose)

                    // Summen-Karte
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(storeAndDate)
                                .font(AppFont.dm(13, 400))
                                .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                            Text("\(lines.count) Positionen erkannt")
                                .font(AppFont.dm(15, 600))
                                .foregroundStyle(Color.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(total)
                            .font(AppFont.outfit(26, 600))
                            .foregroundStyle(Color.white)
                            .fixedSize()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(CSSBox(shape: RR(20), paint: t.heroBg))
                    .padding(.top, 16)

                    EKKSectionLabel(text: "Zuordnung", k: k)
                        .padding(.top, 18)

                    VStack(spacing: 8) {
                        ForEach(lines) { line in
                            lineCard(line, k: k, t: t)
                        }
                    }
                    .padding(.top, 10)

                    Spacer(minLength: 16)

                    CTAButton(title: "Preise speichern", k: k, action: onSave)
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// Positions-Karte: Rahmen 1 (content-box) → Einzug 13 / 15; Warnung mit warnBorder.
    private func lineCard(_ line: EKKReceiptLine, k: SheetTheme, t: EKKTokens) -> some View {
        let color: Color
        let icon: [SVGElement]
        let status: String
        switch line.match {
        case .matched:
            color = t.ok
            icon = Icon.check
            status = "Zugeordnet"
        case .check:
            color = t.warn
            icon = EKKIcon.alert
            status = "Zuordnung prüfen"
        case .new:
            color = k.accentText
            icon = Icon.plus
            status = "Neuer Artikel?"
        }

        return Button(action: { onSelect(line) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // font-family: ui-monospace → SF Mono
                    Text(line.raw)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(k.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(line.price)
                        .font(AppFont.outfit(16, 600))
                        .foregroundStyle(k.text)
                        .fixedSize()
                }
                HStack(spacing: 8) {
                    SVGIcon(icon, size: 16, color: color, lineWidth: 2.4)
                    Text(line.item)
                        .font(AppFont.dm(15, 500))
                        .foregroundStyle(k.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(status)
                        .font(AppFont.dm(12, 600))
                        .foregroundStyle(color)
                        .fixedSize()
                }
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 15)
            .background(CSSBox(shape: RR(20), paint: t.card, border: 1,
                               borderColor: line.match == .check ? t.warnBorder : t.cardBorder,
                               shadows: t.cardShadow))
            .contentShape(RR(20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Einkauf erledigt
//
// Quelle: Design/html/ShoppingDone.dc.html (Dark: ShoppingDoneDark.dc.html)
//  Hero 420 (Padding oben 30, Inhalt mittig, Abstand 14): Kreis 94 (92 + 2 Rahmen) · Titel Outfit 32/700 · Untertitel 15
//  Inhalt links/rechts 20, top 444, Abstand 10: 2 Kacheln (Padding 16, Radius 22) · Hinweis (Padding 14/16, Radius 20)
//  Unten 34: CTA · 8 · „Liste behalten“ 48

struct ShoppingDoneScreen: View {
    var appearance: Appearance = .light
    var accentHex: String? = nil
    var listName = "My List"
    var itemCount = 6
    var total = "11,51 €"
    var savedPrices = 5
    var onFinish: () -> Void = {}
    var onKeep: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance, accentHex: accentHex)
        let t = EKKTokens(appearance, accentHex: accentHex)
        let infoFont = AppFont.ui(.dmSans, 14, 400)

        return ZStack(alignment: .top) {
            EKKScreenBackground(t: t)

            EKKHero(t: t, height: 420) {
                VStack(spacing: 14) {
                    SVGIcon(Icon.check, size: 44, color: .white, lineWidth: 2.4)
                        .frame(width: 94, height: 94)
                        .background(EKKGlassBadge(shape: Circle(), size: 94))
                        .accessibilityHidden(true)
                    Text("Einkauf erledigt")
                        .font(AppFont.outfit(32, 700))
                        .foregroundStyle(Color.white)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(listName) · alle \(itemCount) Artikel abgehakt")
                        .font(AppFont.dm(15, 400))
                        .foregroundStyle(Color.rgba(255, 255, 255, 0.9))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 30)
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    statTile("Gesamt", total, k: k, t: t)
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
            .padding(.top, 444)

            VStack(spacing: 8) {
                CTAButton(title: "Abgehakte löschen & fertig", k: k, action: onFinish)
                EKKTextButton(title: "Liste behalten", color: k.accentText, action: onKeep)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
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
        }
        .padding(17)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
        .accessibilityElement(children: .combine)
    }
}
