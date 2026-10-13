/*
 BarcodeScanSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild „Barcode scannen“: Kamera (VisionKit) mit Design-UI darüber – Glas-Knöpfe, Titel-Pille,
   Scan-Rahmen, Hinweis und Karte „Artikel erkannt“ (Bild · Details · Menge · Zur Liste hinzufügen · Weiter scannen).

 🔰 Notes for Beginners:
 - Vorlage: BarcodeScanScreen in design-handoff/MyListUI/Screens/ItemExtraScreens.swift
   (BarcodeScan.dc.html, nur dunkel). Werte 1:1; die Kameravorschau ersetzt den Platzhalter „Kamerabild“.
 - Ohne Kamera (Simulator) bleibt der dunkle Verlauf des Designs sichtbar, mit Hinweis.
 - Die Karte erscheint erst, wenn ein Code einen Artikel trifft. Unbekannte Codes → `onUnknown`.

 📝 Last Change:
 - Mengen-Kreis gedrückt halten rollt 2× … 6× aus (ScanQuantityRoll); Karte zeigt Artikelbild, Marke, Details
   (Wunsch Robert 14.10.2026).
 - „Zur Liste hinzufügen“ schließt den Scanner (11.10.2026, vorher lief die Kamera weiter).
 - Initial creation (Redesign „Hybrid“, Phase 3).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct BarcodeScanSheet: View {
    @StateObject private var vm: BarcodeScanViewModel
    let appearance: Appearance
    var onClose: () -> Void = {}
    var onAdd: (ScannedProduct, Int) -> Void = { _, _ in }
    var onUnknown: (String) -> Void = { _ in }
    /// Nur Vorschau/Design-Abgleich: feste Karte ohne Kamera.
    var previewProduct: ScannedProduct?
    /// Mengen eingerastet ausgerollt → Tipp-Fläche hinter der Karte schließt.
    @State private var quantityRollOpen = false

    init(viewModel: BarcodeScanViewModel, appearance: Appearance, previewProduct: ScannedProduct? = nil,
         onClose: @escaping () -> Void = {}, onAdd: @escaping (ScannedProduct, Int) -> Void = { _, _ in },
         onUnknown: @escaping (String) -> Void = { _ in }) {
        _vm = StateObject(wrappedValue: viewModel)
        self.appearance = appearance
        self.previewProduct = previewProduct
        self.onClose = onClose
        self.onAdd = onAdd
        self.onUnknown = onUnknown
    }

    private var product: ScannedProduct? {
        if case .found(let p) = vm.state { return p }
        return previewProduct
    }

    var body: some View {
        let k = SheetTheme(appearance)
        let t = ItemExtraTokens(appearance)
        let camera = BarcodeCameraView.isAvailable && previewProduct == nil

        ZStack(alignment: .top) {
            // Kamera-Hintergrund (Design-Verlauf; die Kamera liegt darüber, wenn vorhanden)
            CSSRadialGradient(center: UnitPoint(x: 0.5, y: 0.4), extent: .ellipse(rx: 0.9, ry: 0.6),
                              stops: [stop(.hex("#2B3A3C"), 0), stop(.hex("#121A1B"), 0.7), stop(.hex("#0A0F10"), 1)])
            if camera {
                BarcodeCameraView(isPaused: vm.isPaused, torchOn: vm.torchOn) { code in
                    Task {
                        if let unknown = await vm.handle(code: code) { onUnknown(unknown) }
                    }
                }
                .accessibilityHidden(true)
            }

            // Top-Bar
            HStack(spacing: 0) {
                glassButton(Icon.close, lineWidth: 2.2, label: "Schließen", action: onClose)
                Spacer(minLength: 0)
                Text("Barcode scannen")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(RR(18).fill(Color.rgba(0, 0, 0, 0.35)))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                glassButton(ItemExtraIcon.bolt, lineWidth: 2, label: vm.torchOn ? "Licht aus" : "Licht an") {
                    vm.torchOn.toggle()
                }
                .opacity(camera ? 1 : 0.4)
                .allowsHitTesting(camera)
            }
            .padding(.top, 62)
            .padding(.horizontal, 20)

            if !camera && previewProduct == nil {
                Text("Kamera nicht verfügbar")
                    .font(AppFont.dm(12, 400))
                    .tracking(0.96)                                  // 0.08em × 12
                    .textCase(.uppercase)
                    .foregroundStyle(Color.rgba(255, 255, 255, 0.25))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 330)
            }

            BarcodeScanFrame(accent: k.accent)
                .frame(width: 280, height: 180)
                .padding(.top, 220)
                .accessibilityHidden(true)

            Text(hint)
                .font(AppFont.dm(15, 500))
                .foregroundStyle(Color.rgba(255, 255, 255, 0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 420)
                // Auf kleinen Geräten (SE) liegt die Ergebniskarte über dem Hinweis und das Glas lässt ihn durchscheinen.
                .opacity(product == nil ? 1 : 0)

            if quantityRollOpen {
                // Daneben tippen schließt die ausgerollten Mengen (wie die Abdunkelung unter dem Dock).
                Color.black.opacity(0.001)
                    .onTapGesture { quantityRollOpen = false }
                    .accessibilityHidden(true)
            }

            if let product {
                resultCard(product, k: k, t: t)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: vm.state)
        .onChange(of: vm.state) { _, _ in quantityRollOpen = false }
        .onDisappear { BarcodeCameraView.setTorch(false) }
    }

    private var hint: String {
        if case .lookingUp = vm.state { return "Artikel wird gesucht …" }
        return "Barcode in den Rahmen halten"
    }

    /// Glas-Knopf 48, neutral dunkel (Kamera, Canvas-Token gnd), Icon 20 weiß.
    private func glassButton(_ icon: [SVGElement], lineWidth: CGFloat, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SVGIcon(icon, size: 20, color: .white, lineWidth: lineWidth)
                .frame(width: 48, height: 48)
                .background(GlassCircleBackground(style: .neutralDark, appearance: .dark, accent: AccentScale(Appearance.dark.defaultAccent, .dark), size: 48))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Karte „Artikel erkannt“: Innenabstand 16 + Rahmen 1, Radius 30, kein Schatten.
    private func resultCard(_ product: ScannedProduct, k: SheetTheme, t: ItemExtraTokens) -> some View {
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SVGIcon(Icon.check, size: 16, color: t.ok, lineWidth: 2.6)
                Text("Artikel erkannt")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.ok)
            }

            productHeader(product, k: k, t: t)

            // Menge: Tippen zählt weiter, gedrückt halten rollt 2× … 6× über den Knopf aus (wie Plus im Dock).
            ScanQuantityControl(k: k, quantity: vm.quantity, isOpen: $quantityRollOpen,
                                onCycle: vm.cycleQuantity, onPick: vm.setQuantity) {
                // Kein vm.resume(): Die Kamera bliebe sonst beim Schließen aktiv und läse denselben Code erneut.
                CTAButton(title: "Zur Liste hinzufügen", k: k) {
                    onAdd(product, vm.quantity)
                    onClose()
                }
            }

            // „Weiter scannen“: neutrale Glas-Pille 52 (29.09.2026, vorher Textknopf)
            Button(action: vm.resume) {
                Text("Weiter scannen")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 52))
                    .contentShape(Pill)
            }
            .buttonStyle(.plain)
        }
        .padding(17)                                                   // 1 border + 16 padding
        .background(CSSBox(shape: RR(30), paint: .color(t.menu), border: 1, borderColor: t.menuBorder))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Erkannter Artikel")
    }

    /// Bild (eigenes Foto, sonst Katalog-Bild, sonst Wagen-Symbol) · Name · Marke · Detail-Chips · Beschreibung.
    private func productHeader(_ product: ScannedProduct, k: SheetTheme, t: ItemExtraTokens) -> some View {
        let nameFont = AppFont.ui(.outfit, 17, 600)
        let chips = product.detailChips()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                productImage(product, k: k, t: t)
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.entry.name)
                        .font(AppFont.outfit(17, 600))
                        .foregroundStyle(k.text)
                        .cssLineHeight(21.25, font: nameFont)             // line-height 1.25
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let brand = product.brand {
                        Text(brand)
                            .font(AppFont.dm(13, 500))
                            .foregroundStyle(k.sub)
                            .lineLimit(1)
                    }
                    if !chips.isEmpty {
                        // Passt nicht alles in eine Zeile, fallen hintere Chips weg (Preis zuerst).
                        ViewThatFits(in: .horizontal) {
                            chipRow(chips, k: k)
                            chipRow(Array(chips.prefix(2)), k: k)
                            chipRow(Array(chips.prefix(1)), k: k)
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let details = product.details {
                Text(details)
                    .font(AppFont.dm(13, 400))
                    .foregroundStyle(k.sub)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func chipRow(_ chips: [String], k: SheetTheme) -> some View {
        HStack(spacing: 6) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(AppFont.dm(12, 600))
                    .foregroundStyle(k.accentText)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(k.a.base.color(k.appearance == .dark ? 0.18 : 0.1)))
            }
        }
    }

    /// Artikelbild 84 × 84, Radius 20, randlos gefüllt; ohne Bild das Wagen-Symbol auf der Kachel wie bisher.
    private func productImage(_ product: ScannedProduct, k: SheetTheme, t: ItemExtraTokens) -> some View {
        let placeholder = SVGIcon(ItemExtraIcon.cartArcs, size: 26, color: k.accentText, lineWidth: 1.8)
        return ZStack {
            CSSBox(shape: RR(20), paint: t.tile)
            if let image = ImageCache.shared.image(fromBase64: product.entry.imageData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if let url = product.remoteImageURL {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if case .success(let image) = phase {
                        // Katalog-Bilder sind freigestellte Packungen: auf weiß, ganz sichtbar.
                        image.resizable().scaledToFit().padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.white)
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RR(20))
        .overlay(RR(20).strokeBorder(Color.rgba(255, 255, 255, k.appearance == .dark ? 0.1 : 0), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

extension ScannedProduct {
    /// Beispiel aus BarcodeScan.dc.html.
    static let designSample = ScannedProduct(
        barcode: "5011038133330",
        entry: ItemCatalogEntry(id: "sample", ownerPublicId: "", name: "Kerrygold, original irische Butter",
                                brand: "Kerrygold", category: "Milchprodukte",
                                productDescription: "Aus der Milch irischer Weidekühe, mild gesalzen.", measure: "250 g",
                                price: 0, imageData: nil),
        meta: "Kerrygold · 250 g")
}

#Preview("Barcode-Scanner", traits: .fixedLayout(width: 390, height: 844)) {
    BarcodeScanSheet(viewModel: BarcodeScanViewModel(catalog: nil, global: nil), appearance: .light,
                     previewProduct: .designSample)
}

#Preview("Barcode-Scanner – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    BarcodeScanSheet(viewModel: BarcodeScanViewModel(catalog: nil, global: nil), appearance: .dark,
                     previewProduct: .designSample)
}
