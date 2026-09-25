/*
 ShoppingListView+DesignLaunch.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nur DEBUG: öffnet per Launch-Argument ein Overlay oder Sheet, damit Simulator-Screenshots
   direkt gegen design-handoff/Design/png verglichen werden können.

 🔰 Notes for Beginners:
 - Beispiel: `-uiTestFixture -designFixture -designOverlay sort`
   Werte: menu, sort, copy, delete, copied, undo · `-designSheet <name>` siehe `designSheet(named:)`
   (u. a. receiptCapture, receiptReview, shoppingDone, priceHistory).
 - Im Release-Build ist diese Datei leer.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Pixel-Abgleich).
 ------------------------------------------------------------------------
 */

import SwiftUI

#if DEBUG
extension ShoppingListView {
    /// Wendet `-designOverlay` / `-designSheet` einmalig beim Erscheinen an.
    func applyDesignLaunchState() {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: "designOverlay") {
        case "menu": activeOverlay = .menu
        case "sort": activeOverlay = .sort
        case "copy": activeOverlay = .copy
        case "delete": activeOverlay = .delete
        case "copied": copied = CopyResult(count: listViewModel.uncheckedItems.count, scope: .open)
        case "undo":
            // Warten, bis die Beispiel-Artikel ihre endgültige ID im Store haben.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                listViewModel.stageDeletion(.all)
            }
        default: break
        }
        if let name = defaults.string(forKey: "designSheet"), let sheet = designSheet(named: name) {
            activeSheet = sheet
        }
    }

    private func designSheet(named name: String) -> ActiveListSheet? {
        switch name {
        case "search": return .search
        case "newItem": return .newItem(initialName: "Milch")
        case "edit": return listViewModel.items.first.map { .edit($0) }
        case "productImage": return listViewModel.items.first.map { .productImage($0) }
        case "lists": return .lists
        case "barcode": return .barcode
        case "importClipboard":
            UIPasteboard.general.string = "Milch 2 l\nEier 10 Stk\nBrot\nÄpfel 1 kg\nButter"
            return .importClipboard
        case "createList": return .createList
        case "listOptions": return listViewModel.defaultList.map { .listOptions($0) }
        case "shareMembers": return listViewModel.defaultList.map { .shareMembers($0) }
        case "settings": return .settings
        case "editProfile": return .editProfile
        case "deleteAccount": return .deleteAccount
        case "manageCategories": return .manageCategories
        case "editCategory": return .editCategory(categoryStore.categories.first { $0.name == "Milchprodukte" })
        case "receiptCapture":
            receiptFlow = designReceiptFlow(filled: false)
            return .receiptCapture
        case "receiptReview":
            receiptFlow = designReceiptFlow(filled: true)
            return .receiptReview
        case "shoppingDone":
            receiptFlow = designReceiptFlow(filled: true)
            return .shoppingDone
        case "priceHistory":
            if let repo = listViewModel.catalogRepository, manageItemsVM == nil {
                manageItemsVM = ManageItemsViewModel(repository: repo)
            }
            return .priceHistory(.priceHistorySample)
        case "manageItems":
            if let repo = listViewModel.catalogRepository, manageItemsVM == nil {
                manageItemsVM = ManageItemsViewModel(repository: repo)
            }
            return .manageItems
        default: return nil
        }
    }

    /// Positionen aus ReceiptReview.dc.html (Edeka, 5 Positionen, 11,51 €).
    private func designReceiptFlow(filled: Bool) -> ReceiptFlowViewModel {
        let flow = ReceiptFlowViewModel(listItemNames: listViewModel.items.map(\.name), catalog: nil, priceBook: priceBook)
        guard filled else { return flow }
        let rows: [(String, String, String, ReceiptItemMatcher.Status)] = [
            ("KERRYGOLD BUTTER", "2.49", "Kerrygold, original irische Butter", .matched),
            ("ALPRO SOJA DRINK", "2.29", "Soyamilch · alpro", .matched),
            ("KOKOSM. 400ML", "1.39", "Kokosmilch · Freshona?", .check),
            ("MANDELDR.O.Z.", "1.85", "Milch Mandel ohne Zucker", .matched),
            ("FAIRGL.VM SCHOKO", "3.49", "Bio Vollmilch-Schokolade", .new)
        ]
        flow.storeName = "Edeka"
        flow.purchaseDate = Date()
        flow.lines = rows.map { ReceiptReviewLine(id: UUID(), raw: $0.0, price: Decimal(string: $0.1) ?? 0, itemName: $0.2, status: $0.3) }
        return flow
    }
}
#endif
