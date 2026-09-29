/*
 ProductDetailSheet.swift
 Famlist
 Created on: 28.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Produktdetails“ (ProductDetail.dc.html, Sheet 790 über der Liste). Ersetzt „Neuer Artikel“,
   „Artikel bearbeiten“ und „Produktbild“. Kopf 330 mit Produktbild → 24 → Name/Marke links, Preis rechts
   → 20 → Karten 2 × 2 (Kategorie, Maßeinheit, Menge, Preisverlauf) → 18 → Linie → 14 → Beschreibung.
 - Griff oben, ✕ oben rechts (14 / 16). Stift „Bearbeiten“ unten rechts am Bild (nur Ansehen).
   Beim Bearbeiten unten „Speichern“, bei neuen Artikeln „Zur Liste hinzufügen“.

 🔰 Notes for Beginners:
 - Beim Bearbeiten werden die Texte an derselben Stelle zu Eingabefeldern (Rahmen 11 pt nach außen
   gerückt, damit der Text stehen bleibt). Kategorie und Maßeinheit öffnen ein Menü.
 - Menge und Preisverlauf fehlen im Artikelstamm (Artikel verwalten): `showsQuantity` / `onPriceHistory`.
 - Wurde aus „Ansehen“ bearbeitet, bleibt der Screen nach „Speichern“ offen und zeigt die neuen Werte.
 - Die Anzeige liest immer aus dem Formular (ItemFormViewModel), damit sie nach dem Speichern stimmt.

 📝 Last Change:
 - Vollbild → Sheet (Griff, Herunterziehen schließt), Stift unten rechts am Bild.
 - Ziehen am Bild/Inhalt nach unten bewegt das ganze Sheet (SheetPullTracker, kein weißer Spalt);
   Bild beginnt ohne 1-pt-Streifen ganz oben.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

/// Product detail sheet: view, edit in place, or create a new item.
struct ProductDetailSheet: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @StateObject private var formVM: ItemFormViewModel

    /// Gespeicherter Stand (nil = neuer Artikel).
    let item: ItemModel?
    let k: SheetTheme
    let keyboardHeight: CGFloat
    /// Karte „Menge in der Liste“ (nicht im Artikelstamm).
    let showsQuantity: Bool
    /// Unbekannter Barcode aus dem Scanner (nur neue Artikel).
    let barcode: String?
    let onClose: () -> Void
    /// Eigene Speicher-Aktion (Artikel verwalten → Artikelstamm). nil = Listenartikel aktualisieren.
    var onSave: ((ItemModel) -> Void)?
    /// Karte „Preisverlauf“; bekommt die aktuellen Eingaben als Entwurf. nil = keine Karte.
    var onPriceHistory: ((ItemModel) -> Void)?
    /// Liefert „zuletzt 2,49 €“ für die Karte „Preisverlauf“.
    var lastPriceText: (() async -> String?)?
    /// Preis wurde beim Speichern geändert (> 0) → Preispunkt für den Verlauf anlegen.
    var onPriceChanged: ((ItemModel) -> Void)?

    @State private var mode: ProductDetailMode
    /// Aus „Ansehen“ heraus bearbeitet → nach dem Speichern zurück zu „Ansehen“.
    @State private var returnsToView = false
    @State private var quantityEditing = false
    @State private var attemptedSubmit = false
    @State private var priceSubtitle = "Preise & Läden"
    @State private var showPhotoSource = false
    @State private var showPicker = false
    @State private var dragOffset: CGFloat = 0
    /// Wie weit der Inhalt oben über den Anfang hinaus gezogen ist (> 0 = Überziehen am Anfang).
    @State private var pull: CGFloat = 0
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @FocusState private var nameFocused: Bool
    @FocusState private var brandFocused: Bool
    @FocusState private var descriptionFocused: Bool

    /// Bestehender Artikel: `startInEdit` = direkt bearbeiten (Wischaktion „Bearbeiten“, Artikel verwalten).
    init(item: ItemModel, draft: ItemModel? = nil, startInEdit: Bool, k: SheetTheme, keyboardHeight: CGFloat,
         showsQuantity: Bool = true, onClose: @escaping () -> Void, onSave: ((ItemModel) -> Void)? = nil,
         onPriceHistory: ((ItemModel) -> Void)? = nil, lastPriceText: (() async -> String?)? = nil,
         onPriceChanged: ((ItemModel) -> Void)? = nil) {
        let start = draft.flatMap { $0.id == item.id ? $0 : nil } ?? item
        _formVM = StateObject(wrappedValue: ItemFormViewModel(item: start))
        _mode = State(initialValue: startInEdit ? .edit : .view)
        self.item = item
        self.k = k
        self.keyboardHeight = keyboardHeight
        self.showsQuantity = showsQuantity
        self.barcode = nil
        self.onClose = onClose
        self.onSave = onSave
        self.onPriceHistory = onPriceHistory
        self.lastPriceText = lastPriceText
        self.onPriceChanged = onPriceChanged
    }

    /// Neuer Artikel (Plus → „… als neuen Artikel anlegen“ oder unbekannter Barcode).
    init(newItemName: String, barcode: String? = nil, k: SheetTheme, keyboardHeight: CGFloat,
         onClose: @escaping () -> Void) {
        _formVM = StateObject(wrappedValue: ItemFormViewModel(initialName: newItemName))
        _mode = State(initialValue: .new)
        self.item = nil
        self.k = k
        self.keyboardHeight = keyboardHeight
        self.showsQuantity = true
        self.barcode = barcode
        self.onClose = onClose
    }

    private var bottomInset: CGFloat { keyboardHeight > 0 ? keyboardHeight + 14 : 34 }
    /// Bei offener Tastatur verdeckt: Tastatur + Schnellwahl-Leiste bzw. 14 Abstand + CTA 56, dazu 12 Luft.
    private var revealInset: CGFloat {
        keyboardHeight + (quantityEditing ? QuantityPresetBar.height : 14 + 56) + 12
    }
    private var visibleNameError: String? {
        (attemptedSubmit || !formVM.name.isEmpty) ? formVM.nameError : nil
    }

    static let designHeight: CGFloat = 790

    var body: some View {
        SheetSurface(k: k, height: Self.designHeight) {
            sheetContent
        }
        .offset(y: dragOffset + pull)                 // Überziehen am Anfang zieht das ganze Sheet mit
        .accessibilityAction(.escape, onClose)
        // Aktionskarte statt Systemdialog (Design: PhotoSourceDialog)
        .actionCard(isPresented: $showPhotoSource, k: k) {
            .photoSource(k: k, hasImage: formVM.selectedImage != nil,
                         onCamera: { pickerSource = .camera; showPicker = true },
                         onLibrary: { pickerSource = .photoLibrary; showPicker = true },
                         onRemove: { formVM.selectedImage = nil })
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(selectedImage: $formVM.selectedImage, isPresented: $showPicker, sourceType: pickerSource)
        }
        .onChange(of: formVM.name) { _, _ in formVM.validateField(.name) }
        .onChange(of: formVM.units) { _, _ in formVM.validateField(.units) }
        .onChange(of: formVM.price) { _, _ in formVM.validateField(.price) }
        .onAppear {
            formVM.validateAll()
            if mode == .new && formVM.name.isEmpty { nameFocused = true }
        }
        .task {
            if let lastPriceText, let text = await lastPriceText() { priceSubtitle = text }
        }
    }

    private var sheetContent: some View {
        ZStack(alignment: .top) {
            KeyboardRevealScrollView(keyboardHeight: keyboardHeight, bottomInset: revealInset) {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ProductDetailHero(k: k, image: formVM.selectedImage, mode: mode,
                                          onPhoto: { showPhotoSource = true }, onEdit: startEditing)
                        Group {
                            if mode.isEditing { editContent } else { viewContent }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, mode.isEditing ? 20 : 24)
                        .padding(.bottom, mode.isEditing ? 56 + 34 + 20 : 34)
                    }
                }
                // Ziehen am Anfang des Inhalts bewegt das Sheet statt den Inhalt (kein „Pull to refresh“-Spalt).
                .background {
                    SheetPullTracker(
                        onChange: { pull = $0 },
                        onEnd: { distance, velocity in
                            if distance > 120 || velocity > 900 { onClose() }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { pull = 0 }
                        })
                }
            }
            .padding(.top, -1)          // 1-pt-Oberkante der SheetSurface überdecken: Bild beginnt ganz oben
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            topButtons
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Rahmen

    /// Griff (40 × 5, oben 9) als Zieh-Fläche und ✕ oben rechts (14 / 16) – beide über dem Bild.
    private var topButtons: some View {
        ZStack(alignment: .top) {
            // Zieh-Leiste über die ganze Breite: Herunterziehen schließt (wie HybridSheetLayer).
            Color.clear
                .frame(height: 44)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(dismissDrag)
            RR(3)
                .fill(k.grabber)
                .frame(width: 40, height: 5)
                .padding(.top, 8)                        // 9 im Design, 1 pt Oberkante liegt schon davor
                .allowsHitTesting(false)
            HStack(spacing: 0) {
                // Unsichtbare Überschrift für VoiceOver (und UI-Tests): Titel wie die früheren Sheets.
                Text(screenTitle)
                    .font(AppFont.dm(1, 400))
                    .foregroundStyle(.clear)
                    .frame(width: 1, height: 1)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                GlassCircleButton(style: .neutral, appearance: k.appearance, accent: k.a, icon: Icon.close,
                                  label: "Schließen", action: onClose)
            }
            .padding(.top, 13)
            .padding(.leading, 20)
            .padding(.trailing, 16)
        }
    }

    private var dismissDrag: some Gesture {
        // Global messen: die Zieh-Leiste wandert mit dem Sheet mit, lokal gemessen würde der Weg springen (Ruckeln).
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in dragOffset = max(0, value.translation.height) }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 260 { onClose() }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragOffset = 0 }
            }
    }

    /// „Speichern“ bzw. „Zur Liste hinzufügen“; beim Eintippen der Menge die Schnellwahl-Leiste.
    @ViewBuilder
    private var bottomBar: some View {
        if mode.isEditing {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if quantityEditing && keyboardHeight > 0 {
                    QuantityPresetBar(k: k, units: QuantityFormat.parse(formVM.units) ?? 1, measure: formVM.measure,
                                      onSelect: { preset in
                                          formVM.units = QuantityFormat.format(preset.units)
                                          formVM.measure = preset.measure
                                      },
                                      onDone: { quantityEditing = false })
                        .padding(.bottom, keyboardHeight)
                        .transition(.opacity)
                } else {
                    CTAButton(title: mode == .new ? "Zur Liste hinzufügen" : "Speichern", k: k,
                              isEnabled: mode == .new ? (formVM.isValid || !attemptedSubmit) : formVM.isValid,
                              action: save)
                        .padding(.horizontal, 20)
                        .padding(.bottom, bottomInset)
                        .background(alignment: .bottom) { fade }
                        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                }
            }
            .ignoresSafeArea(.keyboard)
        }
    }

    /// Verlauf hinter dem Knopf (120 hoch), damit Text beim Scrollen nicht hart abgeschnitten wirkt.
    private var fade: some View {
        let base: Color = k.isDark ? .hex("#0A1416") : .white     // Sheet-Farbe unten
        return LinearGradient(stops: [.init(color: base.opacity(0), location: 0), .init(color: base.opacity(0.96), location: 0.45)],
                              startPoint: .top, endPoint: .bottom)
            .frame(height: 120 + max(0, bottomInset - 34))
            .allowsHitTesting(false)
    }

    // MARK: - Ansehen

    private var viewContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formVM.name.isEmpty ? "Ohne Namen" : formVM.name)
                        .font(AppFont.outfit(28, 700))
                        .tracking(-0.56)                              // -0.02em
                        .foregroundStyle(k.text)
                        .lineLimit(2)
                    if !formVM.brand.isEmpty {
                        Text(formVM.brand)
                            .font(AppFont.dm(15, 400))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(priceValue > 0 ? PriceDisplaySetting.euro(priceValue) : "–")
                        .font(AppFont.outfit(26, 700))
                        .foregroundStyle(k.accentText)
                    Text(priceCaption)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                }
                .fixedSize()
            }

            cardGrid.padding(.top, 20)

            divider.padding(.top, 18)
            Text("Beschreibung")
                .font(AppFont.outfit(18, 600))
                .foregroundStyle(k.text)
                .padding(.top, 14)
            Text(formVM.productDescription.isEmpty ? "Keine Beschreibung" : formVM.productDescription)
                .font(AppFont.dm(15, 400))
                .lineSpacing(4)                                        // line-height 1.5
                .foregroundStyle(k.sub)
                .padding(.top, 6)
        }
    }

    // MARK: - Bearbeiten / Neu

    private var editContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("", text: $formVM.name, prompt: Text("Name").foregroundStyle(k.sub.opacity(0.75)))
                        .font(AppFont.outfit(28, 700))
                        .tracking(-0.56)
                        .foregroundStyle(k.text)
                        .tint(k.accent)
                        .focused($nameFocused)
                        .submitLabel(.next)
                        .onSubmit { brandFocused = true }
                        .padding(.horizontal, 11)
                        .frame(height: 44)
                        .background(inlineField(focused: nameFocused, error: visibleNameError != nil))
                        .padding(.leading, -11)
                        .revealsWhenFocused(nameFocused)
                        .accessibilityLabel("Name")
                    TextField("", text: $formVM.brand, prompt: Text("Marke").foregroundStyle(k.sub.opacity(0.75)))
                        .font(AppFont.dm(15, 400))
                        .foregroundStyle(k.sub)
                        .tint(k.accent)
                        .focused($brandFocused)
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(inlineField(focused: brandFocused, error: false))
                        .padding(.leading, -11)
                        .revealsWhenFocused(brandFocused)
                        .accessibilityLabel("Marke")
                    if let error = visibleNameError {
                        Text(error)
                            .font(AppFont.dm(12, 500))
                            .foregroundStyle(Color.hex("#E5484D"))
                    }
                }
                VStack(alignment: .trailing, spacing: 4) {
                    ProductDetailPriceField(k: k, price: $formVM.price, hasError: formVM.priceError != nil)
                        .padding(.trailing, -11)
                    Text(priceCaption)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                }
                .fixedSize()
            }

            cardGrid.padding(.top, 12)

            divider.padding(.top, 16)
            Text("Beschreibung")
                .font(AppFont.outfit(18, 600))
                .foregroundStyle(k.text)
                .padding(.top, 12)
            TextField("", text: $formVM.productDescription,
                      prompt: Text("Beschreibung").foregroundStyle(k.sub.opacity(0.75)), axis: .vertical)
                .lineLimit(2...5)
                .font(AppFont.dm(15, 400))
                .lineSpacing(4)
                .foregroundStyle(k.text)
                .tint(k.accent)
                .focused($descriptionFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(minHeight: 70, alignment: .topLeading)
                .background(inlineField(focused: descriptionFocused, error: false))
                .padding(.horizontal, -12)
                .padding(.top, 6)
                .revealsWhenFocused(descriptionFocused)
                .accessibilityLabel("Beschreibung")
        }
    }

    /// Eingabefeld-Fläche, Radius 12: Ruhe field + Rand 1; fokussiert helle Fläche, Rand 1,5 ring, Ring 4.
    private func inlineField(focused: Bool, error: Bool) -> some View {
        CSSBox(shape: RR(12), paint: .color(focused ? k.fieldFocus : k.field), border: focused ? 1.5 : 1,
               borderColor: error ? .hex("#E5484D") : (focused ? k.ring : k.fieldBorder),
               shadows: focused ? [.drop(0, 0, 0, 4, k.ringSoft)] : [])
    }

    // MARK: - Karten

    /// Kategorie · Maßeinheit, darunter Menge · Preisverlauf (Abstand 10).
    private var cardGrid: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                categoryCard
                unitCard
            }
            if showsQuantity || hasPriceHistory {
                HStack(alignment: .top, spacing: 10) {
                    if showsQuantity { quantityCard } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                    if hasPriceHistory { priceHistoryCard } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
        }
    }

    private var hasPriceHistory: Bool { onPriceHistory != nil && mode != .new }

    @ViewBuilder
    private var categoryCard: some View {
        let selected = listViewModel.categoryOrder.first { $0.name == formVM.category }
        let icon = selected?.svgIcon ?? ProductDetailIcon.category
        if mode.isEditing {
            Menu {
                Button("Keine Kategorie") { formVM.category = "" }
                Divider()
                ForEach(listViewModel.categoryOrder) { category in
                    Button(category.name) { formVM.category = category.name }
                }
            } label: {
                ProductDetailCard(k: k, icon: icon, label: "Kategorie", style: .field) {
                    ProductDetailCardValue(text: formVM.category.isEmpty ? "Wählen" : formVM.category,
                                           color: formVM.category.isEmpty ? k.sub : k.text,
                                           trailing: Icon.chevronDown, trailingColor: k.sub)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel("Kategorie: \(formVM.category.isEmpty ? "keine" : formVM.category)")
        } else {
            ProductDetailCard(k: k, icon: icon, label: "Kategorie") {
                ProductDetailCardValue(text: formVM.category.isEmpty ? "Keine" : formVM.category,
                                       color: formVM.category.isEmpty ? k.sub : k.text)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var unitCard: some View {
        if mode.isEditing {
            Menu {
                Button("Keine Einheit") { formVM.measure = "" }
                Divider()
                ForEach(Measure.allCases, id: \.self) { unit in
                    Button(unit.localizedName) { formVM.measure = unit.rawValue }
                }
            } label: {
                ProductDetailCard(k: k, icon: ProductDetailIcon.unit, label: "Maßeinheit", style: .field) {
                    ProductDetailCardValue(text: unitName ?? "Keine", color: unitName == nil ? k.sub : k.text,
                                           trailing: Icon.chevronDown, trailingColor: k.sub)
                }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel("Maßeinheit: \(unitName ?? "keine")")
        } else {
            ProductDetailCard(k: k, icon: ProductDetailIcon.unit, label: "Maßeinheit") {
                ProductDetailCardValue(text: unitName ?? "Keine", color: unitName == nil ? k.sub : k.text)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var quantityCard: some View {
        if mode.isEditing {
            ProductDetailCard(k: k, icon: Icon.cart, label: "Menge", style: quantityEditing ? .focused : .field) {
                SheetQuantityStepper(k: k, quantity: unitsBinding, measure: formVM.measure,
                                     isEditing: $quantityEditing, compact: true)
            }
        } else {
            ProductDetailCard(k: k, icon: Icon.cart, label: "Menge in der Liste") {
                ProductDetailCardValue(text: currentModel.quantityText, color: k.text)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var priceHistoryCard: some View {
        Button(action: { onPriceHistory?(currentModel) }) {
            ProductDetailCard(k: k, icon: ProductDetailIcon.trend, label: "Preisverlauf",
                              style: mode.isEditing ? .field : .info) {
                ProductDetailCardValue(text: priceSubtitle, color: k.accentText,
                                       trailing: Icon.chevronRight, trailingColor: k.sub)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preisverlauf anzeigen")
        .accessibilityValue(priceSubtitle)
    }

    private var divider: some View {
        Rectangle()
            .fill(k.isDark ? Color.rgba(255, 255, 255, 0.08) : Color.hex("#EDF1F2"))
            .frame(height: 1)
    }

    // MARK: - Werte

    private var screenTitle: String {
        switch mode {
        case .view: return "Produktdetails"
        case .edit: return "Artikel bearbeiten"
        case .new: return "Neuer Artikel"
        }
    }

    private var priceValue: Double { Double(formVM.price.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var unitName: String? {
        formVM.measure.isEmpty ? nil : Measure.fromExternal(formVM.measure).localizedName
    }

    /// „aktueller Preis · je kg“ (ohne Einheit nur „aktueller Preis“).
    private var priceCaption: String {
        guard let unitName, mode != .new || !formVM.measure.isEmpty else { return "aktueller Preis" }
        let short = ["g", "kg", "ml", "l", "cm", "m"].contains(formVM.measure) ? formVM.measure : unitName
        return "aktueller Preis · je \(short)"
    }

    private var unitsBinding: Binding<Double> {
        Binding(get: { QuantityFormat.parse(formVM.units) ?? 1 }, set: { formVM.units = QuantityFormat.format($0) })
    }

    /// Aktuelle Eingaben als Artikel (gleiche ID, Liste und Besitzer wie `item`).
    private var currentModel: ItemModel {
        formVM.toItemModel(existingId: item?.id, listId: item?.listId, ownerPublicId: item?.ownerPublicId)
    }

    // MARK: - Aktionen

    private func startEditing() {
        returnsToView = true
        withAnimation(.easeOut(duration: 0.2)) { mode = .edit }
        nameFocused = true
    }

    private func save() {
        attemptedSubmit = true
        formVM.validateAll()
        guard formVM.isValid else { return }
        guard let item else {
            listViewModel.addItem(formVM.toItemModel(), barcode: barcode)
            onClose()
            return
        }
        let updated = currentModel
        logVoid(params: (action: "productDetail.save", itemId: item.id, formPrice: formVM.price,
                         oldPrice: item.price, newPrice: updated.price))
        if updated.price > 0, abs(updated.price - item.price) > 0.0001 { onPriceChanged?(updated) }
        if let onSave {
            onSave(updated)
        } else {
            listViewModel.updateItem(updated)
        }
        if returnsToView {
            nameFocused = false
            brandFocused = false
            descriptionFocused = false
            quantityEditing = false
            withAnimation(.easeOut(duration: 0.2)) { mode = .view }
        } else {
            onClose()
        }
    }
}

#Preview("Ansehen") {
    ProductDetailSheet(item: ItemModel(name: "Orangen", units: 1, measure: "kg", price: 2.99, category: "Obst & Gemüse",
                                       productDescription: "Saftige Tafelorangen aus Spanien.", brand: "Hofgut Sonnental"),
                       startInEdit: false, k: SheetTheme(.light), keyboardHeight: 0, onClose: {},
                       onPriceHistory: { _ in })
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}

#Preview("Bearbeiten Dark") {
    ProductDetailSheet(item: ItemModel(name: "Orangen", units: 1, measure: "kg", price: 2.99, category: "Obst & Gemüse",
                                       productDescription: "Saftige Tafelorangen aus Spanien.", brand: "Hofgut Sonnental"),
                       startInEdit: true, k: SheetTheme(.dark), keyboardHeight: 0, onClose: {},
                       onPriceHistory: { _ in })
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}

#Preview("Neu") {
    ProductDetailSheet(newItemName: "", k: SheetTheme(.light), keyboardHeight: 0, onClose: {})
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}

// MARK: - Herunterziehen über den Inhalt

/// Hängt sich an den Pan-Gesture-Recognizer der umgebenden UIScrollView. Steht der Inhalt ganz oben und
/// zieht der Finger nach unten, bleibt der Inhalt stehen (kein Überziehen) und der Weg geht an `onChange`
/// – das Sheet wandert 1:1 mit. Beim Loslassen meldet `onEnd` Weg und Geschwindigkeit (pt/s).
/// Die ScrollView federt nicht mehr nach: passt der Inhalt ganz hinein, bewegt er sich gar nicht.
private struct SheetPullTracker: UIViewRepresentable {
    let onChange: (CGFloat) -> Void
    let onEnd: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: TrackerView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.onEnd = onEnd
    }

    static func dismantleUIView(_ uiView: TrackerView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class TrackerView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.attachToScrollView() }
        }

        private func attachToScrollView() {
            var view = superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            if let scrollView = view as? UIScrollView { coordinator?.attach(to: scrollView) }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (CGFloat) -> Void = { _ in }
        var onEnd: (CGFloat, CGFloat) -> Void = { _, _ in }
        private weak var scrollView: UIScrollView?
        private var pulling = false
        private var startY: CGFloat = 0

        func attach(to scrollView: UIScrollView) {
            guard self.scrollView !== scrollView else { return }
            detach()
            self.scrollView = scrollView
            scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))
            lockBounce(scrollView)
        }

        /// Kein Überziehen – weder oben (Sheet wandert stattdessen) noch unten (Bild ließ sich hochschieben).
        /// `alwaysBounceVertical` bleibt an, damit die Pan-Geste auch bei kurzem Inhalt meldet.
        private func lockBounce(_ scrollView: UIScrollView) {
            scrollView.bounces = false
            scrollView.alwaysBounceVertical = true
        }

        func detach() {
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePan(_:)))
            scrollView = nil
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView else { return }
            let top = -scrollView.adjustedContentInset.top
            // Fensterkoordinaten: die ScrollView wandert mit dem Sheet mit, lokal gemessen würde es ruckeln.
            let y = gesture.translation(in: nil).y
            switch gesture.state {
            case .began:
                pulling = false
                lockBounce(scrollView)                // SwiftUI könnte die Werte beim Aktualisieren zurücksetzen
            case .changed:
                if !pulling, scrollView.contentOffset.y <= top + 0.5, gesture.velocity(in: nil).y > 0 {
                    pulling = true
                    startY = y
                }
                guard pulling else { return }
                let distance = y - startY
                if distance < 0 {                    // wieder nach oben: normal weiterscrollen
                    pulling = false
                    onChange(0)
                    return
                }
                scrollView.contentOffset.y = top     // Inhalt bleibt oben stehen
                onChange(distance)
            case .ended, .cancelled, .failed:
                if pulling { onEnd(max(0, y - startY), gesture.velocity(in: nil).y) }
                pulling = false
            default:
                break
            }
        }
    }
}
