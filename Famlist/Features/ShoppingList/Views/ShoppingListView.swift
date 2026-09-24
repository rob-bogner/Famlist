/*
 ShoppingListView.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hauptscreen der Einkaufsliste im Hybrid-Design: Hintergrund, scrollender Inhalt, Dock
   und die Hybrid-Sheets (Suchen, Neuer Artikel, Bearbeiten, Produktbild) als eigene Ebene.

 🛠 Includes:
 - ShoppingListContent (Top-Bar, Suche, Fortschritt, Tabs, Abschnitte) + ListDock.
 - Sheet-Ebene: Liste 3 pt weichgezeichnet, Abdunkelung (scrim), Sheet von unten.
 - „Mehr“-Menü: Import, Alle abhaken/zurücksetzen, Lösch-Varianten, Mitglieder, Liste teilen, Profil, Abmelden.
 - Rückfragen (ListConfirmation) für Duplizieren und Löschen.

 🔰 Notes for Beginners:
 - Die Hybrid-Sheets sind bewusst KEINE `.sheet()`-Präsentationen (eigene Radien, kein System-Glas).
   Listen-Übersicht, Import und Profil sind nicht Teil des Designs und bleiben System-Sheets.
 - Light/Dark folgt dem System (`colorScheme`), der Akzent ist der Design-Standard.
 - Oben und unten gilt die echte Safe Area. Auf dem Referenzgerät (Top 62 / Bottom 34)
   ergibt das exakt die Design-Abstände, auf anderen Geräten rutscht nichts unter Notch oder Home-Indikator.

 📝 Last Change:
 - Komplett auf das Hybrid-Design umgestellt (ersetzt AccentHeader, ListView und FloatingBottomMenuBar).
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI for declarative UI building blocks and property wrappers.

/// The main shopping list screen in the Hybrid design.
struct ShoppingListView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var session: AppSessionViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var keyboard = KeyboardObserver()
    @State private var activeSheet: ActiveListSheet?
    @State private var openRow: OpenSwipeRow?
    @State private var pendingConfirmation: ListConfirmation?
    @State private var showListsOverview = false
    @State private var showImport = false
    @State private var showProfile = false
    @State private var showShareSheet = false
    @State private var showMembersSheet = false

    var body: some View {
        let appearance = Appearance(colorScheme)
        let t = ListTheme(appearance)
        let k = SheetTheme(appearance)

        GeometryReader { geo in
            let screenHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            listLayer(t: t, bottomInset: geo.safeAreaInsets.bottom)
                .blur(radius: activeSheet == nil ? 0 : 3, opaque: true)
                .allowsHitTesting(activeSheet == nil)
                .overlay(alignment: .bottom) {
                    sheetLayer(k: k, maxHeight: screenHeight - 54)   // Design: 54 pt Luft über dem höchsten Sheet
                }
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.4, dampingFraction: 0.88), value: activeSheet)
        .sheet(isPresented: $showListsOverview) {
            ListsOverviewView()
                .environmentObject(listViewModel)
                .environmentObject(session)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareListView(list: listViewModel.defaultList,
                          currentPublicId: session.currentProfile?.publicId ?? "")
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMembersSheet) {
            MembersView(list: listViewModel.defaultList)
                .environmentObject(session)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showImport) {
            ClipboardImportView()
                .environmentObject(listViewModel)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfile) {
            if let profile = session.currentProfile {
                ProfileView(profile: profile)
                    .environmentObject(session)
                    .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog(pendingConfirmation?.title ?? "", isPresented: confirmationBinding,
                            titleVisibility: .visible, presenting: pendingConfirmation) { confirmation in
            Button(confirmation.confirmLabel, role: confirmation.isDestructive ? .destructive : nil) {
                perform(confirmation)
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { confirmation in
            Text(confirmation.message)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active: listViewModel.handleAppDidBecomeActive()
            case .background: listViewModel.handleAppDidEnterBackground()
            default: break
            }
        }
    }

    // MARK: - List Layer

    private func listLayer(t: ListTheme, bottomInset: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ListBackground(t: t)
            ScrollView {
                ShoppingListContent(
                    t: t,
                    openRow: $openRow,
                    onSearch: openSearch,
                    onShowLists: { showListsOverview = true },
                    onEdit: { activeSheet = .edit($0) },
                    onShowImage: { activeSheet = .productImage($0) },
                    moreMenu: { moreMenu }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 68 + 28)       // Dock 68 + Luft, damit die letzte Karte frei liegt
            }
            .scrollIndicators(.hidden)
            .refreshable { await listViewModel.pullToRefresh() }   // FAM-40
            .modifier(CloseSwipedRowOnScroll(openRow: $openRow))
            ListDock(
                t: t,
                sortOrder: ListViewModel.currentSortOrder,
                hasCheckedItems: listViewModel.checkedItemCount > 0,
                liveBlur: t.isDark,               // Dark-Pille ist nur zu 78 % deckend → Karten scheinen sonst durch
                onSort: { listViewModel.setSortOrder($0) },
                onDuplicate: { pendingConfirmation = .duplicate },
                onDeleteChecked: { pendingConfirmation = .deleteChecked },
                onAdd: openSearch
            )
            .padding(.horizontal, 20)
            .padding(.bottom, bottomInset > 0 ? 0 : 16)   // ohne Home-Indikator trotzdem Abstand halten
        }
    }

    // MARK: - Sheet Layer

    @ViewBuilder
    private func sheetLayer(k: SheetTheme, maxHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            if activeSheet != nil {
                k.scrim
                    .onTapGesture(perform: closeSheet)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            if let sheet = activeSheet {
                sheetView(sheet, k: k, maxHeight: maxHeight)
                    .id(sheet.id)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveListSheet, k: SheetTheme, maxHeight: CGFloat) -> some View {
        switch sheet {
        case .search:
            if let catalog = listViewModel.catalogRepository {
                ItemSearchSheet(catalogRepository: catalog,
                                globalCatalogRepository: listViewModel.globalCatalogRepository,
                                k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height,
                                onClose: closeSheet,
                                onCreateNew: { activeSheet = .newItem(initialName: $0) })
            }
        case .newItem(let name):
            NewItemSheet(initialName: name, k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height, onClose: closeSheet)
        case .edit(let item):
            EditItemSheet(item: item, k: k, maxHeight: maxHeight, keyboardHeight: keyboard.height, onClose: closeSheet)
        case .productImage(let item):
            ProductImageSheet(item: item, k: k, maxHeight: maxHeight, onClose: closeSheet)
        }
    }

    // MARK: - More Menu

    @ViewBuilder
    private var moreMenu: some View {
        let allChecked = !listViewModel.items.isEmpty && listViewModel.items.allSatisfy(\.isChecked)
        Button { showImport = true } label: {
            Label("Aus Zwischenablage importieren", systemImage: "doc.on.clipboard")
        }
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { listViewModel.toggleAllItems() }
        } label: {
            Label(allChecked ? "Alle zurücksetzen" : "Alle abhaken",
                  systemImage: allChecked ? "arrow.uturn.backward.circle" : "checkmark.circle")
        }
        .disabled(listViewModel.items.isEmpty)
        Menu {
            Button("Offene löschen", role: .destructive) { pendingConfirmation = .deleteOpen }
                .disabled(listViewModel.uncheckedItems.isEmpty)
            Button("Alle Artikel löschen", role: .destructive) { pendingConfirmation = .deleteAll }
        } label: {
            Label("Löschen", systemImage: "trash")
        }
        .disabled(listViewModel.items.isEmpty)
        Divider()
        if listViewModel.defaultList != nil {
            Button { showMembersSheet = true } label: {
                Label("Mitglieder", systemImage: "person.2")
            }
        }
        if let list = listViewModel.defaultList, list.ownerId == session.currentProfile?.id {
            Button { showShareSheet = true } label: {
                Label("Liste teilen", systemImage: "person.badge.plus")
            }
        }
        Divider()
        Button { showProfile = true } label: {
            Label(String(localized: "menu.profile"), systemImage: "person.circle")
        }
        Button(role: .destructive) { session.signOut() } label: {
            Label(String(localized: "auth.signout.button"), systemImage: "rectangle.portrait.and.arrow.right")
        }
    }

    // MARK: - Actions

    private var confirmationBinding: Binding<Bool> {
        Binding(get: { pendingConfirmation != nil }, set: { if !$0 { pendingConfirmation = nil } })
    }

    /// Opens the search sheet, or the new-item form when no catalog is configured (preview / fallback).
    private func openSearch() {
        openRow = nil
        activeSheet = listViewModel.catalogRepository == nil ? .newItem(initialName: "") : .search
    }

    private func closeSheet() {
        hideKeyboard()
        activeSheet = nil
    }

    private func perform(_ confirmation: ListConfirmation) {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch confirmation {
            case .duplicate: listViewModel.duplicateActiveList()
            case .deleteChecked: listViewModel.deleteCheckedItems()
            case .deleteOpen: listViewModel.deleteUncheckedItems()
            case .deleteAll: listViewModel.deleteAllItems()
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
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
}

#Preview("Dark") {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    ShoppingListView()
        .modelContainer(PersistenceController.preview.container)
        .environmentObject(listVM)
        .environmentObject(AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                               lists: PreviewListsRepository(), listViewModel: listVM))
        .preferredColorScheme(.dark)
}
