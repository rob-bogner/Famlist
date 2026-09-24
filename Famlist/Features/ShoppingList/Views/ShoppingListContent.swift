/*
 ShoppingListContent.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Scrollender Inhalt der Liste im vertikalen Rhythmus des Designs:
   Top-Bar → 18 → Suchfeld → 18 → Fortschritt → 18 → Tabs → 16 → Sektions-Kopf → 12 → Karten (12 Abstand).
   Ersetzt ListView (SwiftUI.List mit System-Wischaktionen).

 🔰 Notes for Beginners:
 - Offene Artikel stehen nach Kategorie gruppiert, abgehakte in einem eigenen Abschnitt darunter.
   Welche Abschnitte sichtbar sind, bestimmt der Tab-Filter (visibleOpenGroups / visibleCheckedItems).
 - Alle Aktionen gehen direkt an das ListViewModel (Offline-First: erst lokal, dann SyncEngine).
 - Sheets öffnet nicht diese View, sondern ShoppingListView über die Callbacks.

 📝 Last Change:
 - Initial creation (Hybrid-Redesign).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Scroll column of the shopping list screen.
struct ShoppingListContent<MoreMenu: View>: View {
    @EnvironmentObject var listViewModel: ListViewModel
    let t: ListTheme
    @Binding var openRow: OpenSwipeRow?
    var onSearch: () -> Void = {}
    var onShowLists: () -> Void = {}
    var onEdit: (ItemModel) -> Void = { _ in }
    var onShowImage: (ItemModel) -> Void = { _ in }
    @ViewBuilder let moreMenu: () -> MoreMenu

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ListTopBar(t: t, title: listViewModel.defaultList?.title ?? String(localized: "shoppingList.title"),
                       onShowLists: onShowLists, moreMenu: moreMenu)
            ListSearchBar(t: t, action: onSearch)
                .padding(.top, 18)
            ProgressHero(t: t, checked: listViewModel.checkedItemCount, total: listViewModel.totalItemCount)
                .padding(.top, 18)
            ListFilterTabs(t: t, selection: $listViewModel.itemFilter)
                .padding(.top, 18)
            openSections
            checkedSection
            if listViewModel.isLoadingNextPage {
                ProgressView()                      // FAM-40: nächste Seite wird geladen
                    .tint(t.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
            if showsEmptyState {
                emptyState
                    .padding(.top, 40)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: listViewModel.items)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: listViewModel.itemFilter)
    }

    // MARK: - Sections

    @ViewBuilder
    private var openSections: some View {
        ForEach(listViewModel.visibleOpenGroups, id: \.category) { group in
            ListSectionHeader(t: t, kind: .category(group.category), count: group.items.count) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    listViewModel.checkAllItems(in: group.category)
                }
            }
            .padding(.top, 16)
            ForEach(group.items) { item in
                row(for: item)
                    .padding(.top, 12)
            }
        }
    }

    @ViewBuilder
    private var checkedSection: some View {
        let checked = listViewModel.visibleCheckedItems
        if !checked.isEmpty {
            ListSectionHeader(t: t, kind: .checked, count: checked.count)
                .padding(.top, 16)
            ForEach(checked) { item in
                row(for: item)
                    .padding(.top, 12)
            }
        }
    }

    /// Letzte sichtbare Karte (Abgehakte stehen unten, sonst die letzte offene).
    private var lastVisibleItemId: String? {
        listViewModel.visibleCheckedItems.last?.id ?? listViewModel.visibleOpenGroups.last?.items.last?.id
    }

    private func row(for item: ItemModel) -> some View {
        SwipeableItemRow(
            t: t,
            item: item,
            openRow: $openRow,
            onToggleChecked: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { listViewModel.toggleItemChecked(item) }
            },
            onDelete: {
                withAnimation(.easeInOut(duration: 0.3)) { listViewModel.deleteItem(item) }
            },
            onEdit: { onEdit(item) },
            onToggleUnavailable: { listViewModel.toggleItemUnavailable(item) },
            onTapImage: { onShowImage(item) },
            isRecentlySynced: listViewModel.recentlySyncedItemIDs.contains(item.id),
            onRetry: { listViewModel.retryItem(item) }
        )
        .id("\(item.isChecked ? "checked" : "open")-\(item.id)") // eigene Identität je Abschnitt
        .onAppear {
            // FAM-40: nächste Seite laden, sobald die letzte sichtbare Karte erscheint.
            if item.id == lastVisibleItemId && listViewModel.hasMoreItems {
                Task { await listViewModel.loadNextPage() }
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale(scale: 0.9))))
    }

    // MARK: - Empty State

    private var showsEmptyState: Bool {
        listViewModel.visibleOpenGroups.isEmpty && listViewModel.visibleCheckedItems.isEmpty
    }

    private var emptyTexts: (title: String, message: String) {
        if listViewModel.items.isEmpty {
            return ("Deine Liste ist leer", "Tippe auf +, um den ersten Artikel hinzuzufügen.")
        }
        switch listViewModel.itemFilter {
        case .open: return ("Alles erledigt", "Auf dieser Liste sind keine offenen Artikel mehr.")
        case .done, .all: return ("Noch nichts abgehakt", "Abgehakte Artikel erscheinen hier.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text(emptyTexts.title)
                .font(AppFont.outfit(20, 600))
                .foregroundStyle(t.text)
            Text(emptyTexts.message)
                .font(AppFont.dm(15, 500))
                .foregroundStyle(t.sub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
