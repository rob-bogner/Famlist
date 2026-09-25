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
 - `draft`: Eingaben, die vor dem Wechsel in den Preisverlauf gemacht wurden. Beim Zurückkehren
   füllt der Entwurf das Formular; `item` bleibt der gespeicherte Stand (Vergleich „Preis geändert“).

 📝 Last Change:
 - Eingaben überstehen den Wechsel in den Preisverlauf (vorher war ein eingetippter Preis danach weg).
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
    /// Link „Preisverlauf“ neben dem Preis (EditItem.dc.html); bekommt die aktuellen Eingaben als Entwurf. nil = kein Link.
    var onPriceHistory: ((ItemModel) -> Void)?
    /// Liefert die Unterzeile des Links („zuletzt 2,49 €“); läuft im Hintergrund, blockiert nichts.
    var lastPriceText: (() async -> String?)?
    /// Preis wurde beim Speichern geändert (> 0) → Preispunkt für den Verlauf anlegen. nil = nichts tun.
    var onPriceChanged: ((ItemModel) -> Void)?
    @State private var priceSubtitle = "Preise & Läden"

    init(item: ItemModel, draft: ItemModel? = nil, k: SheetTheme, maxHeight: CGFloat, keyboardHeight: CGFloat,
         onClose: @escaping () -> Void, onSave: ((ItemModel) -> Void)? = nil,
         onPriceHistory: ((ItemModel) -> Void)? = nil, lastPriceText: (() async -> String?)? = nil,
         onPriceChanged: ((ItemModel) -> Void)? = nil) {
        let start = draft.flatMap { $0.id == item.id ? $0 : nil } ?? item
        _formVM = StateObject(wrappedValue: ItemFormViewModel(item: start))
        self.item = item
        self.k = k
        self.maxHeight = maxHeight
        self.keyboardHeight = keyboardHeight
        self.onClose = onClose
        self.onSave = onSave
        self.onPriceHistory = onPriceHistory
        self.lastPriceText = lastPriceText
        self.onPriceChanged = onPriceChanged
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
                HStack(spacing: 10) {
                    SheetPriceField(k: k, price: $formVM.price, hasError: formVM.priceError != nil)
                    if let onPriceHistory { priceHistoryLink { onPriceHistory(currentDraft) } }
                }
            }
        }
    }

    /// Link-Taste 52 hoch, Radius 16, field-Fläche: Trend-Icon, „Preisverlauf“ + Unterzeile, Chevron.
    private func priceHistoryLink(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                SVGIcon(EKKIcon.trend, size: 20, color: k.accentText, lineWidth: 1.9)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Preisverlauf")
                        .font(AppFont.dm(15, 600))
                        .foregroundStyle(k.accentText)
                        .lineLimit(1)
                        .minimumScaleFactor(1 / AppFont.maxScale)     // XXL: bis zur Designgröße schrumpfen
                    Text(priceSubtitle)
                        .font(AppFont.dm(12, 400))
                        .foregroundStyle(k.sub)
                        .lineLimit(1)
                        .minimumScaleFactor(1 / AppFont.maxScale)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                SVGIcon(Icon.chevronRight, size: 16, color: k.sub, lineWidth: 2.2)
            }
            .padding(.horizontal, 15)                            // 1 Rahmen + 14 Padding
            .padding(.vertical, 4)                               // wirkt nur bei großer iOS-Schrift
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(CSSBox(shape: RR(16), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preisverlauf anzeigen")
        .accessibilityValue(priceSubtitle)
        .task {
            if let lastPriceText, let text = await lastPriceText() { priceSubtitle = text }
        }
    }

    private var unitsBinding: Binding<Int> {
        Binding(get: { Int(formVM.units) ?? 1 }, set: { formVM.units = String($0) })
    }

    /// Aktuelle Eingaben als Artikel (gleiche ID, Liste und Besitzer wie `item`).
    private var currentDraft: ItemModel {
        formVM.toItemModel(existingId: item.id, listId: item.listId, ownerPublicId: item.ownerPublicId)
    }

    private func save() {
        formVM.validateAll()
        guard formVM.isValid else { return }
        let updated = formVM.toItemModel(existingId: item.id, listId: item.listId, ownerPublicId: item.ownerPublicId)
        logVoid(params: (action: "editItem.save", itemId: item.id, formPrice: formVM.price,
                         oldPrice: item.price, newPrice: updated.price))
        if updated.price > 0, abs(updated.price - item.price) > 0.0001 { onPriceChanged?(updated) }
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

#Preview("Dark") {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        EditItemSheet(item: ItemModel(name: "Butter", units: 1, measure: "pack", price: 2.49, brand: "Kerrygold"),
                      k: SheetTheme(.dark), maxHeight: 790, keyboardHeight: 0, onClose: {})
    }
    .ignoresSafeArea()
    .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
