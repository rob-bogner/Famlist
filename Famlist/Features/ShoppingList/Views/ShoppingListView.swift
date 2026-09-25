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
 - Redesign „Hybrid“ (Handoff 24.09.2026): DockView, Kontext-Menü, Dock-Menüs, Toasts.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI for declarative UI building blocks and property wrappers.

/// The main shopping list screen in the Hybrid design.
struct ShoppingListView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var session: AppSessionViewModel
    @EnvironmentObject var categoryStore: CategoryStore
    @EnvironmentObject var priceBook: PriceBook
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    /// Bedienungshilfe „Bewegung reduzieren“: Sheets/Overlays nur ein-/ausblenden, keine Federn.
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @StateObject var keyboard = KeyboardObserver()
    @State var activeSheet: ActiveListSheet?
    @State var activeOverlay: ListOverlay?
    @State var openRow: OpenSwipeRow?
    /// Dock zeigt 2 s lang „Kopiert“, dazu der Toast „Liste kopiert“.
    @State var copied: CopyResult?
    /// Restzeit-Balken des Rückgängig-Toasts (1 → 0 in 5 s).
    @State var undoRemaining: CGFloat = 1
    /// Liste, deren Löschen gerade bestätigt werden soll (Listen-Optionen → „Liste löschen“).
    @State var listToDelete: ListModel?
    @State var isDeletingAccount = false
    @State var deleteAccountError: String?
    /// „Artikel verwalten“ bleibt beim Wechsel ins Bearbeiten-Sheet erhalten.
    @State var manageItemsVM: ManageItemsViewModel?
    /// Ablauf „Kassenzettel“: lebt von der Aufnahme bis „Einkauf erledigt“.
    @State var receiptFlow: ReceiptFlowViewModel?
    /// Fehlermeldung des ListViewModels als Toast (blendet nach 3 s aus).
    @State var errorToast: String?

    var appearance: Appearance { Appearance(colorScheme) }

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
                    .accessibilityHidden(activeSheet != nil || activeOverlay != nil)
                overlayLayer(t: t, insets: insets)
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
                listViewModel.commitPendingDeletion()        // Rückgängig-Zeitraum endet mit dem Verlassen der App
                listViewModel.handleAppDidEnterBackground()
            default: break
            }
        }
        .task(id: session.currentProfile?.id) {
            if let id = session.currentProfile?.id { await categoryStore.load(profileId: id) }
        }
        .onReceive(categoryStore.$categories) { listViewModel.categoryOrder = $0 }
        #if DEBUG
        .onAppear { applyDesignLaunchState() }
        #endif
        .onChange(of: listViewModel.shoppingCompletedEvent) { _, event in
            if let event { offerShoppingDone(for: event) }
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
        return activeOverlay == nil ? 0 : 2
    }

    // MARK: - List Layer

    private func listLayer(t: ListTheme) -> some View {
        ScrollView {
            ShoppingListContent(
                t: t,
                openRow: $openRow,
                onSearch: openSearch,
                onScan: openScanner,
                onShowLists: openLists,
                onMenu: { open(.menu) },
                onEdit: { activeSheet = .edit($0) },
                onShowImage: { activeSheet = .productImage($0) }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 64 + 28)       // Dock 64 + Luft, damit die letzte Karte frei liegt
        }
        .scrollIndicators(.hidden)
        .refreshable { await listViewModel.pullToRefresh() }   // FAM-40
        .modifier(CloseSwipedRowOnScroll(openRow: $openRow))
    }

    // MARK: - Navigation Helpers

    /// Opens the search sheet, or the new-item form when no catalog is configured (preview / fallback).
    func openSearch() {
        openRow = nil
        activeSheet = listViewModel.catalogRepository == nil ? .newItem(initialName: "") : .search
    }

    /// Scan-Knopf im Suchfeld → Barcode-Scanner (SPEC §3.2).
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
        .preferredColorScheme(.dark)
}
