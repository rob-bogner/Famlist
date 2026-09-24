/*
 ShoppingListView+Receipts.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ablauf „Kassenzettel“ über der Liste: Aufnehmen (Vollbild) → Prüfen (Sheet) → Einkauf erledigt
   (Vollbild). Dazu der Preisverlauf eines Artikels aus „Artikel verwalten“.

 🔰 Notes for Beginners:
 - Einstieg: ☰ → „Kassenzettel scannen“. Das ReceiptFlowViewModel lebt in `receiptFlow`, bis der
   Ablauf geschlossen wird; Schließen an beliebiger Stelle verwirft ihn.
 - „Abgehakte löschen & fertig“ nutzt dasselbe Löschen mit Rückgängig wie das Dock.
 - Preisverlauf: Schließen führt zurück zu „Artikel verwalten“ (liegt weichgezeichnet darunter).

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension ShoppingListView {
    @ViewBuilder
    func receiptSheetView(_ sheet: ActiveListSheet, k: SheetTheme) -> some View {
        switch sheet {
        case .receiptCapture:
            if let flow = receiptFlow {
                ReceiptCaptureView(flow: flow, onClose: closeReceiptFlow, onContinue: { reviewReceipt(flow) })
            }
        case .receiptReview:
            if let flow = receiptFlow {
                ReceiptReviewSheet(flow: flow, appearance: appearance, onClose: closeReceiptFlow,
                                   onSaved: { activeSheet = .shoppingDone })
            }
        case .shoppingDone:
            ShoppingDoneView(appearance: appearance,
                             listName: listViewModel.defaultList?.title ?? String(localized: "shoppingList.title"),
                             itemCount: listViewModel.checkedItemCount,
                             totalCount: listViewModel.items.count,
                             total: receiptFlow?.total ?? 0,
                             savedPrices: savedPriceCount,
                             onFinish: finishShopping,
                             onKeep: closeReceiptFlow)
        case .priceHistory(let entry):
            PriceHistorySheet(viewModel: PriceHistoryViewModel(entry: entry, priceBook: priceBook),
                              appearance: appearance,
                              onClose: { activeSheet = .manageItems })
        default:
            EmptyView()
        }
    }

    /// ☰ → „Kassenzettel scannen“: neuer Ablauf mit den Artikeln der Liste als Zuordnungs-Kandidaten.
    func openReceiptCapture() {
        openRow = nil
        receiptFlow = ReceiptFlowViewModel(listItemNames: listViewModel.items.map(\.name),
                                           catalog: listViewModel.catalogRepository,
                                           priceBook: priceBook)
        activeSheet = .receiptCapture
    }

    private func reviewReceipt(_ flow: ReceiptFlowViewModel) {
        activeSheet = .receiptReview
        Task { await flow.process() }
    }

    private var savedPriceCount: Int {
        if case .done(let saved) = receiptFlow?.phase { return saved }
        return 0
    }

    private func finishShopping() {
        listViewModel.stageDeletion(.checked)
        closeReceiptFlow()
    }

    func closeReceiptFlow() {
        activeSheet = nil
        receiptFlow = nil
    }
}
