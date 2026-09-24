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
 - Initial creation (Redesign „Hybrid“).
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
            if !dockOnTop { dock(t: t, insets: insets) }
            if activeOverlay != nil {
                // OverlayScrim: Weichzeichner 2 liegt auf der Liste, hier nur die Farbe + Tippen schließt
                k.scrim
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeOverlay)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
            if dockOnTop { dock(t: t, insets: insets) }
            overlayContent(insets: insets)
            toasts(insets: insets)
        }
    }

    private func dock(t: ListTheme, insets: LayoutShift) -> some View {
        DockView(appearance: appearance, active: dockActive, pill: dockPill,
                 liveBlur: true,                   // backdrop-filter des Designs: Leiste ist nur zu 78/84 % deckend
                 onCheck: dockCheck, onSort: { toggle(.sort) }, onCopy: { toggle(.copy) },
                 onDelete: { toggle(.delete) }, onAdd: openNewItem)
            .frame(width: 350, height: 64)
            .padding(.leading, 20)
            .padding(.bottom, insets.dockBottom)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .ignoresSafeArea()
            .blur(radius: activeSheet != nil ? 3 : (activeOverlay == .menu ? 2 : 0), opaque: false)
            .allowsHitTesting(activeSheet == nil && activeOverlay != .menu)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: dockActive)
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
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
        case .sort:
            SortMenuScreen(appearance: appearance, settings: listViewModel.sortSettings,
                           onSelect: { listViewModel.setSortOrder($0); UserLog.Data.sortChanged(to: $0.rawValue) },
                           onToggleDoneAtBottom: { listViewModel.setDoneAtBottom($0) },
                           onDismiss: closeOverlay)
                .offset(y: insets.dockShift)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
        case .copy:
            CopyChoiceScreen(appearance: appearance,
                             openCount: listViewModel.uncheckedItems.count,
                             allCount: listViewModel.items.count,
                             previewText: copyText(.open),
                             onSelect: copy, onDismiss: closeOverlay)
                .offset(y: insets.dockShift)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
        case .delete:
            DeleteChoiceScreen(appearance: appearance,
                               checkedCount: listViewModel.checkedItemCount,
                               allCount: listViewModel.items.count,
                               onDeleteChecked: { stageDeletion(.checked) },
                               onDeleteAll: { stageDeletion(.all) },
                               onDismiss: closeOverlay)
                .offset(y: insets.dockShift)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let copied, activeSheet == nil {
            CopyDoneToast(k: k, count: copied.count, scope: copied.scope)
                .padding(.horizontal, 20)
                .padding(.bottom, insets.dockBottom + 78)       // Design: unten 112 bei Dock-Unterkante 34
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { listViewModel.toggleAllItems() }
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
        UserLog.Data.listCopied(title: listViewModel.defaultList?.title ?? "", count: count)
        let result = CopyResult(count: count, scope: scope)
        activeOverlay = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { copied = result }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copied?.id == result.id {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { copied = nil }
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
        case .receipt: break                                    // folgt in Phase 7
        case .importClipboard: showImport = true
        case .settings: activeSheet = .settings
        }
    }
}
