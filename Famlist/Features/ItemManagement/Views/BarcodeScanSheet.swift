/*
 BarcodeScanSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Vollbild „Barcode scannen“: Kamera (VisionKit) mit Design-UI darüber – Glas-Knöpfe, Titel-Pille,
   Scan-Rahmen, Hinweis und Karte „Artikel erkannt“ (Menge · Zur Liste hinzufügen · Weiter scannen).

 🔰 Notes for Beginners:
 - Vorlage: BarcodeScanScreen in design-handoff/MyListUI/Screens/ItemExtraScreens.swift
   (BarcodeScan.dc.html, nur dunkel). Werte 1:1; die Kameravorschau ersetzt den Platzhalter „Kamerabild“.
 - Ohne Kamera (Simulator) bleibt der dunkle Verlauf des Designs sichtbar, mit Hinweis.
 - Die Karte erscheint erst, wenn ein Code einen Artikel trifft. Unbekannte Codes → `onUnknown`.

 📝 Last Change:
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
        .onDisappear { BarcodeCameraView.setTorch(false) }
    }

    private var hint: String {
        if case .lookingUp = vm.state { return "Artikel wird gesucht …" }
        return "Barcode in den Rahmen halten"
    }

    /// Glas-Knopf 48 (border-box): Rahmen 1 rgba(255,255,255,.28), Fläche rgba(255,255,255,.14), Icon 20 weiß.
    private func glassButton(_ icon: [SVGElement], lineWidth: CGFloat, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SVGIcon(icon, size: 20, color: .white, lineWidth: lineWidth)
                .frame(width: 48, height: 48)
                .background(CSSBox(shape: Circle(), paint: .color(.rgba(255, 255, 255, 0.14)),
                                   border: 1, borderColor: .rgba(255, 255, 255, 0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Karte „Artikel erkannt“: Innenabstand 16 + Rahmen 1, Radius 30, kein Schatten.
    private func resultCard(_ product: ScannedProduct, k: SheetTheme, t: ItemExtraTokens) -> some View {
        let nameFont = AppFont.ui(.outfit, 17, 600)
        let quantityText = "\(vm.quantity)×"
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                SVGIcon(Icon.check, size: 16, color: t.ok, lineWidth: 2.6)
                Text("Artikel erkannt")
                    .font(AppFont.dm(13, 600))
                    .foregroundStyle(t.ok)
            }

            HStack(spacing: 14) {
                SVGIcon(ItemExtraIcon.cartArcs, size: 24, color: k.accentText, lineWidth: 1.8)
                    .frame(width: 56, height: 56)
                    .background(CSSBox(shape: RR(16), paint: t.tile))
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.entry.name)
                        .font(AppFont.outfit(17, 600))
                        .foregroundStyle(k.text)
                        .cssLineHeight(21.25, font: nameFont)             // line-height 1.25
                        .fixedSize(horizontal: false, vertical: true)
                    if !product.meta.isEmpty {
                        Text(product.meta)
                            .font(AppFont.dm(13, 400))
                            .foregroundStyle(k.sub)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                Button(action: vm.cycleQuantity) {
                    Text(quantityText)
                        .font(AppFont.dm(13, 600))
                        .foregroundStyle(k.accentText)
                        .frame(width: 56, height: 56)
                        .background(CSSBox(shape: Circle(), paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Menge: \(quantityText)")
                .accessibilityHint("Tippen erhöht die Menge")
                CTAButton(title: "Zur Liste hinzufügen", k: k) {
                    onAdd(product, vm.quantity)
                    vm.resume()
                }
            }

            Button(action: vm.resume) {
                Text("Weiter scannen")
                    .font(AppFont.dm(14, 600))
                    .foregroundStyle(k.accentText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)                                // Trefferfläche 44 (Design 40)
                    .padding(.vertical, -2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(17)                                                   // 1 border + 16 padding
        .background(CSSBox(shape: RR(30), paint: .color(t.menu), border: 1, borderColor: t.menuBorder))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Erkannter Artikel")
    }
}

extension ScannedProduct {
    /// Beispiel aus BarcodeScan.dc.html.
    static let designSample = ScannedProduct(
        barcode: "5011038133330",
        entry: ItemCatalogEntry(id: "sample", ownerPublicId: "", name: "Kerrygold, original irische Butter",
                                brand: "Kerrygold", category: nil, productDescription: nil, measure: "250 g",
                                price: 0, imageData: nil),
        meta: "Kerrygold · 250 g")
}

#Preview("Barcode-Scanner", traits: .fixedLayout(width: 390, height: 844)) {
    BarcodeScanSheet(viewModel: BarcodeScanViewModel(catalog: nil, global: nil), appearance: .light,
                     previewProduct: .designSample)
}
