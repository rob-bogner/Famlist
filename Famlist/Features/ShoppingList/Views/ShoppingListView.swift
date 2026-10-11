/*
 ShoppingListView.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hauptscreen der Einkaufsliste im Hybrid-Design: Hintergrund, scrollender Inhalt, Dock,
   Overlays (☰, Sortieren, Kopieren, Löschen), Toasts und die Hybrid-Sheets als eigene Ebenen.

 🛠 Includes:
 - ShoppingListView+Overlays.swift: Dock, Abdunkelung, Popovers, Toasts, Dock-Aktionen.
 - ShoppingListView+Sheets.swift: Sheet-Ebene (Suchen, Neuer Artikel, Bearbeiten, …).
 - ShoppingListView+Receipts.swift: Kassenzettel und Preisverlauf.

 🔰 Notes for Beginners:
 - Sheets und Overlays sind bewusst KEINE `.sheet()`-Präsentationen (eigene Radien, kein System-Glas).
 - Die Design-Screens laufen mit `hybridHosted = true`: Sie zeichnen nur ihren Inhalt,
   Weichzeichner und Abdunkelung liegen hier über der echten Liste.
 - Oben und unten gilt die echte Safe Area. Auf dem Referenzgerät (Top 62 / Bottom 34) ergibt
   das exakt die Design-Abstände; `topShift`/`dockShift` gleichen andere Geräte aus.

 📝 Last Change:
 - Tab-Wechsel scrollt die Liste ganz nach oben (12.10.2026).
 - Plus im Dock → Eingabe über der Tastatur (InlineAddOverlay), Suchleiste oben → Listenfilter.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI for declarative UI building blocks and property wrappers.

/// The main shopping list screen in the Hybrid design.
struct ShoppingListView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var session: AppSessionViewModel
    @EnvironmentObject var categoryStore: CategoryStore
    @EnvironmentObject var priceBook: PriceBook
    @EnvironmentObject var receiptArchive: ReceiptArchive
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    /// Bedienungshilfe „Bewegung reduzieren“: Sheets/Overlays nur ein-/ausblenden, keine Federn.
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @StateObject var keyboard = KeyboardObserver()
    /// Geteilte Liste: Namen und Profilbilder der anderen Mitglieder (Profilbild am Mengen-Chip).
    @StateObject var contributors = ListContributorsStore()
    /// Menge direkt in der Liste ändern (Mengen-Chip → Pille, Design: ListQuantityEdit).
    @State var quantityEditor = InlineQuantityEditor()
    @State var activeSheet: ActiveListSheet?
    @State var activeOverlay: ListOverlay?
    @State var openRow: OpenSwipeRow?
    /// Dock zeigt 2 s lang „Kopiert“, dazu der Toast „Liste kopiert“.
    @State var copied: CopyResult?
    /// Restzeit-Balken des Rückgängig-Toasts (1 → 0 in 5 s).
    @State var undoRemaining: CGFloat = 1
    /// Restzeit des Hinweises „Mitglied hat das Konto gelöscht“ (MemberDeletedToast).
    @State var noticeRemaining: CGFloat = 1
    /// Liste, deren Löschen gerade bestätigt werden soll (Listen-Optionen → „Liste löschen“).
    @State var listToDelete: ListModel?
    @State var isDeletingAccount = false
    @State var deleteAccountError: String?
    /// „Artikel verwalten“ bleibt beim Wechsel ins Bearbeiten-Sheet erhalten.
    @State var manageItemsVM: ManageItemsViewModel?
    /// Eingaben in „Artikel bearbeiten“, solange der Preisverlauf darüber liegt (sonst gingen sie beim Zurückkehren verloren).
    @State var editDraft: ItemModel?
    /// Ablauf „Kassenzettel“: lebt von der Aufnahme bis „Einkauf erledigt“.
    @State var receiptFlow: ReceiptFlowViewModel?
    /// Fehlermeldung des ListViewModels als Toast (blendet nach 3 s aus).
    @State var errorToast: String?
    /// Scroll-Weg der Liste; nur CollapsingListHeader liest ihn (sonst würde die ganze Liste je Frame neu berechnet).
    @State var listScroll = ListScrollState()
    @AppStorage(PriceDisplaySetting.storageKey) private var showPrices = PriceDisplaySetting.defaultValue
    /// Hinzufügen über das Plus im Dock: Eingabe über der Tastatur (InlineAddOverlay, Canvas AddInline).
    @State var isAddOpen = false
    /// Vorbelegung der Eingabe (Brücke aus dem Filter: „„milch“ zur Liste hinzufügen“).
    @State var addPrefill = ""
    /// Suchleiste oben filtert die Liste (Canvas SearchInline).
    @State var isFiltering = false
    @State var filterQuery = ""
    /// Zum Hochscrollen der Liste, bevor der Filter aufgeht (Feld liegt dann genau an der Stelle der Suchleiste).
    @State var listScrollProxy: ScrollViewProxy?
    static let listTopID = "shoppingListTop"

    var appearance: Appearance { Appearance(colorScheme) }

    /// Ersteller in der Liste, die weder der angemeldete Nutzer noch ein bekanntes Mitglied sind.
    private var unknownCreators: Set<String> {
        let me = session.currentProfile?.id.uuidString.lowercased()
        return Set(listViewModel.items.compactMap { $0.createdBy?.lowercased() })
            .subtracting(contributors.byId.keys)
            .filter { $0 != me }
    }

    /// Neu laden bei Listenwechsel, Anmeldung oder unbekannter Person (sortiert für einen stabilen Schlüssel).
    private var contributorsKey: String {
        [listViewModel.defaultList?.id.uuidString ?? "-", session.currentProfile?.id.uuidString ?? "-"]
            .joined(separator: "|") + "|" + unknownCreators.sorted().joined(separator: ",")
    }

    var body: some View {
        let t = ListTheme(appearance)
        let k = SheetTheme(appearance)

        GeometryReader { geo in
            let screenHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let insets = LayoutShift(top: geo.safeAreaInsets.top, bottom: geo.safeAreaInsets.bottom)
            ZStack(alignment: .bottom) {
                listLayer(t: t)
                    // opaque: false ist Pflicht: `opaque: true` teilt jedes Pixel durch seinen Alpha-Wert
                    // (Apple-Doku GraphicsContext.BlurOptions.opaque) → pixelig/schwarz (auf dem Gerät nachgewiesen).
                    .blur(radius: backgroundBlur, opaque: false)
                    .background { ListBackground(t: t) }
                    .allowsHitTesting(activeSheet == nil && activeOverlay == nil)
                    // VoiceOver: Hinter offenen Sheets/Overlays ist die Liste nicht erreichbar (wie beim Tippen).
                    .accessibilityHidden(activeSheet != nil || activeOverlay != nil || isAddOpen)
                overlayLayer(t: t, insets: insets)
                if isAddOpen, let catalog = listViewModel.catalogRepository {
                    InlineAddOverlay(catalogRepository: catalog,
                                     globalCatalogRepository: listViewModel.globalCatalogRepository,
                                     appearance: appearance, keyboardHeight: keyboard.height,
                                     initialQuery: addPrefill,
                                     onClose: closeAdd,
                                     onCreateNew: { activeSheet = .newItem(initialName: $0) },
                                     onScan: openScanner,
                                     onPhoto: openPhotoAdd)
                        .transition(.opacity)
                }
                sheetLayer(k: k, maxHeight: screenHeight - 54, insets: insets)   // Design: 54 pt Luft über dem höchsten Sheet
                errorToastView(insets: insets)
            }
            .environment(\.hybridHosted, true)
            .environment(\.hybridScreenWidth, geo.size.width)
        }
        .ignoresSafeArea(.keyboard)
        .animation(motion(.spring(response: 0.4, dampingFraction: 0.88)), value: activeSheet)
        .animation(motion(.spring(response: 0.35, dampingFraction: 0.82)), value: activeOverlay)
        .onChange(of: listViewModel.errorMessage) { _, message in showError(message) }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: listViewModel.handleAppDidBecomeActive()
            case .background:
                quantityEditor.finish()                       // offene Mengen-Änderung speichern
                listViewModel.commitPendingDeletion()        // Rückgängig-Zeitraum endet mit dem Verlassen der App
                listViewModel.handleAppDidEnterBackground()
            default: break
            }
        }
        .task(id: session.currentProfile?.id) {
            if let id = session.currentProfile?.id { await categoryStore.load(profileId: id) }
        }
        .onReceive(categoryStore.$categories) { listViewModel.categoryOrder = $0 }
        // Geteilte Liste: Mitglieder laden (Listenwechsel) bzw. neu laden, wenn eine unbekannte Person auftaucht.
        .environment(\.itemContributors, contributors.byId)
        .environment(\.inlineQuantityEditor, quantityEditor)
        .onAppear {
            quantityEditor.onCommit = { [listViewModel] id, units in
                guard var item = listViewModel.items.first(where: { $0.id == id }), item.units != units else { return }
                item.units = units
                listViewModel.updateItem(item, updateCatalog: false)
            }
        }
        // Ziffernblock offen → Karte ins obere Drittel, damit die Pille über der Tastatur bleibt.
        .onChange(of: quantityEditor.isTyping) { _, typing in
            guard typing, let id = quantityEditor.editingId else { return }
            withAnimation(.easeOut(duration: 0.25)) { listScrollProxy?.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.3)) }
        }
        // Mengen-Pille schließen, sobald ein Sheet/Menü aufgeht oder die Liste wechselt.
        .onChange(of: activeSheet?.id) { _, id in if id != nil { quantityEditor.finish() } }
        .onChange(of: activeOverlay) { _, overlay in if overlay != nil { quantityEditor.finish() } }
        .onChange(of: listViewModel.listId) { _, _ in quantityEditor.finish() }
        .task(id: contributorsKey) {
            await contributors.load(list: listViewModel.defaultList, me: session.currentProfile?.id,
                                    lists: listViewModel.listsRepository, profiles: session.profiles,
                                    force: !unknownCreators.isEmpty)
        }
        #if DEBUG
        .onAppear { applyDesignLaunchState() }
        #endif
        .onChange(of: listViewModel.listId) { _, _ in exitFilter() }   // Filter gilt nur für die aktuelle Liste
        .onChange(of: listViewModel.itemFilter) { _, _ in scrollListToTop() }   // Tab-Wechsel: Liste beginnt oben
        .onChange(of: listViewModel.shoppingCompletedEvent) { _, event in
            if let event { offerShoppingDone(for: event) }
        }
        .onChange(of: activeSheet?.id) { _, _ in
            // Entwurf gilt nur für „Artikel bearbeiten“ ↔ Preisverlauf; jedes andere Sheet (oder keins) verwirft ihn.
            switch activeSheet {
            case .edit, .itemPriceHistory: break
            default: editDraft = nil
            }
        }
        .onChange(of: listViewModel.pendingDeletion?.id) { _, newId in
            guard newId != nil else { return }
            undoRemaining = 1
            withAnimation(.linear(duration: PendingItemDeletion.undoDuration)) { undoRemaining = 0 }
        }
    }

    /// Sheet: 3 pt (SheetScreen), Overlay: 2 pt (OverlayScrim), sonst scharf.
    private var backgroundBlur: CGFloat {
        if activeSheet != nil { return 3 }
        if isAddOpen { return 2 }                             // AddInline: backdrop-filter blur(2px)
        return activeOverlay == nil ? 0 : 2
    }

    // MARK: - List Layer

    private func listLayer(t: ListTheme) -> some View {
      ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                // Kopf außerhalb des LazyVStack: bleibt beim weiten Scrollen erhalten und wird oben gehalten.
                CollapsingListHeader(
                    t: t,
                    title: listViewModel.defaultList?.title ?? String(localized: "shoppingList.title"),
                    checked: listViewModel.checkedItemCount,
                    total: listViewModel.totalItemCount,
                    totalPrice: showPrices ? PriceDisplaySetting.total(of: listViewModel.items) : nil,
                    filter: $listViewModel.itemFilter,
                    scroll: listScroll,
                    onShowLists: openLists,
                    onSearch: openFilter,
                    onMenu: { open(.menu) },
                    isFiltering: isFiltering,
                    filterQuery: $filterQuery,
                    onExitFilter: exitFilter)
                    .id(Self.listTopID)
                ShoppingListContent(
                    t: t,
                    openRow: $openRow,
                    onEdit: { activeSheet = .edit($0) },
                    onShowImage: { activeSheet = .productImage($0) },
                    filterQuery: isFiltering ? filterQuery : "",
                    onAddFromFilter: { query in
                        exitFilter()
                        openAdd(prefill: query)
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 64 + 28)       // Dock 64 + Luft, damit die letzte Karte frei liegt
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: ListScrollOffsetKey.self,
                                           value: -geo.frame(in: .named(ListScrollOffsetKey.coordinateSpace)).minY)
                }
            }
        }
        .coordinateSpace(name: ListScrollOffsetKey.coordinateSpace)
        .modifier(TrackListScrollOffset(onChange: { [listScroll] in listScroll.update(offset: $0) }))
        .modifier(TrackListCoasting(onChange: listCoastingChanged))
        .scrollIndicators(.hidden)
        // Offene Mengen-Pille: Liste steht still; Tippen außerhalb der Pille schließt sie.
        .scrollDisabled(quantityEditor.editingId != nil)
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .global).onEnded { quantityEditor.handleTap(at: $0.location) })
        .refreshable { await listViewModel.pullToRefresh() }   // FAM-40
        .modifier(CloseSwipedRowOnScroll(openRow: $openRow))
        // Tabs bleiben antippbar, während die Liste nachläuft (liegt ÜBER der Scroll-Ansicht).
        .overlay(alignment: .top) {
            CoastingTabsCatcher(t: t, selection: $listViewModel.itemFilter,
                                openCount: max(listViewModel.totalItemCount - listViewModel.checkedItemCount, 0),
                                doneCount: listViewModel.checkedItemCount,
                                scroll: listScroll, isEnabled: !isFiltering)
        }
        .onAppear { listScrollProxy = proxy }
      }
    }

    /// Nachlauf beginnt / endet. Wurde im Nachlauf der Tab gewechselt, steht die Liste danach sicher oben.
    private func listCoastingChanged(_ coasting: Bool) {
        listScroll.isCoasting = coasting
        if !coasting, listScroll.returnToTopWhenIdle {
            listScroll.returnToTopWhenIdle = false
            listScrollProxy?.scrollTo(Self.listTopID, anchor: .top)
        }
    }

    // MARK: - Navigation Helpers

    /// Suchleiste / Such-Knopf: Filter-Modus. Erst ganz nach oben, damit das Feld an der Stelle der Suchleiste liegt.
    func openFilter() {
        openRow = nil
        let needsScroll = listScroll.offset > 1
        withAnimation(motion(.easeOut(duration: 0.25))) {
            listScrollProxy?.scrollTo(Self.listTopID, anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (needsScroll ? 0.3 : 0)) {
            withAnimation(motion(.easeOut(duration: 0.2))) { isFiltering = true }
        }
    }

    /// Tab-Wechsel (Alle · Offen · Erledigt): Die Liste beginnt wieder ganz oben, dadurch zeigt der Kopf die große
    /// Fortschrittskarte (Wunsch Robert 12.10.2026). Ohne Animation: Die Zeilen wechseln im selben Moment.
    func scrollListToTop() {
        openRow = nil
        listScroll.returnToTopWhenIdle = listScroll.isCoasting
        listScrollProxy?.scrollTo(Self.listTopID, anchor: .top)
    }

    /// ✕ im Filterfeld, leeres Feld ohne Fokus oder Listenwechsel.
    func exitFilter() {
        guard isFiltering || !filterQuery.isEmpty else { return }
        hideKeyboard()
        withAnimation(motion(.easeOut(duration: 0.2))) {
            filterQuery = ""
            isFiltering = false
        }
    }

    /// Plus im Dock: Eingabe über der Tastatur. Ohne Katalog (Vorschau) direkt „Neuer Artikel“.
    func openAdd(prefill: String = "") {
        openRow = nil
        activeOverlay = nil
        guard listViewModel.catalogRepository != nil else {
            activeSheet = .newItem(initialName: prefill)
            return
        }
        addPrefill = prefill
        withAnimation(motion(.easeOut(duration: 0.2))) { isAddOpen = true }
    }

    func closeAdd() {
        hideKeyboard()
        withAnimation(motion(.easeOut(duration: 0.2))) { isAddOpen = false }
    }

    /// Scan-Knopf im Suchfeld → Barcode-Scanner (SPEC §3.2).
    /// Per Foto hinzufügen (Kamera-Knopf in der Suchleiste).
    func openPhotoAdd() {
        openRow = nil
        activeSheet = .photoAdd
    }

    func openScanner() {
        openRow = nil
        activeSheet = .barcode
    }

    func openLists() {
        openRow = nil
        activeSheet = .lists
    }

    func closeSheet() {
        hideKeyboard()
        activeSheet = nil
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Abstand der echten Safe Area zu den Design-Werten (Top 62 / Dock-Unterkante 34).
struct LayoutShift {
    let top: CGFloat
    let bottom: CGFloat

    /// Unterkante des Docks über dem Bildschirmrand (ohne Home-Indikator: 16).
    var dockBottom: CGFloat { bottom > 0 ? bottom : 16 }
    /// Verschiebung für absolut positionierte Design-Overlays, die sich auf das Dock beziehen.
    var dockShift: CGFloat { 34 - dockBottom }
    /// Verschiebung für Overlays, die sich auf die Oberkante (62) beziehen.
    var topShift: CGFloat { top - 62 }
}

/// Liefert die Scroll-Position der Liste. iOS 18+: onScrollGeometryChange (zuverlässig während des Scrollens –
/// die GeometryReader-Preference kam auf dem Gerät nicht an, der kompakte Kopf erschien nie).
/// iOS 17: Fallback über ListScrollOffsetKey (GeometryReader im Inhalt).
private struct TrackListScrollOffset: ViewModifier {
    let onChange: @MainActor (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top          // 0 = ganz oben, negativ beim Ziehen
            } action: { _, offset in
                onChange(offset)
            }
        } else {
            content.onPreferenceChange(ListScrollOffsetKey.self) { offset in
                MainActor.assumeIsolated { onChange(offset) }            // Preferences kommen auf dem Main-Thread
            }
        }
    }
}

/// Schließt eine offene Wisch-Zeile, sobald der Nutzer die Liste scrollt (iOS 18+, wie in Mail).
private struct CloseSwipedRowOnScroll: ViewModifier {
    @Binding var openRow: OpenSwipeRow?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                if phase == .interacting, openRow != nil {
                    withAnimation(SwipeableItemRow.snap(reduceMotion: reduceMotion)) { openRow = nil }
                }
            }
        } else {
            content
        }
    }
}

#Preview("Light") {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    ShoppingListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(listVM)
        .environmentObject(AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                               lists: PreviewListsRepository(), listViewModel: listVM))
        .environmentObject(CategoryStore(repository: nil))
        .environmentObject(PriceBook(repository: nil))
        .environmentObject(ReceiptArchive(repository: nil))
}

#Preview("Dark") {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    ShoppingListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(listVM)
        .environmentObject(AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                               lists: PreviewListsRepository(), listViewModel: listVM))
        .environmentObject(CategoryStore(repository: nil))
        .environmentObject(PriceBook(repository: nil))
        .environmentObject(ReceiptArchive(repository: nil))
        .preferredColorScheme(.dark)
}
