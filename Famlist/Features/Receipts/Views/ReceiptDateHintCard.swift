/*
 ReceiptDateHintCard.swift
 Famlist
 Created on: 08.11.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hinweis-Karte „Kaufdatum nicht erkannt“ in „Kassenzettel prüfen“ (Board ReceiptReviewNoDate, T-008).

 🔰 Notes for Beginners:
 - Board: Abstand zur Kopfkarte 10, Einzug 12 / 14 plus Rahmen 1 (content-box) → 13 / 15, Radius 20,
   Rahmen warnBorder. Zeile: Kalender 16 (Strich 2,2, warn), Abstand 8, Titel DM 15/600.
   Text DM 12 sub, Einzug links 24. Pille „Datum ändern“ 34 hoch, Einzug 11, DM 13/600, Akzent-Text,
   neutrales Glas; Abstand nach oben 6 + 4.
 - Die Karte verschwindet, sobald ein Datum gewählt ist (ReceiptFlowViewModel.isPurchaseDateMissing).

 📝 Last Change:
 - Initial creation (T-008).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptDateHintCard: View {
    let appearance: Appearance
    var onChange: () -> Void = {}

    var body: some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SVGIcon(ReceiptMetaIcon.calendar, size: 16, color: t.warn, lineWidth: 2.2)
                    .accessibilityHidden(true)
                Text("Kaufdatum nicht erkannt")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Wir haben heute eingesetzt. Stimmt das nicht, ändere es vor dem Speichern.")
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 24)
            Button(action: onChange) {
                Text("Datum ändern")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(k.accentText)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(GlassPillBackground(style: .neutral, appearance: appearance, accent: k.a, height: 34))
                    .contentShape(Pill)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
            .padding(.top, 4)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CSSBox(shape: RR(20), paint: t.card, border: 1, borderColor: t.warnBorder, shadows: t.cardShadow))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kaufdatum nicht erkannt")
    }
}

#Preview("Kaufdatum nicht erkannt") {
    ReceiptDateHintCard(appearance: .light).padding(20)
}

#Preview("Kaufdatum nicht erkannt – Dark") {
    ReceiptDateHintCard(appearance: .dark)
        .padding(20)
        .background(Color.hex("#0A1416"))
}
