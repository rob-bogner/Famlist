/*
 ShoppingListView.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hauptscreen der Einkaufsliste im Hybrid-Design: Hintergrund, scrollender Inhalt, Dock,
   Overlays (☰, Sortieren, Kopieren, Löschen), Toasts und die Hybrid-Sheets als eigene Ebenen.

 🛠 Includes:
 - ShoppingListView+Overlays.swift: Dock, Abdunkelung, Popovers, Toasts, Dock-Aktionen.
 - ShoppingListView+Sheets.swift: Sheet-Ebene (Suchen, Neuer Artikel, Bearbeiten, …).

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
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @StateObject var keyboard = KeyboardObserver()
    @State var activeSheet: ActiveListSheet?
    @State var activeOverlay: ListOverlay?
    @State var openRow: OpenSwipeRow?
    /// Dock zeigt 2 s lang „Kopiert“, dazu der Toast „Liste kopiert“.
    @State var copied: CopyResult?
    /// Restzeit-Balken des Rückgängig-Toasts (1 → 0 in 5 s).
    @State var undoRemaining: CGFloat = 1
    @State var showImport = false
    /// Liste, deren Löschen gerade bestätigt werden soll (Listen-Optionen → „Liste löschen“).
    @State var listToDelete: ListModel?
    @State var isDeletingAccount = false
    @State var deleteAccountError: String?
    /// „Artikel verwalten“ bleibt beim Wechsel ins Bearbeiten-Sheet erhalten.
    @State var manageItemsVM: ManageItemsViewModel?

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
                overlayLayer(t: t, insets: insets)
                sheetLayer(k: k, maxHeight: screenHeight - 54, insets: insets)   // Design: 54 pt Luft über dem höchsten Sheet
            }
            .environment(\.hybridHosted, true)
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: activeSheet)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activeOverlay)
        .sheet(isPresented: $showImport) {
            ClipboardImportView()
                .environmentObject(listViewModel)
                .presentationDragIndicator(.visible)
        }
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

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollPhaseChange { _, phase in
                if phase == .interacting, openRow != nil {
                    withAnimation(SwipeableItemRow.snap) { openRow = nil }
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
}

#Preview("Dark") {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    ShoppingListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(listVM)
        .environmentObject(AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                               lists: PreviewListsRepository(), listViewModel: listVM))
        .environmentObject(CategoryStore(repository: nil))
        .preferredColorScheme(.dark)
}
