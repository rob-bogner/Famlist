/*
 ReceiptInsightsSheet.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Auswertung“ (Höhe 790, Boards InsightSpend/InsightUsage): Segment „Ausgaben“ · „Verbrauch“,
   Monatswechsel, darunter der Inhalt des Reiters.

 🔰 Notes for Beginners:
 - Kopf ohne Zurück-Knopf; ✕ führt zurück ins Archiv (`onClose`). Im Board liegt darunter die Einkaufsliste.
 - Abstände: Segment 14 unter dem Titel, Monatswechsel 12 darunter, dann scrollt der Inhalt bis zum Rand.
 - `onOpenHistory` meldet Artikelname, Reiter und Monat, damit „Zurück“ im Preisverlauf genau hierher führt.

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptInsightsSheet: View {
    @StateObject private var viewModel: ReceiptInsightsViewModel
    let appearance: Appearance
    var onClose: () -> Void = {}
    var onOpenHistory: ((String, InsightTab, Date) -> Void)? = nil
    var keyboardHeight: CGFloat = 0

    init(viewModel: @autoclosure @escaping () -> ReceiptInsightsViewModel, appearance: Appearance,
         keyboardHeight: CGFloat = 0, onClose: @escaping () -> Void = {},
         onOpenHistory: ((String, InsightTab, Date) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.appearance = appearance
        self.keyboardHeight = keyboardHeight
        self.onClose = onClose
        self.onOpenHistory = onOpenHistory
    }

    var body: some View {
        let t = ListAccountTokens(appearance)
        let k = t.k
        ListAccountBackdrop(scrim: t.scrimSheet) {
            DesignListScreen(appearance: appearance)
        } content: {
            SheetSurface(k: k, height: 790) {
                VStack(alignment: .leading, spacing: 0) {
                    SheetHeader(title: "Auswertung", k: k, onClose: onClose)
                    SheetSegmentControl(titles: InsightTab.allCases.map(\.title), selection: tabIndex, t: t,
                                        accessibilityLabel: "Auswertung")
                        .padding(.top, 14)
                    MonthSwitcher(title: viewModel.monthTitle, canGoBack: viewModel.canGoBack,
                                  canGoForward: viewModel.canGoForward, k: k,
                                  onBack: viewModel.showPreviousMonth, onForward: viewModel.showNextMonth)
                        .padding(.top, 12)
                    SheetFadeScrollArea(t: t, extraBottom: keyboardHeight) { content(t: t) }
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .onAppear { viewModel.noteOpened() }
    }

    private var tabIndex: Binding<Int> {
        Binding(get: { viewModel.tab.rawValue },
                set: { viewModel.tab = InsightTab(rawValue: $0) ?? .spend })
    }

    @ViewBuilder
    private func content(t: ListAccountTokens) -> some View {
        switch viewModel.tab {
        case .spend:
            SpendInsightsView(spend: viewModel.spend, context: viewModel.context, t: t)
        case .usage:
            let usage = viewModel.usage
            UsageInsightsView(usage: usage, products: viewModel.filteredProducts(usage), search: $viewModel.search,
                              context: viewModel.context, t: t,
                              onOpen: onOpenHistory.map { open in
                                  { name in open(name, viewModel.tab, viewModel.month) }
                              })
        }
    }
}

#Preview("Auswertung – Ausgaben", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptInsightsSheet(viewModel: ReceiptInsightsViewModel(receipts: ArchivedReceipt.insightSamples,
                                                             context: .designSample,
                                                             now: ArchivedReceipt.insightSamples[0].purchasedAt),
                         appearance: .light)
}

#Preview("Auswertung – Ausgaben – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptInsightsSheet(viewModel: ReceiptInsightsViewModel(receipts: ArchivedReceipt.insightSamples,
                                                             context: .designSample,
                                                             now: ArchivedReceipt.insightSamples[0].purchasedAt),
                         appearance: .dark)
}

#Preview("Auswertung – Verbrauch", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptInsightsSheet(viewModel: ReceiptInsightsViewModel(receipts: ArchivedReceipt.insightSamples,
                                                             context: .designSample, tab: .usage,
                                                             now: ArchivedReceipt.insightSamples[0].purchasedAt),
                         appearance: .light)
}

#Preview("Auswertung – Verbrauch – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ReceiptInsightsSheet(viewModel: ReceiptInsightsViewModel(receipts: ArchivedReceipt.insightSamples,
                                                             context: .designSample, tab: .usage,
                                                             now: ArchivedReceipt.insightSamples[0].purchasedAt),
                         appearance: .dark)
}
