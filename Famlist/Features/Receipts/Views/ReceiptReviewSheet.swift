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
 - „Preise speichern“: Weichen Bon-Preise von gespeicherten Artikelpreisen ab, fragt ein System-Dialog
   (nicht gestaltet), ob sie als neue Artikelpreise übernommen werden. Der Preisverlauf wird immer gespeichert.

 📝 Last Change:
 - Rückfrage „Artikelpreise aktualisieren?“ vor dem Speichern.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptReviewSheet: View {
    @ObservedObject var flow: ReceiptFlowViewModel
    let appearance: Appearance
    var onClose: () -> Void = {}
    /// „Zurück“: zurück zu „Kassenzettel fotografieren“ (Aufnahmen bleiben). nil = kein Knopf.
    var onBack: (() -> Void)? = nil
    /// Nach „Preise speichern“ (→ „Einkauf erledigt“).
    var onSaved: () -> Void = {}
    /// „Preise übernehmen“: Bon-Preise als neue Artikelpreise speichern.
    var onUpdateItemPrices: ([ReceiptPriceChange]) -> Void = { _ in }
    /// „Nicht gekauft“ / „Rückgängig“: Artikel auf der Liste wieder öffnen bzw. erneut abhaken.
    var onSetItemBought: (ItemModel, Bool) -> Void = { _, _ in }

    @State private var correcting: ReceiptReviewLine?
    @State private var editingStore = false
    @State private var storeDraft = ""
    @State private var isSaving = false
    @State private var pendingPriceChanges: [ReceiptPriceChange] = []
    @State private var askingPriceUpdate = false

    var body: some View {
        let k = SheetTheme(appearance)
        let t = EKKTokens(appearance)

        EKKSheetStage(k: k, background: {
            DesignListScreen(appearance: appearance, state: .normal)
        }) {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Kassenzettel prüfen", k: k, onClose: onClose, onBack: onBack)

                    if flow.phase == .recognizing {
                        VStack(spacing: 14) {
                            ProgressView().controlSize(.large).tint(k.accent)
                            Text("Kassenzettel wird gelesen …")
                                .font(AppFont.dm(15, 500))
                                .foregroundStyle(k.sub)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Design: Kopfkarte, Zuordnung und „Nicht auf dem Bon gefunden“ scrollen gemeinsam.
                        ScrollView {
                          VStack(spacing: 0) {
                            summaryCard(t: t)
                                .padding(.top, 16)

                            EKKSectionLabel(text: "Zuordnung", k: k)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 18)

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

                            if !flow.missingItems.isEmpty { missingSection(k: k) }

                            Color.clear.frame(height: 16)
                          }
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
        .alert("Artikelpreise aktualisieren?", isPresented: $askingPriceUpdate) {
            Button("Preise übernehmen") { persist(updating: pendingPriceChanges) }
            Button("Nur Preisverlauf", role: .cancel) { persist(updating: []) }
        } message: {
            Text(ReceiptFlowViewModel.priceChangeMessage(pendingPriceChanges))
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
                    let missing = flow.missingItems.count
                    if missing > 0 {
                        Text(missing == 1 ? "1 Artikel nicht gefunden" : "\(missing) Artikel nicht gefunden")
                            .font(AppFont.dm(13, 400))
                            .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                            .contentTransition(.numericText())
                    }
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

    /// „Nicht auf dem Bon gefunden · n“: Label (margin-top 22), Hinweis 12 (margin-top 4), Karten ab 10, Abstand 12.
    @ViewBuilder
    private func missingSection(k: SheetTheme) -> some View {
        let items = flow.missingItems
        EKKSectionLabel(text: "Nicht auf dem Bon gefunden · \(items.count)", k: k)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 22)
        Text("Abgehakt, aber auf dem Kassenzettel nicht erkannt. Ohne Auswahl wird kein Preis gespeichert.")
            .font(AppFont.dm(12, 400))
            .foregroundStyle(k.sub)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)
        VStack(spacing: 12) {
            ForEach(items) { item in
                ReceiptMissingItemCard(
                    item: item,
                    resolution: flow.missingResolutions[item.id],
                    suggestions: flow.lineSuggestions(for: item),
                    appearance: appearance,
                    onAssign: { lineId in withAnimation(.easeOut(duration: 0.25)) { flow.assignLine(lineId, to: item) } },
                    onPrice: { flow.setManualPrice($0, for: item) },
                    onNotBought: {
                        flow.markNotBought(item)
                        onSetItemBought(item, false)
                    },
                    onUndo: {
                        if flow.missingResolutions[item.id] == .notBought { onSetItemBought(item, true) }
                        flow.clearResolution(for: item)
                    })
            }
        }
        .padding(.top, 10)
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

    /// Weichen Preise ab → erst fragen, sonst direkt speichern.
    private func save() {
        let changes = flow.priceChanges
        if changes.isEmpty {
            persist(updating: [])
        } else {
            pendingPriceChanges = changes
            askingPriceUpdate = true
        }
    }

    private func persist(updating changes: [ReceiptPriceChange]) {
        isSaving = true
        Task {
            await flow.savePrices()
            if !changes.isEmpty { onUpdateItemPrices(changes) }
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

#Preview("Kassenzettel prüfen – nicht gefunden", traits: .fixedLayout(width: 390, height: 844)) {
    let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Schokolade", "Bananen"],
                                    checkedItems: [ItemModel(name: "Kerrygold, original irische Butter"),
                                                   ItemModel(name: "Schokolade", units: 1),
                                                   ItemModel(name: "Bananen", units: 6)],
                                    catalog: nil, priceBook: PriceBook(repository: nil))
    flow.apply(ReceiptParser.parse(lines: ["EDEKA", "KERRYGOLD BUTTER 2,49 A", "FAIRGL.VM SCHOKO 3,49 A"]))
    return ReceiptReviewSheet(flow: flow, appearance: .dark)
}

#Preview("Kassenzettel prüfen – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    let flow = ReceiptFlowViewModel(listItemNames: ["Kerrygold, original irische Butter", "Soyamilch", "Kokosmilch"],
                                    catalog: nil, priceBook: PriceBook(repository: nil))
    flow.apply(ReceiptParser.parse(lines: ["EDEKA", "KERRYGOLD BUTTER 2,49 A", "ALPRO SOJA DRINK 2,29 A",
                                           "KOKOSM. 400ML 1,39 A", "FAIRGL.VM SCHOKO 3,49 A"]))
    return ReceiptReviewSheet(flow: flow, appearance: .dark)
}
