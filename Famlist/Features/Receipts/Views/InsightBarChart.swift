/*
 InsightBarChart.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Säulen „Letzte 6 Monate“ (Board InsightSpend): Betrag über jeder Säule, Monatskürzel darunter,
   gewählter Monat in Akzentfarbe, gestrichelte Linie beim Schnitt.

 🔰 Notes for Beginners:
 - Gezeichnet im Koordinatensystem des Board-SVG (viewBox 350 × 142) und auf die Kartenbreite skaliert,
   wie `<svg width="100%">` – Schrift und Striche wachsen mit.
 - Säule: Breite 38, Abstand (350 − 38) ÷ 5, Grundlinie y 120, Höhe = Betrag ÷ größter Betrag × 95,2, Radius 10.
   Betrag 11/600 bei Säulenoberkante − 5; Monat 12 bei y 137. Schnittlinie: sub 45 %, Striche 4/4.
 - VoiceOver: eine Liste „April: 356 Euro“ … statt der Zeichnung.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InsightBarChart: View {
    let bars: [SpendInsights.MonthBar]
    let average: Decimal?
    let t: ListAccountTokens

    private static let viewBox = CGSize(width: 350, height: 142)
    private static let barWidth: CGFloat = 38
    private static let baseline: CGFloat = 120
    private static let maxHeight: CGFloat = 95.2

    var body: some View {
        Canvas { context, size in
            let scale = size.width / Self.viewBox.width
            context.scaleBy(x: scale, y: scale)
            draw(in: &context)
        }
        .aspectRatio(Self.viewBox, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityRepresentation {
            VStack { ForEach(bars) { Text(SpendInsightsText.barAccessibility($0)) } }
                .accessibilityLabel("Letzte 6 Monate")
        }
    }

    private var maxTotal: CGFloat {
        max(bars.map { CGFloat(NSDecimalNumber(decimal: $0.total).doubleValue) }.max() ?? 0, 1)
    }

    private func height(_ value: Decimal) -> CGFloat {
        CGFloat(NSDecimalNumber(decimal: value).doubleValue) / maxTotal * Self.maxHeight
    }

    private func draw(in context: inout GraphicsContext) {
        let k = t.k
        if let average {
            let y = Self.baseline - height(average)
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: Self.viewBox.width, y: y))
            context.stroke(line, with: .color(k.sub.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        let step = (Self.viewBox.width - Self.barWidth) / CGFloat(max(bars.count - 1, 1))
        for (index, bar) in bars.enumerated() {
            let x = CGFloat(index) * step
            let h = height(bar.total)
            let rect = CGRect(x: x, y: Self.baseline - h, width: Self.barWidth, height: h)
            context.fill(RR(10).path(in: rect), with: .color(bar.isSelected ? k.accent : t.segBg))
            let center = x + Self.barWidth / 2
            drawText(Text(SpendInsightsText.barValue(bar)).font(AppFont.dm(11, 600))
                        .foregroundStyle(bar.isSelected ? t.accentText : k.sub),
                     centerX: center, baseline: rect.minY - 5, in: &context)
            drawText(Text(InsightFormat.monthShort(bar.month)).font(AppFont.dm(12, bar.isSelected ? 600 : 400))
                        .foregroundStyle(bar.isSelected ? k.text : k.sub),
                     centerX: center, baseline: 137, in: &context)
        }
    }

    /// Wie SVG `<text text-anchor="middle" y="…">`: waagerecht mittig, `baseline` = Grundlinie der Schrift.
    private func drawText(_ text: Text, centerX: CGFloat, baseline: CGFloat, in context: inout GraphicsContext) {
        let resolved = context.resolve(text)
        let size = resolved.measure(in: CGSize(width: 200, height: 50))
        let ascent = resolved.firstBaseline(in: size)
        context.draw(resolved, in: CGRect(x: centerX - size.width / 2, y: baseline - ascent,
                                          width: size.width, height: size.height))
    }
}

#Preview("Säulen", traits: .fixedLayout(width: 390, height: 200)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    InsightBarChart(bars: spend.bars, average: spend.barAverage, t: ListAccountTokens(.light)).padding(34)
}

#Preview("Säulen – Dark", traits: .fixedLayout(width: 390, height: 200)) {
    let spend = ReceiptInsights.spend(ArchivedReceipt.insightSamples, month: ArchivedReceipt.insightSamples[0].purchasedAt,
                                      context: .designSample)
    InsightBarChart(bars: spend.bars, average: spend.barAverage, t: ListAccountTokens(.dark))
        .padding(34)
        .background(Color.black)
}
