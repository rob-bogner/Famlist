/*
 ShoppingListView+Sheets.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet-Ebene der Liste: Abdunkelung + Hybrid-Sheet von unten (Suchen, Neuer Artikel, Bearbeiten,
   Produktbild, Meine Listen, Listen-Name).

 🔰 Notes for Beginners:
 - Es ist immer höchstens ein Sheet offen (ActiveListSheet).
 - Die Sheets bekommen `hybridSheetMaxHeight`, damit feste Designhöhen (790 …) auf kleinen
   Geräten nicht über den Bildschirm ragen.

 📝 Last Change:
 - Aus ShoppingListView ausgelagert (Redesign „Hybrid“).
 ------------------------------------------------------------------------
 */

import SwiftUI

extension ShoppingListView {
    @ViewBuilder
    func sheetLayer(k: SheetTheme, maxHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            if activeSheet != nil {
                k.scrim
                    .onTapGesture(perform: closeSheet)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            if let sheet = activeSheet {
                // Scanner ist Vollbild und bringt seinen eigenen Hintergrund mit.
                sheetView(sheet, k: k, maxHeight: maxHeight)
                    .environment(\.hybridSheetMaxHeight, maxHeight)
                    .id(sheet.id)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveListSheet, k: SheetTheme, maxHeight: CGFloat) -> some View {
        switch sheet {
        case .search:
            if let catalog = listViewModel.catalogRepository {
                ItemSearchSheet(catalogRepository: catalog,
                                globalCatalogRepository: listViewModel.globalCatalogRepository,
                                k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height,
                                onClose: closeSheet,
                                onCreateNew: { activeSheet = .newItem(initialName: $0) })
            }
        case .newItem(let name, let barcode):
            NewItemSheet(initialName: name, barcode: barcode, k: k, maxHeight: maxHeight,
                         keyboardHeight: keyboard.height, onClose: closeSheet)
        case .barcode:
            BarcodeScanSheet(viewModel: BarcodeScanViewModel(catalog: listViewModel.catalogRepository,
                                                             global: listViewModel.globalCatalogRepository),
                             appearance: appearance,
                             previewProduct: designScanPreview,
                             onClose: closeSheet,
                             onAdd: addScanned,
                             onUnknown: { activeSheet = .newItem(initialName: "", barcode: $0) })
        case .manageItems:
            if let vm = manageItemsVM {
                ManageItemsSheet(viewModel: vm, appearance: appearance, onClose: closeSheet,
                                 onEdit: { activeSheet = .editCatalog($0) },
                                 onPriceHistory: nil)
            }
        case .editCatalog(let entry):
            EditItemSheet(item: entry.toEditableItem(), k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height,
                          onClose: { hideKeyboard(); activeSheet = .manageItems },
                          onSave: { manageItemsVM?.update(entry.applying($0)) })
        case .edit(let item):
            EditItemSheet(item: item, k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height, onClose: closeSheet)
        case .productImage(let item):
            ProductImageSheet(item: item, k: k, maxHeight: maxHeight, onClose: closeSheet)
        case .lists:
            MyListsSheet(k: k, maxHeight: maxHeight, onClose: closeSheet,
                         onCreate: { activeSheet = .listName(.create) },
                         onRename: { activeSheet = .listName(.rename($0)) })
        case .listName(let mode):
            ListNameSheet(mode: mode, k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height) {
                hideKeyboard()
                activeSheet = .lists             // zurück zur Listenverwaltung
            }
        }
    }

    /// Nur DEBUG `-designSheet barcode`: Karte „Artikel erkannt“ wie im Design (Simulator hat keine Kamera).
    private var designScanPreview: ScannedProduct? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "designSheet") == "barcode" ? .designSample : nil
        #else
        return nil
        #endif
    }

    /// Barcode-Scanner: erkannten Artikel mit Menge zur Liste hinzufügen.
    private func addScanned(_ product: ScannedProduct, quantity: Int) {
        var item = product.entry.toItemModel(listId: listViewModel.listId.uuidString,
                                             ownerPublicId: listViewModel.defaultList?.ownerId.uuidString)
        item.units = quantity
        listViewModel.addItem(item, barcode: product.barcode)
    }

    /// Öffnet „Artikel verwalten“ (ViewModel lebt über das Bearbeiten-Sheet hinweg).
    func openManageItems() {
        guard let repo = listViewModel.catalogRepository else { return }
        if manageItemsVM == nil { manageItemsVM = ManageItemsViewModel(repository: repo) }
        activeSheet = .manageItems
    }
}
