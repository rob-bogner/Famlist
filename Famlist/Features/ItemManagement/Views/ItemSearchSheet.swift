/*
 ItemSearchSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet „Artikel suchen“ (Höhe 790). Ersetzt ItemSearchView.
   • unter 2 Zeichen: Leerzustand + „Neuen Artikel anlegen“ 14 pt über der Tastatur
   • ab 2 Zeichen:    „n Treffer“ + Ergebnis-Karten + Fußleiste „Neu anlegen: „…““

 🔰 Notes for Beginners:
 - ItemSearchViewModel sucht wie bisher im persönlichen und im globalen Katalog (300 ms Entprellung).
 - Plus auf einer Karte legt den Artikel über ListViewModel.addItem an und schließt das Sheet.
 - „Neu anlegen“ ruft onCreateNew; ShoppingListView tauscht dann dieses Sheet gegen „Neuer Artikel“.

 📝 Last Change:
 - Initial creation (aus SearchScreen des Design-Pakets MyListUI).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid search sheet over personal + global catalog.
struct ItemSearchSheet: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @StateObject private var searchVM: ItemSearchViewModel
    @FocusState private var isFieldFocused: Bool

    let k: SheetTheme
    let maxHeight: CGFloat
    let keyboardHeight: CGFloat
    let onClose: () -> Void
    let onCreateNew: (String) -> Void

    init(catalogRepository: any ItemCatalogRepository,
         globalCatalogRepository: (any GlobalProductCatalogRepository)?,
         k: SheetTheme, maxHeight: CGFloat, keyboardHeight: CGFloat,
         onClose: @escaping () -> Void, onCreateNew: @escaping (String) -> Void) {
        _searchVM = StateObject(wrappedValue: ItemSearchViewModel(catalogRepository: catalogRepository,
                                                                  globalCatalogRepository: globalCatalogRepository))
        self.k = k
        self.maxHeight = maxHeight
        self.keyboardHeight = keyboardHeight
        self.onClose = onClose
        self.onCreateNew = onCreateNew
    }

    private var query: String { searchVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var showsResults: Bool { query.count >= 2 }
    /// Abstand des Buttons zur Unterkante: 14 über der Tastatur, sonst 34.
    private var bottomInset: CGFloat { keyboardHeight > 0 ? keyboardHeight + 14 : 34 }

    var body: some View {
        HybridSheetLayer(k: k, title: "Artikel suchen", designHeight: 790, maxHeight: maxHeight, onClose: onClose) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    FocusedSearchField(k: k, text: $searchVM.searchText, placeholder: "Artikel suchen …",
                                       focus: $isFieldFocused)
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                    if showsResults { results } else { emptyState }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                footer
            }
        }
        .onChange(of: searchVM.searchText) { _, _ in searchVM.onSearchTextChanged() }
        .task {
            try? await Task.sleep(nanoseconds: 350_000_000) // nach der Einblend-Animation fokussieren
            isFieldFocused = true
        }
    }

    // MARK: - Empty State

    /// Leerzustand: Bereich ab y 150 im Sheet (9 pt unter dem Suchfeld), Höhe 255, Inhalt zentriert.
    private var emptyState: some View {
        VStack(spacing: 14) {
            SearchEmptyIcon(k: k)
            Text("Suche nach einem Artikel oder lege einen neuen an.")
                .font(AppFont.dm(15, 500))
                .foregroundStyle(k.sub)
                .multilineTextAlignment(.center)
                .cssLineHeight(21, font: AppFont.ui(.dmSans, 15, 500))          // line-height 1.4
                .frame(maxWidth: 240)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 255)
        .padding(.top, 9)
    }

    // MARK: - Results

    private var results: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(searchVM.results.count) Treffer")
                    .font(AppFont.dm(13, 600))
                    .tracking(0.52)                       // 0.04em × 13
                    .textCase(.uppercase)
                    .foregroundStyle(k.sub)
                    .padding(.horizontal, 4)
                if searchVM.isSearching {
                    ProgressView()
                        .tint(k.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else if searchVM.results.isEmpty {
                    Text(searchVM.errorMessage ?? "Kein passender Artikel. Lege ihn unten neu an.")
                        .font(AppFont.dm(15, 500))
                        .foregroundStyle(searchVM.errorMessage == nil ? k.sub : .hex("#E5484D"))
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                }
                ForEach(searchVM.results) { result in
                    SearchResultCard(k: k, result: result) { add(result) }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .padding(.bottom, 108 + bottomInset)   // Platz unter der Fußleiste
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Footer

    private var footer: some View {
        let title = showsResults ? "Neu anlegen: „\(query)“" : "Neuen Artikel anlegen"
        let stops: [Gradient.Stop] = k.isDark
            ? [stop(.rgba(10, 20, 22, 0), 0), stop(.hex("#0A1416"), 0.3)]
            : [stop(.rgba(255, 255, 255, 0), 0), stop(.white, 0.3)]
        return CTAButton(title: title, k: k) { onCreateNew(showsResults ? query : "") }
            .padding(.top, 18)
            .padding(.horizontal, 20)
            .padding(.bottom, bottomInset)
            .background(showsResults ? LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom) : nil)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }

    // MARK: - Actions

    private func add(_ result: SearchResult) {
        guard let ownerPublicId = listViewModel.defaultList?.ownerId.uuidString else {
            logVoid(params: (action: "searchSheet.add.skipped", reason: "defaultList.ownerId is nil"))
            return
        }
        let item = result.entry.toItemModel(listId: listViewModel.listId.uuidString, ownerPublicId: ownerPublicId)
        listViewModel.addItem(item)
        onClose()
    }
}

/// Icon-Kachel des Leerzustands: 72 × 72, Radius 24, Lupe 30, Lichtfleck oben links.
private struct SearchEmptyIcon: View {
    let k: SheetTheme

    var body: some View {
        let dark = k.isDark
        SVGIcon(Icon.search, size: 30, color: dark ? k.a.light.color() : .hex("#7D9498"), lineWidth: 1.8)
            .frame(width: 72, height: 72)
            .background(alignment: .topLeading) {
                // left -20, top -30, 90×70
                CSSRadialGradient(center: .center, extent: .ellipseClosestSide,
                                  stops: [stop(.rgba(255, 255, 255, 0.5), 0), stop(.rgba(255, 255, 255, 0), 1)])
                    .frame(width: 90, height: 70)
                    .offset(x: -20, y: -30)
            }
            .clipShape(RR(24))
            .background(CSSBox(shape: RR(24),
                               paint: dark
                                   ? .linear(150, [stop(k.a.base.color(0.24), 0), stop(k.a.base.color(0.06), 1)])
                                   : .linear(150, [stop(.hex("#F4F8F8"), 0), stop(.hex("#E2ECED"), 1)]),
                               shadows: dark
                                   ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.14))]
                                   : [.inner(0, 1, 0, 0, .white), .drop(0, 12, 24, -14, .rgba(12, 40, 44, 0.35))]))
            .accessibilityHidden(true)
    }
}

#Preview("Leer") {
    ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        ItemSearchSheet(catalogRepository: PreviewItemCatalogRepository(), globalCatalogRepository: nil,
                        k: SheetTheme(.light), maxHeight: 790, keyboardHeight: 0, onClose: {}, onCreateNew: { _ in })
    }
    .ignoresSafeArea()
    .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
