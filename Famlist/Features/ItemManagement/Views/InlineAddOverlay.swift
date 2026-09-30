/*
 InlineAddOverlay.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikel hinzufügen über das Plus im Dock (Canvas AddInline): Eingabe direkt über der Tastatur
   (Daumenbereich), Vorschläge als Pop-up darüber, ganze Liste abgedunkelt.

 🔰 Notes for Beginners:
 - Eingabezeile: 12 Rand, 8 über der Tastatur. Feld 52 (Plus 20 · Text · Glas-Knopf „Scannen“ 40),
   daneben neutraler Glas-Knopf ✕ 44.
 - Pop-up 12 über dem Feld, wächst nach oben; bester Treffer direkt über dem Feld:
   oben „„…“ als neuen Artikel anlegen“, dann „Weitere Produkte“, unten „Deine Artikel“.
 - „+“ fügt hinzu (bzw. erhöht die Menge), das Feld bleibt aktiv für den nächsten Artikel.
   Tastatur-Taste übernimmt den besten Treffer (ohne Treffer: neu anlegen).
 - Schließen: ✕ oder Tipp auf die abgedunkelte Liste. Suche/Filter der Liste ist davon getrennt (ListFilterField).

 📝 Last Change:
 - Aus InlineSearchOverlay: Eingabe unten statt oben, Glas-Knöpfe, Suche oben ist jetzt Filter.
 ------------------------------------------------------------------------
 */

import SwiftUI

struct InlineAddOverlay: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @StateObject private var searchVM: ItemSearchViewModel
    @FocusState private var focused: Bool
    @State private var popupContentHeight: CGFloat = 0
    @State private var justAdded: Set<String> = []

    let appearance: Appearance
    let keyboardHeight: CGFloat
    var initialQuery: String = ""
    var onClose: () -> Void = {}
    var onCreateNew: (String) -> Void = { _ in }
    var onScan: () -> Void = {}

    init(catalogRepository: any ItemCatalogRepository, globalCatalogRepository: (any GlobalProductCatalogRepository)?,
         appearance: Appearance, keyboardHeight: CGFloat, initialQuery: String = "",
         onClose: @escaping () -> Void = {}, onCreateNew: @escaping (String) -> Void = { _ in },
         onScan: @escaping () -> Void = {}) {
        _searchVM = StateObject(wrappedValue: ItemSearchViewModel(catalogRepository: catalogRepository,
                                                                  globalCatalogRepository: globalCatalogRepository))
        self.appearance = appearance
        self.keyboardHeight = keyboardHeight
        self.initialQuery = initialQuery
        self.onClose = onClose
        self.onCreateNew = onCreateNew
        self.onScan = onScan
    }

    private var query: String { searchVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private static let fieldHeight: CGFloat = 52

    var body: some View {
        let k = SheetTheme(appearance)
        GeometryReader { geo in
            // Ohne Tastatur (kurz beim Öffnen) über dem Home-Indikator.
            let bottom = (keyboardHeight > 0 ? keyboardHeight : 34) + 8
            let available = max(120, geo.size.height - bottom - Self.fieldHeight - 12 - 70)
            ZStack(alignment: .bottom) {
                (k.isDark ? Color.rgba(0, 0, 0, 0.55) : Color.rgba(8, 24, 27, 0.28))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)
                    .accessibilityHidden(true)

                VStack(spacing: 12) {
                    if !query.isEmpty {
                        popup(k: k, maxHeight: available)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)))
                    }
                    inputRow(k: k)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, bottom)
                .animation(.spring(response: 0.3, dampingFraction: 0.9), value: query.isEmpty)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if !initialQuery.isEmpty { searchVM.searchText = initialQuery }
            DispatchQueue.main.async { focused = true }
        }
        .onChange(of: searchVM.searchText) { _, _ in searchVM.onSearchTextChanged() }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, close)
    }

    // MARK: - Eingabezeile

    private func inputRow(k: SheetTheme) -> some View {
        HStack(spacing: 8) {
            field(k: k)
            GlassCircleButton(style: .neutral, appearance: appearance, accent: k.a, icon: Icon.close,
                              label: "Schließen", size: 44, lineWidth: 2.2, action: close)
        }
    }

    /// Feld 52, Radius 26, Rand 1,5 ring, Ring 4 ringSoft; Plus 20 Akzenttext; rechts Glas „Scannen“ 40.
    private func field(k: SheetTheme) -> some View {
        HStack(spacing: 10) {
            SVGIcon(Icon.plus, size: 20, color: k.accentText, lineWidth: 2.4)
            TextField("", text: $searchVM.searchText, prompt: Text("Artikel hinzufügen").foregroundStyle(k.sub))
                .font(AppFont.dm(16, 500))
                .foregroundStyle(k.text)
                .tint(k.a.base.color())
                .focused($focused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .onSubmit(addBestMatch)
                .accessibilityLabel("Artikel hinzufügen")
            GlassCircleButton(style: .neutral, appearance: appearance, accent: k.a, icon: Icon.scan,
                              label: "Barcode scannen", size: 40, iconColor: k.accentText, lineWidth: 2) {
                close()
                onScan()
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: Self.fieldHeight)
        .background(CSSBox(shape: RR(26), paint: .color(k.isDark ? .hex("#102124") : .white), border: 1.5,
                           borderColor: k.ring,
                           shadows: [.drop(0, 0, 0, 4, k.ringSoft), .drop(0, 8, 20, -12, k.ringGlow)]))
    }

    // MARK: - Pop-up

    private func popup(k: SheetTheme, maxHeight: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                createRow(k: k)
                Rectangle().fill(k.isDark ? Color.rgba(255, 255, 255, 0.08) : .hex("#EDF1F2"))
                    .frame(height: 1)
                    .padding(4)
                if searchVM.isSearching && searchVM.personalResults.isEmpty && searchVM.globalResults.isEmpty {
                    ProgressView().tint(k.a.base.color()).frame(maxWidth: .infinity).padding(.vertical, 14)
                } else if searchVM.personalResults.isEmpty && searchVM.globalResults.isEmpty {
                    Text(searchVM.errorMessage ?? "Kein passender Artikel.")
                        .font(AppFont.dm(14, 500))
                        .foregroundStyle(k.sub)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                } else {
                    section(title: "Weitere Produkte", results: searchVM.globalResults, k: k, topPadding: 6)
                    section(title: "Deine Artikel", results: searchVM.personalResults, k: k,
                            topPadding: searchVM.globalResults.isEmpty ? 6 : 8)
                }
            }
            .padding(8)
            .background { GeometryReader { g in Color.clear.onAppear { popupContentHeight = g.size.height }
                .onChange(of: g.size.height) { _, h in popupContentHeight = h } } }
        }
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.never)
        .frame(height: min(popupContentHeight, maxHeight))
        .background(CSSBox(shape: RR(24), paint: .color(k.isDark ? .rgba(20, 34, 37, 0.97) : .rgba(255, 255, 255, 0.98)),
                           border: 1, borderColor: k.isDark ? .rgba(255, 255, 255, 0.1) : .rgba(15, 37, 40, 0.08),
                           shadows: k.isDark
                               ? [.inner(0, 1, 0, 0, .rgba(255, 255, 255, 0.08)), .drop(0, 24, 48, -16, .rgba(0, 0, 0, 0.8))]
                               : [.drop(0, 24, 48, -16, .rgba(12, 40, 44, 0.35)), .drop(0, 2, 6, 0, .rgba(12, 40, 44, 0.06))]))
        .clipShape(RR(24))
        .accessibilityLabel("Vorschläge")
    }

    /// Abschnitt: Überschrift 12/600 versal; Treffer umgekehrt, damit der beste direkt über dem Feld steht.
    @ViewBuilder
    private func section(title: String, results: [SearchResult], k: SheetTheme, topPadding: CGFloat) -> some View {
        if !results.isEmpty {
            Text(title)
                .font(AppFont.dm(12, 600))
                .tracking(0.48)                                   // 0.04em × 12
                .textCase(.uppercase)
                .foregroundStyle(k.sub)
                .padding(.horizontal, 10)
                .padding(.top, topPadding)
                .padding(.bottom, 4)
            ForEach(Array(results.reversed())) { result in
                InlineSearchResultRow(k: k, result: result, query: query,
                                      isInList: isInList(result), justAdded: justAdded.contains(result.id)) {
                    add(result)
                }
            }
        }
    }

    /// „„…“ als neuen Artikel anlegen“: 56 hoch, Text 15/600 Akzenttext, rechts Glas „+“ 40.
    private func createRow(k: SheetTheme) -> some View {
        Button(action: createNew) {
            HStack(spacing: 12) {
                Text("„\(query)“ als neuen Artikel anlegen")
                    .font(AppFont.dm(15, 600))
                    .foregroundStyle(k.accentText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                GlassOrb(style: .accent, appearance: appearance, accent: k.a, icon: Icon.plus, size: 40, lineWidth: 2.4)
            }
            .padding(.horizontal, 8)
            .frame(height: 56)
            .contentShape(RR(16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Aktionen

    private func isInList(_ result: SearchResult) -> Bool {
        let key = CatalogOperation.key(result.entry.name)
        return listViewModel.items.contains { CatalogOperation.key($0.name) == key && !$0.isChecked }
    }

    /// Tastatur-Taste: bester Treffer (Deine Artikel vor Produktkatalog), ohne Treffer neu anlegen.
    private func addBestMatch() {
        guard !query.isEmpty else { close(); return }
        if let best = searchVM.personalResults.first ?? searchVM.globalResults.first {
            add(best)
            searchVM.searchText = ""
            focused = true
        } else {
            createNew()
        }
    }

    private func createNew() {
        let name = query
        close()
        onCreateNew(name)
    }

    /// Hinzufügen (bzw. Menge +1), Feld bleibt aktiv; „+“ zeigt 1,2 s einen Haken.
    private func add(_ result: SearchResult) {
        guard let ownerPublicId = listViewModel.defaultList?.ownerId.uuidString else {
            logVoid(params: (action: "inlineAdd.add.skipped", reason: "defaultList.ownerId is nil"))
            return
        }
        let item = result.entry.toItemModel(listId: listViewModel.listId.uuidString, ownerPublicId: ownerPublicId)
        listViewModel.addItem(item, remoteImageURL: result.entry.imageUrl) // Katalog-Bild nachladen (ohne eigenes Foto)
        justAdded.insert(result.id)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            justAdded.remove(result.id)
        }
    }

    private func close() {
        focused = false
        onClose()
    }
}
