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
 - Einkaufsdaten: Artikel, Kategorien und Einkaufsbeginn an den Ablauf; Beginn nach Speichern/Erledigt zurücksetzen.
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
                                   onBack: {
                                       flow.backToCapture()
                                       activeSheet = .receiptCapture
                                   },
                                   onSaved: {
                                       listViewModel.resetShoppingStart()      // der Bon hat den Beginn übernommen
                                       activeSheet = .shoppingDone
                                   },
                                   onUpdateItemPrices: { changes in
                                       Task { await listViewModel.applyReceiptPrices(changes) }
                                   },
                                   onSetItemBought: { item, bought in setItemChecked(item, bought) },
                                   keyboardHeight: keyboard.height)
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
        case .receiptArchive(let fromMenu):
            let access = receiptArchiveViewModel()
            // Aus dem Menü gibt es keine Einstellungen darunter: „Zurück“ schließt dann.
            ReceiptArchiveSheet(archive: receiptArchive, appearance: appearance,
                                currentUserId: session.currentProfile?.id, ownedListIds: access.ownedListIds,
                                onBack: { if fromMenu { closeSheet() } else { activeSheet = .settings } },
                                onClose: closeSheet,
                                onOpen: { activeSheet = .receiptDetail($0, fromMenu: fromMenu) })
        case .receiptDetail(let receipt, let fromMenu):
            ReceiptDetailSheet(receipt: receipt, archive: receiptArchive, appearance: appearance,
                               canDelete: receiptArchiveViewModel().canDelete(receipt),
                               onBack: { activeSheet = .receiptArchive(fromMenu: fromMenu) }, onClose: closeSheet,
                               onDelete: {
                                   activeSheet = .receiptArchive(fromMenu: fromMenu)
                                   Task { await receiptArchive.delete(receipt) }
                               },
                               context: receiptLineContext(),
                               onOpenHistory: { name in
                                   activeSheet = .receiptPriceHistory(catalogEntry(named: name),
                                                                      back: .receiptDetail(receipt, fromMenu: fromMenu))
                               })
        case .receiptInsights(let tab, let month, let fromMenu):
            ReceiptInsightsSheet(viewModel: receiptInsightsViewModel(tab: tab, month: month), appearance: appearance,
                                 onClose: { activeSheet = .receiptArchive(fromMenu: fromMenu) },
                                 onOpenHistory: { name, tab, month in
                                     activeSheet = .receiptPriceHistory(catalogEntry(named: name),
                                                                        back: .receiptInsights(tab: tab, month: month,
                                                                                               fromMenu: fromMenu))
                                 })
        case .receiptPriceHistory(let entry, let back):
            PriceHistorySheet(viewModel: PriceHistoryViewModel(entry: entry, priceBook: priceBook),
                              appearance: appearance,
                              onClose: { activeSheet = back })
        default:
            EmptyView()
        }
    }

    /// Kategorien, Farben und Nachschlagen für gespeicherte Bons (Design-Modus: Werte der Boards).
    func receiptLineContext() -> ReceiptLineContext {
        #if DEBUG
        if UITestFixture.designMode { return .designSample }
        #endif
        return ReceiptLineContext(receipts: receiptArchive.receipts, listItems: listViewModel.items,
                                  categories: categoryStore.categories)
    }

    /// Auswertung über alle Bons des Archivs (offline, ausstehende eingeschlossen); Design-Modus: Board-Daten.
    func receiptInsightsViewModel(tab: InsightTab, month: Date?) -> ReceiptInsightsViewModel {
        #if DEBUG
        if UITestFixture.designMode {
            let september = ReceiptTimes.calendar.date(from: DateComponents(year: 2026, month: 9, day: 28)) ?? Date()
            return ReceiptInsightsViewModel(receipts: ArchivedReceipt.insightSamples, context: .designSample, tab: tab,
                                            month: month, now: september)
        }
        #endif
        return ReceiptInsightsViewModel(receipts: receiptArchive.receipts, context: receiptLineContext(), tab: tab,
                                        month: month)
    }

    /// Artikel für den Preisverlauf: aus der Liste, sonst ein Eintrag nur mit dem Namen (Verlauf kommt aus dem PriceBook).
    func catalogEntry(named name: String) -> ItemCatalogEntry {
        let key = CatalogOperation.key(name)
        if let item = listViewModel.items.first(where: { CatalogOperation.key($0.name) == key }) {
            return .from(item: item, ownerPublicId: item.ownerPublicId ?? "")
        }
        return ItemCatalogEntry(id: "receipt-\(key)", ownerPublicId: "", name: name, brand: nil, category: nil,
                                productDescription: nil, measure: "", price: 0, imageData: nil)
    }

    /// Archiv-Anzeige: Löschen dürfen Ersteller und Besitzer der Liste (Migration 021).
    func receiptArchiveViewModel() -> ReceiptArchiveViewModel {
        let me = session.currentProfile?.id
        let owned = Set(listViewModel.allLists.filter { $0.ownerId == me }.map(\.id))
        return ReceiptArchiveViewModel(archive: receiptArchive, currentUserId: me, ownedListIds: owned)
    }

    /// ☰ → „Kassenzettel scannen“: neuer Ablauf mit den Artikeln der Liste als Zuordnungs-Kandidaten.
    func openReceiptCapture() {
        openRow = nil
        receiptFlow = ReceiptFlowViewModel(listItemNames: listViewModel.items.map(\.name),
                                           listPrices: Dictionary(listViewModel.items.map { ($0.name, $0.price) },
                                                                  uniquingKeysWith: { first, _ in first }),
                                           checkedItems: listViewModel.items.filter(\.isChecked),
                                           listItems: listViewModel.items,
                                           categories: categoryStore.categories,
                                           catalog: listViewModel.catalogRepository,
                                           priceBook: priceBook,
                                           archive: receiptArchive,
                                           origin: ReceiptArchiveOrigin(listId: listViewModel.listId,
                                                                        listTitle: listViewModel.defaultList?.title,
                                                                        createdBy: session.currentProfile?.id,
                                                                        creatorName: session.currentProfile?.displayName,
                                                                        listStart: ShoppingStartStore.start(listId: listViewModel.listId)))
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

    /// „Nicht gekauft“ / „Rückgängig“ aus „Kassenzettel prüfen“: Abhak-Status auf der Liste setzen.
    private func setItemChecked(_ item: ItemModel, _ checked: Bool) {
        guard let current = listViewModel.items.first(where: { $0.id == item.id }), current.isChecked != checked else { return }
        listViewModel.toggleItemChecked(current)
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
        listViewModel.resetShoppingStart()
        closeReceiptFlow()
    }

    func closeReceiptFlow() {
        activeSheet = nil
        receiptFlow = nil
    }
}
