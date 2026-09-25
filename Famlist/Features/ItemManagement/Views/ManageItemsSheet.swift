/*
 ManageItemsSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Artikel verwalten“ (Höhe 790): alle gespeicherten Artikel mit Suche und Kategorie-Filterchips.
   Tippen auf den Pfeil → Artikel bearbeiten, Wischen → löschen, langer Druck → „Preisverlauf“ (SPEC §5).

 🔰 Notes for Beginners:
 - Vorlage: ManageItemsScreen in design-handoff/MyListUI/Screens/ItemExtraScreens.swift
   (ManageItems.dc.html). Werte 1:1, nur Beispieldaten und Callbacks ersetzt.
 - Kopf: Titelzeile → 16 → Suchfeld 50 → 12 → Chips 36 (Reihe ab x 30) → 18 → „n Artikel“ → 10 → Karten 74.

 📝 Last Change:
 - Karte ist kein Button mehr: nur der Pfeil öffnet das Bearbeiten, Wischen greift überall zuverlässig.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ManageItemsSheet: View {
    @StateObject private var vm: ManageItemsViewModel
    let appearance: Appearance
    var onClose: () -> Void = {}
    var onEdit: (ItemCatalogEntry) -> Void = { _ in }
    /// Übergangslösung SPEC §5: Kontextmenü „Preisverlauf“. nil = kein Eintrag.
    var onPriceHistory: ((ItemCatalogEntry) -> Void)?

    init(viewModel: ManageItemsViewModel, appearance: Appearance, onClose: @escaping () -> Void = {},
         onEdit: @escaping (ItemCatalogEntry) -> Void = { _ in },
         onPriceHistory: ((ItemCatalogEntry) -> Void)? = nil) {
        _vm = StateObject(wrappedValue: viewModel)
        self.appearance = appearance
        self.onClose = onClose
        self.onEdit = onEdit
        self.onPriceHistory = onPriceHistory
    }

    var body: some View {
        let k = SheetTheme(appearance)
        let t = ItemExtraTokens(appearance)

        SheetScreen(appearance: appearance, accentHex: nil) {
            SheetSurface(k: k, height: 790) {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            SheetHeader(title: "Artikel verwalten", k: k, onClose: onClose)
                            searchField(k)
                                .padding(.top, 16)
                        }
                        .padding(.top, 10)
                        .padding(.horizontal, 20)

                        // Filter-Reihe: width 100 % + margin-right −20 in zentrierter Flex-Spalte
                        // → Randbox 330 zentriert → Reihe beginnt 10 pt weiter rechts (x 30). Hier scrollbar.
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(vm.filters, id: \.self) { f in
                                    filterChip(f, on: f == vm.selectedFilter, k: k, t: t)
                                }
                            }
                            .padding(.leading, 30)
                            .padding(.trailing, 20)
                        }
                        .scrollIndicators(.hidden)
                        .frame(height: 36)
                        .padding(.top, 12)

                        ScrollView {
                            VStack(spacing: 10) {
                                header(k)
                                ForEach(vm.visibleEntries) { entry in
                                    SwipeToDeleteRow(labelColor: k.sub, onDelete: { vm.delete(entry) }) {
                                        itemCard(entry, k: k, t: t)
                                    }
                                }
                            }
                            .padding(.top, 18)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 120)   // Platz unter dem Verlauf
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                    }

                    // Verlauf unten: 120 hoch, transparent → Sheet-Farbe bei 85 %
                    LinearGradient(stops: t.fade, startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .task { await vm.load() }
    }

    private func header(_ k: SheetTheme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(vm.isLoading && vm.entries.isEmpty ? "Wird geladen …" : "\(vm.visibleEntries.count) Artikel")
                .font(AppFont.dm(13, 600))
                .tracking(0.52)                       // 0.04em × 13
                .textCase(.uppercase)
                .foregroundStyle(k.sub)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(vm.errorMessage ?? "Tippen = bearbeiten · wischen = löschen")
                .font(AppFont.dm(12, 400))
                .foregroundStyle(vm.errorMessage == nil ? k.sub : .hex("#E5484D"))
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
    }

    /// Suchfeld: Höhe 50, Pille, Rahmen 1, Innenabstand 16, Lupe 20 (sub), Text 15/400 in sub.
    private func searchField(_ k: SheetTheme) -> some View {
        HStack(spacing: 12) {
            SVGIcon(Icon.search, size: 20, color: k.sub, lineWidth: 2)
            // input::placeholder { color: inherit; opacity: 1 } → Platzhalter in sub
            TextField("", text: $vm.query, prompt: Text("Gespeicherte Artikel durchsuchen").foregroundStyle(k.sub))
                .font(AppFont.dm(15, 400))
                .foregroundStyle(k.sub)
                .tint(k.accent)
                .submitLabel(.search)
                .accessibilityLabel("Gespeicherte Artikel durchsuchen")
        }
        .padding(.horizontal, 17)                                   // 1 border + 16 padding
        .frame(height: 50)
        .background(CSSBox(shape: Pill, paint: .color(k.field), border: 1, borderColor: k.fieldBorder))
    }

    /// Filter-Chip: Höhe 36 (border-box), Innenabstand 14, Rahmen 1, Text 14 (aktiv 600, sonst 500).
    private func filterChip(_ label: String, on: Bool, k: SheetTheme, t: ItemExtraTokens) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { vm.selectedFilter = label } }) {
            Text(label)
                .font(AppFont.dm(14, on ? 600 : 500))
                .foregroundStyle(on ? t.chipOnText : k.text)
                .lineLimit(1)
                .padding(.horizontal, 15)                           // 1 border + 14 padding
                .frame(height: 36)
                .background(CSSBox(shape: Pill, paint: on ? t.chipOnBg : .color(t.chipOffBg),
                                   border: on ? 0 : 1, borderColor: k.fieldBorder))
                .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Artikel-Karte: Innenabstand 10 / 12 / 10 / 10 + Rahmen 1, Radius 22, Bild 52, Chevron 18 (schrumpfbar).
    @ViewBuilder
    private func itemCard(_ entry: ItemCatalogEntry, k: SheetTheme, t: ItemExtraTokens) -> some View {
        let meta = ManageItemsViewModel.meta(for: entry, categories: vm.categories)
        let card = HStack(spacing: 14) {
            thumbnail(entry, t: t)
            ManageItemsShrinkRow(gap: 14, trailingBasis: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(AppFont.outfit(16, 600))
                        .foregroundStyle(k.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(meta)
                        .font(AppFont.dm(13, 400))
                        .foregroundStyle(k.sub)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                // SVG ohne flex-shrink: 0 → schrumpft mit (preserveAspectRatio meet, zentriert)
                GeometryReader { g in
                    SVGIcon(Icon.chevronRight, size: min(g.size.width, g.size.height), color: k.sub, lineWidth: 2.2)
                        .frame(width: g.size.width, height: g.size.height)
                }
                .frame(height: 18)
            }
        }
        .padding(.leading, 11)                                      // 1 border + 10 padding
        .padding(.trailing, 13)                                     // 1 border + 12 padding
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CSSBox(shape: RR(22), paint: t.card, border: 1, borderColor: t.cardBorder, shadows: t.cardShadow))
        .contentShape(RR(22))
        // Nur der Pfeil öffnet das Bearbeiten (Tippfläche 56 × Kartenhöhe). Kein Button: Er würde die
        // Berührung festhalten und das Wischen zum Löschen blockieren (siehe View+SwipeFriendlyTap).
        .overlay(alignment: .trailing) {
            Color.clear
                .frame(width: 56)
                .contentShape(Rectangle())
                .swipeFriendlyTap("\(entry.name) bearbeiten") { onEdit(entry) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.name), \(meta)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Bearbeiten")
        .accessibilityAction { onEdit(entry) }

        if let onPriceHistory {
            card.contextMenu {
                Button { onPriceHistory(entry) } label: { Text("Preisverlauf") }
            }
        } else {
            card
        }
    }

    /// Bild 52 × 52, Radius 16: eigenes Foto oder Platzhalter-Kamera.
    @ViewBuilder
    private func thumbnail(_ entry: ItemCatalogEntry, t: ItemExtraTokens) -> some View {
        if let image = ImageCache.shared.image(fromBase64: entry.imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RR(16))
        } else {
            SVGIcon(Icon.cameraOff, size: 22, color: t.thumbIcon, lineWidth: 1.7)
                .frame(width: 52, height: 52)
                .background(CSSBox(shape: RR(16), paint: t.thumb, shadows: t.thumbShadow))
        }
    }
}

#Preview("Artikel verwalten", traits: .fixedLayout(width: 390, height: 844)) {
    ManageItemsSheet(viewModel: ManageItemsViewModel(repository: PreviewItemCatalogRepository()), appearance: .light)
}

#Preview("Artikel verwalten – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    ManageItemsSheet(viewModel: ManageItemsViewModel(repository: PreviewItemCatalogRepository()), appearance: .dark)
}
