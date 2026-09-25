/*
 ShoppingListView+Overlays.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Dock, Abdunkelung, Kontext-Menü ☰, Dock-Menüs (Sortieren, Kopieren, Löschen) und Toasts.

 🔰 Notes for Beginners:
 - Genau ein Dock-Knopf ist gewählt. Ruhezustand: „Alle abhaken“ (bzw. „Zurücksetzen“, wenn alles
   erledigt ist). Ein offenes Dock-Menü setzt die Pille auf seinen Knopf; beim Schließen springt sie zurück.
 - Leere Liste: Abhaken, Kopieren, Löschen gedimmt; Sortieren bleibt aktiv (SPEC §3.4).
 - Die Design-Overlays sind absolut positioniert (Referenz 390 × 844). `LayoutShift` verschiebt sie
   auf Geräten, deren Safe Area vom Referenzgerät (oben 62, unten 34) abweicht.

 📝 Last Change:
 - Fehler-Toast, VoiceOver-Modalität und „Bewegung reduzieren“ (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import SwiftUI
import UIKit

extension ShoppingListView {
    // MARK: - Layer

    @ViewBuilder
    func overlayLayer(t: ListTheme, insets: LayoutShift) -> some View {
        let k = OverlayTheme(appearance, variant: activeOverlay == .menu ? .listMenu : .dockMenu)
        let dockOnTop = activeOverlay?.keepsDockOnTop ?? false
        ZStack(alignment: .bottom) {
            if activeOverlay != nil {
                // OverlayScrim: Weichzeichner 2 liegt auf der Liste, hier nur die Farbe + Tippen schließt
                k.scrim
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeOverlay)
                    .transition(.opacity)
                    .accessibilityHidden(true)
                    .zIndex(1)
            }
            // Genau EINE Dock-Instanz: Nur die Ebene wechselt (unter/über der Abdunkelung).
            // Zwei bedingte Instanzen würden beim Öffnen/Schließen ausgetauscht → doppelte Leiste,
            // @Namespace neu, Pille springt statt zu gleiten.
            dock(t: t, insets: insets)
                .zIndex(dockOnTop ? 2 : 0)
            overlayContent(insets: insets)
                .accessibilityElement(children: .contain)
                // ☰ deckt das Dock ab → modal. Dock-Menüs lassen das Dock bedienbar (wie beim Tippen).
                .accessibilityAddTraits(activeOverlay == .menu ? .isModal : [])
                .accessibilityAction(.escape, closeOverlay)
                .zIndex(3)
            toasts(insets: insets)
                .zIndex(4)
        }
    }

    private func dock(t: ListTheme, insets: LayoutShift) -> some View {
        DockView(appearance: appearance, active: dockActive, pill: dockPill,
                 liveBlur: true,                   // backdrop-filter des Designs: Leiste ist nur zu 78/84 % deckend
                 onCheck: dockCheck, onSort: { toggle(.sort) }, onCopy: { toggle(.copy) },
                 onDelete: { toggle(.delete) }, onAdd: openNewItem)
            .frame(height: 64)
            .padding(.horizontal, 20)                     // volle Breite: links und rechts 20
            .padding(.bottom, insets.dockBottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
            .blur(radius: activeSheet != nil ? 3 : (activeOverlay == .menu ? 2 : 0), opaque: false)
            .allowsHitTesting(activeSheet == nil && activeOverlay != .menu)
            .accessibilityHidden(activeSheet != nil || activeOverlay == .menu)
            .animation(motion(.spring(response: 0.35, dampingFraction: 0.82)), value: dockActive)
    }

    @ViewBuilder
    private func overlayContent(insets: LayoutShift) -> some View {
        switch activeOverlay {
        case .menu:
            MenuOverlayScreen(appearance: appearance,
                              listTitle: listViewModel.defaultList?.title ?? String(localized: "shoppingList.title"),
                              memberCount: memberCount,
                              onClose: closeOverlay,
                              onSelect: handleMenu)
                .offset(y: insets.topShift)
                .transition(overlayTransition(anchor: .topTrailing))
        case .sort:
            SortMenuScreen(appearance: appearance, settings: listViewModel.sortSettings,
                           onSelect: { listViewModel.setSortOrder($0) },
                           onToggleDoneAtBottom: { listViewModel.setDoneAtBottom($0) },
                           onDismiss: closeOverlay)
                .offset(y: insets.dockShift)
                .transition(overlayTransition(anchor: .bottomLeading))
        case .copy:
            CopyChoiceScreen(appearance: appearance,
                             openCount: listViewModel.uncheckedItems.count,
                             allCount: listViewModel.items.count,
                             previewText: copyText(.open),
                             onSelect: copy, onDismiss: closeOverlay)
                .offset(y: insets.dockShift)
                .transition(overlayTransition(anchor: .bottomLeading))
        case .delete:
            DeleteChoiceScreen(appearance: appearance,
                               checkedCount: listViewModel.checkedItemCount,
                               allCount: listViewModel.items.count,
                               onDeleteChecked: { stageDeletion(.checked) },
                               onDeleteAll: { stageDeletion(.all) },
                               onDismiss: closeOverlay)
                .offset(y: insets.dockShift)
                .transition(overlayTransition(anchor: .bottomLeading))
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private func toasts(insets: LayoutShift) -> some View {
        let k = OverlayTheme(appearance)
        if let pending = listViewModel.pendingDeletion, activeSheet == nil {
            UndoToast(k: k, count: pending.count, remaining: undoRemaining,
                      onUndo: { listViewModel.undoPendingDeletion() })
                .padding(.horizontal, 20)
                .padding(.bottom, insets.dockBottom + 80)       // Design: unten 114 bei Dock-Unterkante 34
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .transition(toastTransition)
        } else if let copied, activeSheet == nil {
            CopyDoneToast(k: k, count: copied.count, scope: copied.scope)
                .padding(.horizontal, 20)
                .padding(.bottom, insets.dockBottom + 78)       // Design: unten 112 bei Dock-Unterkante 34
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(toastTransition)
        }
    }

    /// Fehler des ListViewModels (z. B. Liste offline duplizieren) über allen Ebenen, damit er auch
    /// über einem offenen Sheet sichtbar ist. Position wie der Rückgängig-Toast.
    @ViewBuilder
    func errorToastView(insets: LayoutShift) -> some View {
        if let errorToast {
            StatusToast(text: errorToast, isError: true, appearance: appearance)
                .padding(.horizontal, 20)
                .padding(.bottom, insets.dockBottom + 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(toastTransition)
                .zIndex(5)
        }
    }

    /// Zeigt die Meldung 3 s lang und setzt danach `errorMessage` zurück (wie AcceptInviteView).
    func showError(_ message: String?) {
        guard let message else { return }
        withAnimation(motion(.spring(response: 0.35, dampingFraction: 0.85))) { errorToast = message }
        AccessibilityNotification.Announcement(message).post()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard errorToast == message else { return }
            withAnimation(motion(.easeOut(duration: 0.25))) { errorToast = nil }
            if listViewModel.errorMessage == message { listViewModel.errorMessage = nil }
        }
    }

    // MARK: - Motion

    /// „Bewegung reduzieren“: Feder durch sanftes Ein-/Ausblenden ersetzen; sonst unverändert.
    func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.25) : animation
    }

    private func overlayTransition(anchor: UnitPoint) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: anchor))
    }

    private var toastTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    // MARK: - Dock State

    var dockPill: DockPill {
        if listViewModel.items.isEmpty { return .empty }
        return listViewModel.items.allSatisfy(\.isChecked) ? .allDone : .open
    }

    var dockActive: DockActive {
        if let activeOverlay, activeOverlay != .menu { return activeOverlay.dockActive }
        return copied != nil ? .copied : .none
    }

    /// Eigentümer + Mitglieder (fetchMembers liefert nur Nicht-Eigentümer).
    private var memberCount: Int { listViewModel.activeListMembers.count + 1 }

    // MARK: - Actions

    func open(_ overlay: ListOverlay) {
        openRow = nil
        if overlay == .menu { listViewModel.loadActiveListMembers() }
        activeOverlay = overlay
    }

    func closeOverlay() {
        activeOverlay = nil
    }

    /// Tippen auf einen Dock-Knopf: offenes Menü schließen bzw. das eigene Menü öffnen.
    private func toggle(_ overlay: ListOverlay) {
        activeOverlay = activeOverlay == overlay ? nil : overlay
        openRow = nil
    }

    /// „Alle abhaken“ / „Zurücksetzen“. Ist ein Dock-Menü offen, springt nur die Pille zurück.
    private func dockCheck() {
        guard activeOverlay == nil else { closeOverlay(); return }
        withAnimation(motion(.spring(response: 0.3, dampingFraction: 0.7))) { listViewModel.toggleAllItems() }
    }

    func openNewItem() {
        openRow = nil
        activeOverlay = nil
        activeSheet = .newItem(initialName: "")
    }

    private func copyText(_ scope: ListClipboardFormatter.Scope) -> String {
        let ordered = listViewModel.visibleSectionsIgnoringFilter.flatMap(\.items)
        return ListClipboardFormatter.text(listTitle: listViewModel.defaultList?.title ?? String(localized: "shoppingList.title"),
                                           items: ordered, scope: scope)
    }

    private func copy(_ scope: ListClipboardFormatter.Scope) {
        let ordered = listViewModel.visibleSectionsIgnoringFilter.flatMap(\.items)
        let count = ListClipboardFormatter.items(ordered, scope: scope).count
        UIPasteboard.general.string = copyText(scope)
        listViewModel.noteListCopied(count: count)
        let result = CopyResult(count: count, scope: scope)
        activeOverlay = nil
        withAnimation(motion(.spring(response: 0.35, dampingFraction: 0.82))) { copied = result }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copied?.id == result.id {
                withAnimation(motion(.spring(response: 0.35, dampingFraction: 0.82))) { copied = nil }
            }
        }
    }

    private func stageDeletion(_ scope: ListViewModel.DeletionScope) {
        activeOverlay = nil
        listViewModel.stageDeletion(scope)
    }

    private func handleMenu(_ item: ListMenuItem) {
        activeOverlay = nil
        switch item {
        case .members:
            if let list = listViewModel.defaultList { activeSheet = .shareMembers(list) }
        case .manageItems: openManageItems()
        case .manageCategories: activeSheet = .manageCategories
        case .receipt: openReceiptCapture()
        case .importClipboard: activeSheet = .importClipboard
        case .settings: activeSheet = .settings
        }
    }
}
