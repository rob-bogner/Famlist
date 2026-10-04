/*
 PhotoRecognitionViews.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bausteine für „Per Foto hinzufügen“: Schritte der Erkennung (PhotoAddScan), Hinweis „Aus dem Foto erkannt“
   mit „Rückgängig“ und die Quellenzeile unter der Beschreibung (PhotoAddResult / PhotoAddDescription).

 🔰 Notes for Beginners:
 - Schritte: Karte field, Rand 1, Radius 20, Zeilen ≥ 52 mit Linie dazwischen; Symbol 28:
   fertig = Akzent-Glas mit Haken, läuft = Ring, übersprungen = Strich, offen = gestrichelt (50 %).
 - Hinweis: wie PhotoSuggestionBanner, rechts Textknopf „Rückgängig“ (13/600 Akzenttext).

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct PhotoRecognitionStep: Identifiable, Equatable {
    enum Status: Equatable { case todo, busy, done, skipped }
    let id: Int
    var title: String
    var detail: String
    var status: Status
}

struct PhotoRecognitionStepsView: View {
    let k: SheetTheme
    let steps: [PhotoRecognitionStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Neuer Artikel aus dem Foto")
                .font(AppFont.outfit(20, 600))
                .foregroundStyle(k.text)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    if index > 0 { Rectangle().fill(k.isDark ? Color.rgba(255, 255, 255, 0.08) : .hex("#EDF1F2")).frame(height: 1) }
                    row(step)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 7)
            .background(CSSBox(shape: RR(20), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            .padding(.top, 12)
            Text("Alles läuft auf deinem iPhone – nur die Katalog-Suche fragt Open Food Facts.")
                .font(AppFont.dm(12, 400))
                .lineSpacing(3)
                .foregroundStyle(k.sub)
                .padding(.top, 14)
                .padding(.horizontal, 4)
        }
    }

    private func row(_ step: PhotoRecognitionStep) -> some View {
        HStack(spacing: 12) {
            icon(step.status)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.text)
                Text(step.detail)
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
        .opacity(step.status == .todo ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusText(step.status))
        .animation(.easeInOut(duration: 0.2), value: step.status)
    }

    @ViewBuilder
    private func icon(_ status: PhotoRecognitionStep.Status) -> some View {
        switch status {
        case .done:
            SVGIcon(Icon.check, size: 14, color: .white, lineWidth: 3)
                .frame(width: 28, height: 28)
                .background(GlassCircleBackground(style: .accent, appearance: k.appearance, accent: k.a, size: 28))
        case .busy:
            StepSpinner(color: k.accent, track: k.ringSoft)
        case .skipped:
            SVGIcon([.path("M6 12h12")], size: 13, color: k.sub, lineWidth: 2.6)
                .frame(width: 28, height: 28)
                .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
        case .todo:
            Circle()
                .strokeBorder(k.fieldBorder, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                .frame(width: 28, height: 28)
        }
    }

    private func statusText(_ status: PhotoRecognitionStep.Status) -> String {
        switch status {
        case .done: return "erledigt"
        case .busy: return "läuft"
        case .skipped: return "übersprungen"
        case .todo: return "offen"
        }
    }
}

private struct StepSpinner: View {
    let color: Color
    let track: Color
    @State private var spinning = false

    var body: some View {
        Circle()
            .stroke(track, lineWidth: 3)
            .overlay(Circle().trim(from: 0, to: 0.25).stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round)))
            .frame(width: 25, height: 25)
            .frame(width: 28, height: 28)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
    }
}

/// „Aus dem Foto erkannt · Gefunden in Open Food Facts“ mit „Rückgängig“.
struct PhotoRecognizedBanner: View {
    let k: SheetTheme
    let detail: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SVGIcon(ProductDetailIcon.sparkle, size: 18, color: k.accentText, lineWidth: 1.9)
                .frame(width: 34, height: 34)
                .background(RR(11).fill(k.a.base.color(k.isDark ? 0.16 : 0.08)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Aus dem Foto erkannt")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(k.text)
                Text(detail)
                    .font(AppFont.dm(12, 400))
                    .foregroundStyle(k.sub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button("Rückgängig", action: onUndo)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(k.accentText)
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityHint("Setzt die erkannten Angaben zurück")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(CSSBox(shape: RR(18), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
    }
}

/// „Quelle: Open Food Facts (ODbL)“ bzw. „Automatisch erstellt“ unter der Beschreibung.
struct DescriptionSourceLine: View {
    let k: SheetTheme
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            SVGIcon([.path("M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"), .path("M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1")],
                    size: 13, color: k.sub, lineWidth: 2)
            Text(text)
                .font(AppFont.dm(12, 400))
                .foregroundStyle(k.sub)
        }
        .accessibilityElement(children: .combine)
    }
}

/// „Welches Produkt ist es?“ (Design: PhotoAddChoose): Die Erkennung ist nicht sicher genug –
/// bis zu 3 Katalog-Treffer mit Foto, dazu „Keiner davon“. Erst nach der Wahl kommen Beschreibung & Co.
struct PhotoMatchPicker: View {
    let k: SheetTheme
    let candidates: [ProductMatchCandidate]
    let onPick: (ProductMatchCandidate) -> Void
    let onNone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SVGIcon(ProductDetailIcon.sparkle, size: 18, color: k.accentText, lineWidth: 1.9)
                    .frame(width: 34, height: 34)
                    .background(RR(11).fill(k.a.base.color(k.isDark ? 0.16 : 0.08)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welches Produkt ist es?")
                        .font(AppFont.dm(14, 600))
                        .foregroundStyle(k.text)
                    Text("Nicht ganz sicher – bitte kurz wählen")
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.sub)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                row(candidate, highlighted: index == 0)
            }
            Button(action: onNone) {
                Text("Keiner davon – nur Gelesenes behalten")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(k.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 48))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(12)
        .background(CSSBox(shape: RR(22), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
    }

    private func row(_ candidate: ProductMatchCandidate, highlighted: Bool) -> some View {
        let p = candidate.product
        let meta = [p.brand, p.measure].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return Button { onPick(candidate) } label: {
            HStack(spacing: 12) {
                thumbnail(p.imageUrl)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name)
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(k.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !meta.isEmpty {
                        Text(meta)
                            .font(AppFont.dm(12, 400))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SVGIcon(Icon.chevronRight, size: 16, color: k.sub, lineWidth: 2.2)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(CSSBox(shape: RR(16), paint: .color(k.isDark ? .hex("#102124") : .white),
                               border: highlighted ? 1.5 : 1, borderColor: highlighted ? k.ring : k.fieldBorder))
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel([p.name, meta].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityHint("Übernimmt dieses Produkt")
    }

    private func thumbnail(_ url: String?) -> some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                SVGIcon(Icon.basket, size: 20, color: k.sub, lineWidth: 1.8)
            }
        }
        .frame(width: 48, height: 48)
        .padding(3)
        .background(RR(12).fill(Color.white))
        .clipShape(RR(12))
        .accessibilityHidden(true)
    }
}
