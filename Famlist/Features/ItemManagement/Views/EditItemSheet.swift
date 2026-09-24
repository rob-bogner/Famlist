/*
 EditItemSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Artikel bearbeiten“ (Höhe 726). Ersetzt EditItemView.
   Titelzeile → 16 → [Foto 104 · 14 · Name 48 / 8 / Marke 48] → 10 → Beschreibung 48 → 16 →
   Kategorie → 16 → Menge → 16 → Preis 148 × 52. Primär-Button „Speichern“ unten.

 🔰 Notes for Beginners:
 - ItemFormViewModel(item:) übernimmt alle Felder inklusive isChecked und isUnavailable,
   damit Speichern keinen Status zurücksetzt.
 - Speichern geht über ListViewModel.updateItem → SyncEngine (neuer HLC → Last-Writer-Wins).

 📝 Last Change:
 - Initial creation (aus ItemFormScreens des Design-Pakets MyListUI).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid "edit item" form sheet.
struct EditItemSheet: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @StateObject private var formVM: ItemFormViewModel

    let item: ItemModel
    let k: SheetTheme
    let maxHeight: CGFloat
    let keyboardHeight: CGFloat
    let onClose: () -> Void
    /// Eigene Speicher-Aktion (Artikel verwalten → Artikelstamm). nil = Listenartikel aktualisieren.
    var onSave: ((ItemModel) -> Void)?

    init(item: ItemModel, k: SheetTheme, maxHeight: CGFloat, keyboardHeight: CGFloat,
         onClose: @escaping () -> Void, onSave: ((ItemModel) -> Void)? = nil) {
        _formVM = StateObject(wrappedValue: ItemFormViewModel(item: item))
        self.item = item
        self.k = k
        self.maxHeight = maxHeight
        self.keyboardHeight = keyboardHeight
        self.onClose = onClose
        self.onSave = onSave
    }

    private var bottomInset: CGFloat { keyboardHeight > 0 ? keyboardHeight + 14 : 34 }

    var body: some View {
        HybridSheetLayer(k: k, title: "Artikel bearbeiten", designHeight: 726, maxHeight: maxHeight, onClose: onClose) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    form
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 56 + bottomInset + 20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                CTAButton(title: "Speichern", k: k, isEnabled: formVM.isValid, action: save)
                    .padding(.horizontal, 20)
                    .padding(.bottom, bottomInset)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .onChange(of: formVM.name) { _, _ in formVM.validateField(.name) }
        .onChange(of: formVM.units) { _, _ in formVM.validateField(.units) }
        .onChange(of: formVM.price) { _, _ in formVM.validateField(.price) }
        .onAppear { formVM.validateAll() }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                PhotoAddTile(k: k, image: $formVM.selectedImage)
                VStack(spacing: 8) {
                    SheetTextField(k: k, text: $formVM.name, placeholder: "Name", error: formVM.nameError)
                    SheetTextField(k: k, text: $formVM.brand, placeholder: "Marke", weight: 400, isSecondary: true)
                }
            }

            SheetTextField(k: k, text: $formVM.productDescription, placeholder: "Beschreibung", weight: 400, isSecondary: true)
                .padding(.top, -6)                       // margin-top: -6 → Abstand 10

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "Kategorie", k: k)
                CategoryChipRow(k: k, selection: $formVM.category, categories: listViewModel.categoryOrder)
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Menge", k: k)
                HStack(spacing: 10) {
                    SheetQuantityStepper(k: k, quantity: unitsBinding)
                    UnitPickerMenu(k: k, measure: $formVM.measure)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Preis", k: k)
                SheetPriceField(k: k, price: $formVM.price, hasError: formVM.priceError != nil)
            }
        }
    }

    private var unitsBinding: Binding<Int> {
        Binding(get: { Int(formVM.units) ?? 1 }, set: { formVM.units = String($0) })
    }

    private func save() {
        formVM.validateAll()
        guard formVM.isValid else { return }
        let updated = formVM.toItemModel(existingId: item.id, listId: item.listId, ownerPublicId: item.ownerPublicId)
        if let onSave {
            onSave(updated)
        } else {
            listViewModel.updateItem(updated)
        }
        onClose()
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        EditItemSheet(item: ItemModel(name: "Butter", units: 1, measure: "pack", price: 2.49, brand: "Kerrygold"),
                      k: SheetTheme(.light), maxHeight: 790, keyboardHeight: 0, onClose: {})
    }
    .ignoresSafeArea()
    .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
