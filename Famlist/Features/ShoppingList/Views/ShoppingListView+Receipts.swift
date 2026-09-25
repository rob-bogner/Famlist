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
 - „Preise übernehmen“ (Rückfrage in „Kassenzettel prüfen“) setzt die Bon-Preise in Liste und Artikelstamm.
 - Preisverlauf: Schließen führt zurück zu „Artikel verwalten“ (liegt weichgezeichnet darunter).

 📝 Last Change:
 - Bon-Preise als neue Artikelpreise übernehmen; Listenpreise für den Vergleich an den Ablauf übergeben.
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
                                   onSaved: { activeSheet = .shoppingDone },
                                   onUpdateItemPrices: { changes in
                                       Task { await listViewModel.applyReceiptPrices(changes) }
                                   })
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
        case .itemPriceHistory(let item):
            // Aktuellen Stand aus der Liste nehmen: der Snapshot im Sheet-Fall kennt einen frisch gespeicherten Preis nicht.
            let current = listViewModel.items.first { $0.id == item.id } ?? item
            PriceHistorySheet(viewModel: PriceHistoryViewModel(entry: .from(item: current, ownerPublicId: current.ownerPublicId ?? ""),
                                                               priceBook: priceBook, fallbackStore: currentStoreName),
                              appearance: appearance,
                              onClose: { activeSheet = .edit(item) })
        case .shoppingDoneOffer:
            // Design: ShoppingDoneScan.dc.html – noch ohne Kassenzettel
            ShoppingDoneView(appearance: appearance,
                             listName: listViewModel.defaultList?.title ?? String(localized: "shoppingList.title"),
                             itemCount: listViewModel.checkedItemCount,
                             totalCount: listViewModel.items.count,
                             hasReceipt: false,
                             onFinish: finishShopping,
                             onKeep: closeReceiptFlow,
                             onScan: openReceiptCapture)
        default:
            EmptyView()
        }
    }

    /// ☰ → „Kassenzettel scannen“: neuer Ablauf mit den Artikeln der Liste als Zuordnungs-Kandidaten.
    func openReceiptCapture() {
        openRow = nil
        receiptFlow = ReceiptFlowViewModel(listItemNames: listViewModel.items.map(\.name),
                                           listPrices: Dictionary(listViewModel.items.map { ($0.name, $0.price) },
                                                                  uniquingKeysWith: { first, _ in first }),
                                           catalog: listViewModel.catalogRepository,
                                           priceBook: priceBook)
        activeSheet = .receiptCapture
    }

    /// ListViewModel meldet „Einkauf erledigt“ → nach kurzer Pause anbieten, wenn nichts anderes offen ist.
    func offerShoppingDone(for event: UUID) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)            // Abhak-Animation sichtbar lassen
            guard listViewModel.shoppingCompletedEvent == event, listViewModel.isShoppingComplete,
                  activeSheet == nil, activeOverlay == nil else { return }
            activeSheet = .shoppingDoneOffer
        }
    }

    /// Unterzeile für den Link „Preisverlauf“: „zuletzt 2,49 €“, ohne Preise „Noch keine Preise“.
    /// Zuerst Zwischenspeicher (sofort), sonst einmal den Verlauf laden.
    func lastPriceText(for item: ItemModel) async -> String? {
        var last = priceBook.cachedLatest(itemName: item.name)
        if last == nil { last = priceBook.localHistory(itemName: item.name).last }    // ohne Netz, sofort
        if let last { return "zuletzt \(PriceHistoryViewModel.euro(last.price))" }
        let current = listViewModel.items.first { $0.id == item.id } ?? item
        return current.price > 0 ? "zuletzt \(PriceDisplaySetting.euro(current.price))" : "Noch keine Preise"
    }

    /// Ladenname für Preispunkte aus „Artikel bearbeiten“: der Listenname (z. B. „Edeka“).
    var currentStoreName: String {
        listViewModel.defaultList?.title ?? String(localized: "shoppingList.title")
    }

    /// Neuer Preis in „Artikel bearbeiten“ → Preispunkt für den Preisverlauf (Logik im PriceBook).
    func recordPrice(for item: ItemModel) {
        priceBook.recordManualPrice(itemName: item.name, price: item.price, store: currentStoreName)
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
