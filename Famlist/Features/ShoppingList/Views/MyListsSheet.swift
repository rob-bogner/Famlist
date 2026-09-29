/*
 MyListsSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hybrid-Sheet „Meine Listen“ (Designhöhe 790): Anzahl, Listen-Karten, „Neue Liste erstellen“.

 🔰 Notes for Beginners:
 - Vorlage: MyListsScreen in design-handoff/MyListUI/Screens/MyListsScreen.swift (MyLists.dc.html).
 - Tippen wechselt die Liste. Langer Druck öffnet die Listen-Optionen (Umbenennen, Duplizieren,
   Favorit, Mitglieder & Teilen, Löschen/Verlassen). Alle Listen-Aktionen gibt es NUR dort (SPEC §3.6).

 📝 Last Change:
 - 29.09.2026: Wisch-Aktionen wie bei Artikeln (SwipeableListRow) + „Rückgängig“ nach Löschen/Verlassen;
   langer Druck → Listen-Optionen bleibt.
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Hybrid "Meine Listen" sheet.
struct MyListsSheet: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @EnvironmentObject var session: AppSessionViewModel

    let k: SheetTheme
    let maxHeight: CGFloat
    let onClose: () -> Void
    var onCreate: () -> Void = {}
    var onOptions: (ListModel) -> Void = { _ in }
    /// Wisch-Aktionen (Design: MyListsSwipeLeft/-Right): Umbenennen, Duplizieren, Mitglieder.
    var onRename: (ListModel) -> Void = { _ in }
    var onDuplicate: (ListModel) -> Void = { _ in }
    var onMembers: (ListModel) -> Void = { _ in }

    @State private var openRow: OpenSwipeRow?

    private var lists: [ListModel] { listViewModel.allLists }
    private var currentUserId: UUID? { session.currentProfile?.id }

    var body: some View {
        HybridSheetLayer(k: k, title: "Meine Listen", designHeight: 790, maxHeight: maxHeight, onClose: onClose) {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        countLabel
                        if lists.isEmpty { emptyState }
                        ForEach(lists) { card(for: $0) }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 128)   // Platz unter dem Button
                }
                .scrollIndicators(.hidden)

                CTAButton(title: "Neue Liste erstellen", k: k, action: onCreate)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)

                // „„Drogerie“ gelöscht“ + Rückgängig (MyListsUndo): 14 über dem Knopf
                if let pending = listViewModel.pendingListRemoval {
                    undoToast(pending)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 34 + 56 + 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: listViewModel.pendingListRemoval?.id)
        }
        .onAppear(perform: loadLists)
    }

    // MARK: - Parts

    private var countLabel: some View {
        Text(lists.count == 1 ? "1 Liste" : "\(lists.count) Listen")
            .font(AppFont.dm(13, 600))
            .tracking(0.52)                              // 0.04em × 13
            .textCase(.uppercase)
            .foregroundStyle(k.sub)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Text("Noch keine Listen. Lege unten deine erste Liste an.")
            .font(AppFont.dm(15, 500))
            .foregroundStyle(k.sub)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    private func card(for list: ListModel) -> some View {
        let isOwner = currentUserId == nil || list.ownerId == currentUserId
        let isActive = list.id == listViewModel.listId
        let isFavorite = session.isFavorite(list)
        // Wisch-Aktionen wie bei Artikeln; Tippen öffnet, langer Druck zeigt die Listen-Optionen.
        return SwipeableListRow(k: k, id: list.id.uuidString, isFavorite: isFavorite, isOwner: isOwner, openRow: $openRow,
                                onTap: { select(list) },
                                onLongPress: { onOptions(list) },
                                onToggleFavorite: { session.toggleFavorite(list) },
                                onDelete: { remove(list, isOwner: isOwner) },
                                onRename: { onRename(list) },
                                onDuplicate: { onDuplicate(list) },
                                onMembers: { onMembers(list) }) {
            ListSummaryCard(k: k, list: list,
                            itemCount: listViewModel.listItemCounts[list.id] ?? 0,
                            isSelected: isActive,
                            isShared: !isOwner,
                            isFavorite: isFavorite)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isActive ? "\(list.title), aktive Liste" : "\(list.title) öffnen")
                .accessibilityAction(named: "Listen-Optionen") { onOptions(list) }
        }
    }

    /// Hinweis mit Restzeit-Balken (5 s), gleiche Gestaltung wie beim Löschen von Artikeln.
    private func undoToast(_ pending: PendingListRemoval) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let left = pending.deadline.timeIntervalSince(context.date)
            UndoToast(k: OverlayTheme(k.appearance), message: pending.message,
                      remaining: CGFloat(max(0, min(1, left / PendingListRemoval.undoDuration))),
                      onUndo: { listViewModel.undoListRemoval() })
        }
    }

    // MARK: - Actions

    private func loadLists() {
        if let ownerId = currentUserId ?? listViewModel.defaultList?.ownerId {
            listViewModel.loadAllLists(ownerId: ownerId)
        }
    }

    /// Wisch-Aktion „Löschen“ / „Verlassen“: ohne Rückfrage, dafür 5 s „Rückgängig“.
    private func remove(_ list: ListModel, isOwner: Bool) {
        if isOwner {
            listViewModel.stageListRemoval(list, kind: .delete)
        } else if let me = currentUserId {
            listViewModel.stageListRemoval(list, kind: .leave(profileId: me))
        }
    }

    private func select(_ list: ListModel) {
        if list.id != listViewModel.listId { listViewModel.switchToList(list) }
        onClose()
    }
}

#Preview {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    listVM.allLists = [
        ListModel(id: listVM.listId, ownerId: UUID(), title: "Wocheneinkauf", isDefault: true, createdAt: Date(), updatedAt: Date()),
        ListModel(id: UUID(), ownerId: UUID(), title: "Drogerie", isDefault: false, createdAt: Date(), updatedAt: Date())
    ]
    let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                      lists: PreviewListsRepository(), listViewModel: listVM)
    return ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        MyListsSheet(k: SheetTheme(.light), maxHeight: 790, onClose: {})
    }
    .ignoresSafeArea()
    .environmentObject(listVM)
    .environmentObject(session)
}

#Preview("Dark") {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    listVM.allLists = [
        ListModel(id: listVM.listId, ownerId: UUID(), title: "Wocheneinkauf", isDefault: true, createdAt: Date(), updatedAt: Date()),
        ListModel(id: UUID(), ownerId: UUID(), title: "Drogerie", isDefault: false, createdAt: Date(), updatedAt: Date())
    ]
    let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                      lists: PreviewListsRepository(), listViewModel: listVM)
    return ZStack(alignment: .bottom) {
        Color.black.opacity(0.4)
        MyListsSheet(k: SheetTheme(.dark), maxHeight: 790, onClose: {})
    }
    .ignoresSafeArea()
    .environmentObject(listVM)
    .environmentObject(session)
}
