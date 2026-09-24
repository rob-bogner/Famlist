/*
 NewItemSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Neuer Artikel“ (Höhe 790). Ersetzt AddItemView.
   Titelzeile → 18 → [Foto 104 · 14 · Name-Feld 52] → 20 → Menge [Stepper 148 × 52 · 10 · Einheit]
   → 20 → Kategorie-Chips 42. Primär-Button unten 34 bzw. 14 über der Tastatur.

 🔰 Notes for Beginners:
 - Formularzustand und Validierung liefert ItemFormViewModel (wie bisher bei AddItemView).
 - Die Namens-Fehlermeldung erscheint erst nach dem ersten Tippen oder dem ersten Absenden.
 - Speichern geht über ListViewModel.addItem → SwiftData → SyncEngine (Offline-First).

 📝 Last Change:
 - Initial creation (aus ItemFormScreens des Design-Pakets MyListUI).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid "new item" form sheet.
struct NewItemSheet: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @StateObject private var formVM: ItemFormViewModel
    @State private var attemptedSubmit = false

    let k: SheetTheme
    let maxHeight: CGFloat
    let keyboardHeight: CGFloat
    let onClose: () -> Void
    /// Unbekannter Barcode aus dem Scanner: wird mit dem neuen Artikel im Artikelstamm gespeichert.
    let barcode: String?

    init(initialName: String, barcode: String? = nil, k: SheetTheme, maxHeight: CGFloat, keyboardHeight: CGFloat,
         onClose: @escaping () -> Void) {
        _formVM = StateObject(wrappedValue: ItemFormViewModel(initialName: initialName))
        self.barcode = barcode
        self.k = k
        self.maxHeight = maxHeight
        self.keyboardHeight = keyboardHeight
        self.onClose = onClose
    }

    private var bottomInset: CGFloat { keyboardHeight > 0 ? keyboardHeight + 14 : 34 }
    private var visibleNameError: String? {
        (attemptedSubmit || !formVM.name.isEmpty) ? formVM.nameError : nil
    }

    var body: some View {
        HybridSheetLayer(k: k, title: "Neuer Artikel", designHeight: 790, maxHeight: maxHeight, onClose: onClose) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    form
                        .padding(.top, 18)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 56 + bottomInset + 20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                CTAButton(title: "Zur Liste hinzufügen", k: k, isEnabled: formVM.isValid || !attemptedSubmit, action: submit)
                    .padding(.horizontal, 20)
                    .padding(.bottom, bottomInset)
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .onChange(of: formVM.name) { _, _ in formVM.validateField(.name) }
        .onChange(of: formVM.units) { _, _ in formVM.validateField(.units) }
        .onAppear { formVM.validateAll() }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                PhotoAddTile(k: k, image: $formVM.selectedImage)
                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Name", k: k)
                    SheetTextField(k: k, text: $formVM.name, placeholder: "Name", height: 52,
                                   error: visibleNameError, autoFocus: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Menge", k: k)
                HStack(spacing: 10) {
                    SheetQuantityStepper(k: k, quantity: unitsBinding)
                    UnitPickerMenu(k: k, measure: $formVM.measure)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                FieldLabel(text: "Kategorie", k: k)
                CategoryChipRow(k: k, selection: $formVM.category, categories: listViewModel.categoryOrder)
            }
        }
    }

    /// Bridges the String units of ItemFormViewModel to the Int stepper.
    private var unitsBinding: Binding<Int> {
        Binding(get: { Int(formVM.units) ?? 1 }, set: { formVM.units = String($0) })
    }

    private func submit() {
        attemptedSubmit = true
        formVM.validateAll()
        guard formVM.isValid else { return }
        listViewModel.addItem(formVM.toItemModel(), barcode: barcode)
        onClose()
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        NewItemSheet(initialName: "Milch", k: SheetTheme(.light), maxHeight: 790, keyboardHeight: 0, onClose: {})
    }
    .ignoresSafeArea()
    .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
