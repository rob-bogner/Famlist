/*
 ShoppingListContent.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Scrollender Inhalt der Liste im vertikalen Rhythmus des Designs:
   Kopfzeile → 18 → Suchfeld → 18 → Fortschritt → 18 → Tabs → 16 → Sektions-Kopf → 12 → Karten (12 Abstand).
   Leere Liste: Tabs → 44 → ListEmptyState.

 🔰 Notes for Beginners:
 - Welche Abschnitte es gibt, bestimmt ListViewModel.visibleSections (Sortierung + Tab-Filter).
 - Sortierung „Manuell“: Karten lassen sich per langem Druck ziehen (onDrag/onDrop).
 - Alle Aktionen gehen direkt an das ListViewModel (Offline-First: erst lokal, dann SyncEngine).
 - Sheets und Overlays öffnet nicht diese View, sondern ShoppingListView über die Callbacks.

 📝 Last Change:
 - Abschnitte über ListSectionBuilder, Leer-Zustand aus dem Handoff, Ziehen bei „Manuell“.
 ------------------------------------------------------------------------
 */

import SwiftUI
import UniformTypeIdentifiers

/// Scroll column of the shopping list screen.
struct ShoppingListContent: View {
    @EnvironmentObject var listViewModel: ListViewModel
    let t: ListTheme
    @Binding var openRow: OpenSwipeRow?
    var onSearch: () -> Void = {}
    var onScan: () -> Void = {}
    var onShowLists: () -> Void = {}
    var onMenu: () -> Void = {}
    var onEdit: (ItemModel) -> Void = { _ in }
    var onShowImage: (ItemModel) -> Void = { _ in }

    @State private var draggingId: String?
    /// Einstellungen → Liste → „Preise anzeigen“ (Summe in der Fortschrittskarte).
    @AppStorage(PriceDisplaySetting.storageKey) private var showPrices = PriceDisplaySetting.defaultValue


    var body: some View {
        let sections = listViewModel.visibleSections
        LazyVStack(alignment: .leading, spacing: 0) {
            ListTopBar(t: t, title: listViewModel.defaultList?.title ?? String(localized: "shoppingList.title"),
                       onShowLists: onShowLists, onMenu: onMenu)
            ListSearchBar(t: t, action: onSearch, onScan: onScan)
                .padding(.top, 18)
            ProgressHero(t: t, checked: listViewModel.checkedItemCount, total: listViewModel.totalItemCount,
                         totalPrice: showPrices ? PriceDisplaySetting.total(of: listViewModel.items) : nil)
                .padding(.top, 18)
            ListFilterTabs(t: t, selection: $listViewModel.itemFilter)
                .padding(.top, 18)
            if listViewModel.items.isEmpty && !listViewModel.isLoadingNextPage {
                ListEmptyState(t: t)
                    .padding(.top, 44)                 // gap 18 + margin-top 26
            } else {
                ForEach(sections) { section in
                    sectionView(section, isLast: section.id == sections.last?.id)
                }
                if sections.isEmpty {
                    filterEmptyState
                        .padding(.top, 40)
                }
            }
            if listViewModel.isLoadingNextPage {
                ProgressView()                      // FAM-40: nächste Seite wird geladen
                    .tint(t.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: listViewModel.items)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: listViewModel.itemFilter)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: listViewModel.sortSettings)
    }

    // MARK: - Sections

    @ViewBuilder
    private func sectionView(_ section: ListSection, isLast: Bool) -> some View {
        switch section.kind {
        case .category(let category):
            ListSectionHeader(t: t, kind: .category(category), count: section.items.count) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    listViewModel.checkAllItems(in: category.name)
                }
            }
            .padding(.top, 16)
        case .checked:
            ListSectionHeader(t: t, kind: .checked, count: section.items.count)
                .padding(.top, 16)
        case .flat:
            EmptyView()
        }
        ForEach(section.items) { item in
            row(for: item, isLastVisible: isLast && item.id == section.items.last?.id)
                .padding(.top, section.kind == .flat && item.id == section.items.first?.id ? 16 : 12)
        }
    }

    private func row(for item: ItemModel, isLastVisible: Bool) -> some View {
        SwipeableItemRow(
            t: t,
            item: item,
            openRow: $openRow,
            onToggleChecked: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { listViewModel.toggleItemChecked(item) }
            },
            onDelete: {
                openRow = nil
                listViewModel.stageDeletion(of: item)       // Rückgängig-Toast (5 s) statt sofort löschen
            },
            onEdit: { onEdit(item) },
            onToggleUnavailable: { listViewModel.toggleItemUnavailable(item) },
            onTapImage: { onShowImage(item) },
            isRecentlySynced: listViewModel.recentlySyncedItemIDs.contains(item.id),
            onRetry: { listViewModel.retryItem(item) }
        )
        .modifier(ManualReorder(enabled: listViewModel.sortSettings.order == .manual,
                                itemId: item.id, draggingId: $draggingId,
                                onMove: { listViewModel.moveItem($0, to: $1) }))
        .onAppear {
            // FAM-40: nächste Seite laden, sobald die letzte sichtbare Karte erscheint.
            if isLastVisible && listViewModel.hasMoreItems {
                Task { await listViewModel.loadNextPage() }
            }
        }
        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .scale(scale: 0.9))))
    }

    // MARK: - Filter Empty State

    /// Tab „Offen“ / „Erledigt“ ohne Treffer (Liste selbst ist nicht leer).
    private var filterTexts: (title: String, message: String) {
        switch listViewModel.itemFilter {
        case .open: return ("Alles erledigt", "Auf dieser Liste sind keine offenen Artikel mehr.")
        case .done, .all: return ("Noch nichts abgehakt", "Abgehakte Artikel erscheinen hier.")
        }
    }

    private var filterEmptyState: some View {
        VStack(spacing: 6) {
            Text(filterTexts.title)
                .font(AppFont.outfit(20, 600))
                .foregroundStyle(t.text)
            Text(filterTexts.message)
                .font(AppFont.dm(15, 500))
                .foregroundStyle(t.sub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Sortierung „Manuell“: langer Druck hebt die Karte an, Ablegen auf einer anderen Karte verschiebt sie.
private struct ManualReorder: ViewModifier {
    let enabled: Bool
    let itemId: String
    @Binding var draggingId: String?
    let onMove: (String, String) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggingId = itemId
                    return NSItemProvider(object: itemId as NSString)
                }
                .onDrop(of: [UTType.text], delegate: ReorderDropDelegate(targetId: itemId,
                                                                        draggingId: $draggingId,
                                                                        onMove: onMove))
        } else {
            content
        }
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let targetId: String
    @Binding var draggingId: String?
    let onMove: (String, String) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingId, draggingId != targetId else { return }
        onMove(draggingId, targetId)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }
}

#Preview("ShoppingListContent", traits: .fixedLayout(width: 390, height: 844)) {
    @Previewable @State var openRow: OpenSwipeRow?
    ZStack {
        ListBackground(t: ListTheme(.light))
        ScrollView {
            ShoppingListContent(t: ListTheme(.light), openRow: $openRow)
                .padding(.horizontal, 20)
        }
    }
    .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}

#Preview("ShoppingListContent – Dark", traits: .fixedLayout(width: 390, height: 844)) {
    @Previewable @State var openRow: OpenSwipeRow?
    ZStack {
        ListBackground(t: ListTheme(.dark))
        ScrollView {
            ShoppingListContent(t: ListTheme(.dark), openRow: $openRow)
                .padding(.horizontal, 20)
        }
    }
    .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
