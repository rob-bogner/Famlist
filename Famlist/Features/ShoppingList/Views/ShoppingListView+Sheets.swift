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
    func sheetLayer(k: SheetTheme, maxHeight: CGFloat, insets: LayoutShift) -> some View {
        ZStack(alignment: .bottom) {
            if let sheet = activeSheet {
                if let base = sheet.baseSheet {
                    // Design: das darunterliegende Sheet (Meine Listen / Einstellungen) weichgezeichnet + eigene Abdunkelung
                    ZStack(alignment: .bottom) {
                        k.scrim
                        if let lower = base.baseSheet {             // Detail → Archiv → Einstellungen
                            sheetView(lower, k: k, maxHeight: maxHeight, insets: insets)
                            overlayScrim(for: base)
                        }
                        sheetView(base, k: k, maxHeight: maxHeight, insets: insets)
                    }
                    .blur(radius: 3, opaque: false)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
                    overlayScrim(for: sheet)
                        .onTapGesture { activeSheet = base }
                        .transition(.opacity)
                        .accessibilityHidden(true)
                } else {
                    k.scrim
                        .onTapGesture(perform: closeSheet)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
                sheetView(sheet, k: k, maxHeight: maxHeight, insets: insets)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)                  // VoiceOver bleibt im obersten Sheet
                    .accessibilityAction(.escape) { escape(sheet) }
                    .id(sheet.id)
                    .transition(sheetTransition(sheet))
                    .zIndex(1)
            }
        }
        .environment(\.hybridSheetMaxHeight, maxHeight)
        .ignoresSafeArea()
        .confirmationDialog(listToDelete.map { "„\($0.title)“ löschen?" } ?? "", isPresented: deleteListBinding,
                            titleVisibility: .visible, presenting: listToDelete) { list in
            Button("Löschen", role: .destructive) { deleteList(list) }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Die Liste und alle ihre Artikel werden für alle Mitglieder gelöscht.")
        }
    }

    /// „Bewegung reduzieren“: nur ein-/ausblenden statt von unten einfahren bzw. skalieren.
    private func sheetTransition(_ sheet: ActiveListSheet) -> AnyTransition {
        if reduceMotion { return .opacity }
        return sheet.isPopup ? .opacity.combined(with: .scale(scale: 0.96)) : .move(edge: .bottom)
    }

    /// VoiceOver-Geste „Zurück“ (Z mit zwei Fingern): wie der Schließen-Knopf des obersten Sheets.
    private func escape(_ sheet: ActiveListSheet) {
        switch sheet {
        case .receiptCapture, .receiptReview, .shoppingDone, .shoppingDoneOffer: closeReceiptFlow()
        case .editCatalog: hideKeyboard(); activeSheet = .manageItems
        case .editProfile: hideKeyboard(); activeSheet = .settings
        default:
            if let base = sheet.baseSheet { hideKeyboard(); activeSheet = base } else { closeSheet() }
        }
    }

    private func overlayScrim(for sheet: ActiveListSheet) -> Color {
        let t = ListAccountTokens(appearance)
        switch sheet {
        case .deleteAccount: return t.scrimDialog
        case .listOptions: return t.scrimMenu
        default: return t.scrimSheet            // CreateList / Umbenennen über „Meine Listen“
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveListSheet, k: SheetTheme, maxHeight: CGFloat, insets: LayoutShift) -> some View {
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
                                 onPriceHistory: { activeSheet = .priceHistory($0) })
            }
        case .editCatalog(let entry):
            EditItemSheet(item: entry.toEditableItem(), k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height,
                          onClose: { hideKeyboard(); activeSheet = .manageItems },
                          onSave: { saveCatalogEdit(from: entry, to: entry.applying($0)) })
        case .edit(let item):
            EditItemSheet(item: item, draft: editDraft, k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height,
                          onClose: closeSheet,
                          onPriceHistory: { draft in hideKeyboard(); editDraft = draft; activeSheet = .itemPriceHistory(item) },
                          lastPriceText: { await lastPriceText(for: item) },
                          onPriceChanged: { recordPrice(for: $0) })
        case .productImage(let item):
            ProductImageSheet(item: item, k: k, maxHeight: maxHeight, onClose: closeSheet)
        case .importClipboard:
            ClipboardImportSheet(k: k, maxHeight: maxHeight, onClose: closeSheet)
        case .lists:
            MyListsSheet(k: k, maxHeight: maxHeight, onClose: closeSheet,
                         onCreate: { activeSheet = .createList },
                         onOptions: { activeSheet = .listOptions($0) })
        case .createList:
            CreateListSheet(appearance: appearance, keyboardHeight: keyboard.height,
                            onClose: { hideKeyboard(); activeSheet = .lists },
                            onCreate: createList)
        case .listOptions(let list):
            listOptions(list, insets: insets)
        case .shareMembers(let list):
            ShareMembersSheet(viewModel: ShareMembersViewModel(list: list, me: session.currentProfile,
                                                               lists: listViewModel.listsRepository,
                                                               profiles: session.profiles),
                              appearance: appearance, publicID: session.currentProfile?.publicId ?? "–",
                              onClose: closeSheet)
        case .settings:
            SettingsSheet(appearance: appearance, onClose: closeSheet,
                          onEditProfile: { activeSheet = .editProfile },
                          onOpenReceipts: { activeSheet = .receiptArchive },
                          onDeleteAccount: { deleteAccountError = nil; activeSheet = .deleteAccount })
        case .editProfile:
            EditProfileSheet(appearance: appearance, onClose: { hideKeyboard(); activeSheet = .settings })
        case .manageCategories:
            ManageCategoriesSheet(store: categoryStore, appearance: appearance, onClose: closeSheet,
                                  onEdit: { activeSheet = .editCategory($0) },
                                  onAdd: { activeSheet = .editCategory(nil) },
                                  onDelete: { deleteCategory($0) })
        case .editCategory(let category):
            EditCategorySheet(appearance: appearance, category: category, keyboardHeight: keyboard.height,
                              isNameAvailable: { categoryStore.isAvailable($0, except: category?.id) },
                              onClose: { hideKeyboard(); activeSheet = .manageCategories },
                              onSave: { saveCategory(category, name: $0, icon: $1) },
                              onDelete: { deleteCategory(category) })
        case .deleteAccount:
            DeleteAccountDialog(appearance: appearance, isWorking: isDeletingAccount, errorText: deleteAccountError,
                                onConfirm: deleteAccount, onCancel: { activeSheet = .settings })
                .offset(y: insets.topShift)
        case .receiptCapture, .receiptReview, .shoppingDone, .priceHistory, .itemPriceHistory, .shoppingDoneOffer,
             .receiptArchive, .receiptDetail:
            receiptSheetView(sheet, k: k)
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

    /// Artikel verwalten → Bearbeiten: Artikelstamm speichern und gleichnamige Artikel der Liste anpassen.
    private func saveCatalogEdit(from old: ItemCatalogEntry, to new: ItemCatalogEntry) {
        manageItemsVM?.update(new)
        listViewModel.applyCatalogEdit(from: old, to: new)
    }

    /// Öffnet „Artikel verwalten“ (ViewModel lebt über das Bearbeiten-Sheet hinweg).
    func openManageItems() {
        guard let repo = listViewModel.catalogRepository else { return }
        if manageItemsVM == nil { manageItemsVM = ManageItemsViewModel(repository: repo) }
        activeSheet = .manageItems
    }

    // MARK: - Listen-Optionen

    private func listOptions(_ list: ListModel, insets: LayoutShift) -> some View {
        let isOwner = list.ownerId == session.currentProfile?.id
        return ListOptionsMenu(appearance: appearance, listName: list.title,
                               isFavorite: session.isFavorite(list), isOwner: isOwner,
                               onRename: { activeSheet = .listName(.rename(list)) },
                               onDuplicate: {
                                   listViewModel.duplicateList(list, ownerId: session.currentProfile?.id ?? list.ownerId)
                                   closeSheet()
                               },
                               onToggleFavorite: {
                                   session.toggleFavorite(list)
                                   activeSheet = .lists
                               },
                               onMembers: { activeSheet = .shareMembers(list) },
                               onDelete: {
                                   if isOwner {
                                       activeSheet = .lists
                                       listToDelete = list
                                   } else if let me = session.currentProfile?.id {
                                       listViewModel.leaveList(list, profileId: me)
                                       activeSheet = .lists
                                   }
                               },
                               onDismiss: { activeSheet = .lists })
            .offset(y: insets.topShift)
    }

    private var deleteListBinding: Binding<Bool> {
        Binding(get: { listToDelete != nil }, set: { if !$0 { listToDelete = nil } })
    }

    private func deleteList(_ list: ListModel) {
        withAnimation(.easeInOut(duration: 0.3)) { listViewModel.deleteList(list) }
        listToDelete = nil
    }

    private func createList(name: String, isFavorite: Bool) {
        guard let me = session.currentProfile?.id ?? listViewModel.defaultList?.ownerId else { return }
        hideKeyboard()
        activeSheet = .lists
        listViewModel.createNewList(title: name, ownerId: me) { created in
            if isFavorite, let profile = session.currentProfile {
                session.setFavorite(created.id, profile: profile, listTitle: created.title)
            }
        }
    }

    private func deleteAccount() {
        isDeletingAccount = true
        deleteAccountError = nil
        Task {
            let ok = await session.deleteAccount()
            isDeletingAccount = false
            if ok {
                activeSheet = nil
            } else {
                deleteAccountError = session.errorMessage
            }
        }
    }

    // MARK: - Kategorien

    private func saveCategory(_ category: CategoryDefinition?, name: String, icon: String) {
        hideKeyboard()
        if let category {
            if let oldName = categoryStore.update(category.id, name: name, icon: icon),
               let newName = categoryStore.categories.first(where: { $0.id == category.id })?.name {
                listViewModel.reassignCategory(from: oldName, to: newName)
            }
        } else {
            categoryStore.add(name: name, icon: icon)
        }
        activeSheet = .manageCategories
    }

    private func deleteCategory(_ category: CategoryDefinition?) {
        guard let category, let removed = categoryStore.delete(category.id) else { return }
        listViewModel.reassignCategory(from: removed, to: CategoryDefinition.fallbackName)
        activeSheet = .manageCategories
    }
}
