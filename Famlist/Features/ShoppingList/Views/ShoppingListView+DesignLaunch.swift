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
   Werte: menu, sort, copy, delete, copied, undo · `-designSheet <name>` siehe `designSheet(named:)`.
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
        case "manageItems":
            if let repo = listViewModel.catalogRepository, manageItemsVM == nil {
                manageItemsVM = ManageItemsViewModel(repository: repo)
            }
            return .manageItems
        default: return nil
        }
    }
}
#endif
