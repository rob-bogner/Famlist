/*
 ReceiptReviewSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Kassenzettel prüfen“ (Höhe 790): Summen-Karte (Laden · Datum, Anzahl, Summe),
   „Zuordnung“ mit allen Positionen und Status, „Preise speichern“.

 🔰 Notes for Beginners:
 - Vorlage: ReceiptReviewScreen in design-handoff/MyListUI/Screens/ReceiptScreens.swift (ReceiptReview.dc.html).
 - Tippen auf eine Position öffnet einen System-Dialog zum Korrigieren (nicht gestaltet): Vorschläge,
   „Als neuen Artikel speichern“, „Ignorieren“. Ignorierte Positionen sind gedimmt.
 - Tippen auf die Summen-Karte ändert den Laden (System-Eingabe), falls er nicht erkannt wurde.
 - Während der Texterkennung zeigt der Inhalt einen Ladekreis.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptReviewSheet: View {
    @ObservedObject var flow: ReceiptFlowViewModel
    let appearance: Appearance
    var onClose: () -> Void = {}
    /// Nach „Preise speichern“ (→ „Einkauf erledigt“).
    var onSaved: () -> Void = {}

    @State private var correcting: ReceiptReviewLine?
    @State private var editingStore = false
    @State private var storeDraft = ""
    @State private var isSaving = false

    var body: some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)

        EKKSheetStage(k: k, background: {
            DesignListScreen(appearance: appearance, state: .normal)
        }) {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Kassenzettel prüfen", k: k, onClose: onClose)

                    if flow.phase == .recognizing {
                        VStack(spacing: 14) {
                            ProgressView().controlSize(.large).tint(k.accent)
                            Text("Kassenzettel wird gelesen …")
                                .font(AppFont.dm(15, 500))
                                .foregroundStyle(k.sub)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        summaryCard(t: t)
                            .padding(.top, 16)

                        EKKSectionLabel(text: "Zuordnung", k: k)
                            .padding(.top, 18)

                        ScrollView {
                            VStack(spacing: 8) {
                                if let error = flow.errorMessage {
                                    Text(error)
                                        .font(AppFont.dm(15, 500))
                                        .foregroundStyle(k.sub)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                }
                                ForEach(flow.lines) { line in
                                    lineCard(line, k: k, t: t)
                                }
                            }
                            .padding(.top, 10)
                            .padding(.bottom, 16)
                        }
                        .scrollIndicators(.hidden)

                        CTAButton(title: isSaving ? "Wird gespeichert …" : "Preise speichern", k: k,
                                  isEnabled: flow.savableCount > 0 && !isSaving, action: save)
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .confirmationDialog(correcting.map { "„\($0.raw)“ zuordnen" } ?? "", isPresented: correctingBinding,
                            titleVisibility: .visible, presenting: correcting) { line in
            ForEach(flow.suggestions(for: line), id: \.self) { name in
                Button(name) { flow.assign(line.id, to: name) }
            }
            Button("Als neuen Artikel speichern") { flow.confirmNew(line.id) }
            Button("Ignorieren", role: .destructive) { flow.ignore(line.id) }
            Button("Abbrechen", role: .cancel) {}
        }
        .alert("Laden", isPresented: $editingStore) {
            TextField("z. B. Edeka", text: $storeDraft)
            Button("Übernehmen") { flow.storeName = storeDraft.trimmingCharacters(in: .whitespaces) }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    // MARK: - Teile

    private var storeAndDate: String {
        let store = flow.storeName ?? "Laden unbekannt"
        let date = (flow.purchaseDate ?? Date()).formatted(.dateTime.day().month(.twoDigits).year())
        return "\(store) · \(date)"
    }

    /// Summen-Karte: Padding 14 / 16, Radius 20, Hero-Verlauf.
    private func summaryCard(t: EKKTokens) -> some View {
        Button(action: { storeDraft = flow.storeName ?? ""; editingStore = true }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(storeAndDate)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                    Text(flow.lines.count == 1 ? "1 Position erkannt" : "\(flow.lines.count) Positionen erkannt")
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(flow.total.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE"))))
                    .font(AppFont.outfit(26, 600))
                    .foregroundStyle(Color.white)
                    .fixedSize()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(CSSBox(shape: RR(20), paint: t.heroBg))
            .contentShape(RR(20))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Laden ändern")
    }

    /// Positions-Karte: Rahmen 1 (content-box) → Einzug 13 / 15; Warnung mit warnBorder.
    private func lineCard(_ line: ReceiptReviewLine, k: SheetTheme, t: EKKTokens) -> some View {
        let (color, icon, status) = statusStyle(line, k: k, t: t)
        return Button(action: { correcting = line }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // font-family: ui-monospace → SF Mono
                    Text(line.raw)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(k.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(line.price.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE"))))
                        .font(AppFont.outfit(16, 600))
                        .foregroundStyle(k.text)
                        .fixedSize()
                }
                HStack(spacing: 8) {
                    SVGIcon(icon, size: 16, color: color, lineWidth: 2.4)
                    Text(line.itemName ?? line.raw)
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
                               borderColor: line.status == .check && !line.ignored ? t.warnBorder : t.cardBorder,
                               shadows: t.cardShadow))
            .contentShape(RR(20))
            .opacity(line.ignored ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Zuordnung ändern")
    }

    private func statusStyle(_ line: ReceiptReviewLine, k: SheetTheme, t: EKKTokens) -> (Color, [SVGElement], String) {
        if line.ignored { return (k.sub, Icon.close, "Ignoriert") }
        switch line.status {
        case .matched: return (t.ok, Icon.check, "Zugeordnet")
        case .check: return (t.warn, EKKIcon.alert, "Zuordnung prüfen")
        case .new: return line.confirmedNew ? (t.ok, Icon.plus, "Neuer Artikel") : (k.accentText, Icon.plus, "Neuer Artikel?")
        }
    }

    private var correctingBinding: Binding<Bool> {
        Binding(get: { correcting != nil }, set: { if !$0 { correcting = nil } })
    }

    private func save() {
        isSaving = true
        Task {
            await flow.savePrices()
            isSaving = false
            onSaved()
        }
    }
}

#Preview("Kassenzettel prüfen", traits: .fixedLayout(width: 390, height: 844)) {
    let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Soyamilch", "Kokosmilch"],
                                    catalog: nil, priceBook: PriceBook(repository: nil))
    flow.apply(ReceiptParser.parse(lines: ["EDEKA", "KERRYGOLD BUTTER 2,49 A", "ALPRO SOJA DRINK 2,29 A",
                                           "KOKOSM. 400ML 1,39 A", "FAIRGL.VM SCHOKO 3,49 A"]))
    return ReceiptReviewSheet(flow: flow, appearance: .light)
}

#Preview("Kassenzettel prüfen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Soyamilch", "Kokosmilch"],
                                    catalog: nil, priceBook: PriceBook(repository: nil))
    flow.apply(ReceiptParser.parse(lines: ["EDEKA", "KERRYGOLD BUTTER 2,49 A", "ALPRO SOJA DRINK 2,29 A",
                                           "KOKOSM. 400ML 1,39 A", "FAIRGL.VM SCHOKO 3,49 A"]))
    return ReceiptReviewSheet(flow: flow, appearance: .dark)
}
