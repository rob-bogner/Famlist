/*
 MyListsSheet.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hybrid-Sheet „Meine Listen“ (Listenverwaltung), Designhöhe 790:
   Titelzeile → 20 → „n Listen“ 13/600 in Großbuchstaben → 10 → Listen-Karten (Abstand 10)
   → Button „Neue Liste erstellen“ unten 34.

 🔰 Notes for Beginners:
 - Tippen auf eine Karte wechselt die Liste und schließt das Sheet.
 - Umbenennen / Löschen / Als Standard setzen: Wischen oder lange drücken (SwipeableListCard).
 - Löschen und Standard setzen nur für eigene Listen; Löschen immer mit Rückfrage.
 - Offline-First: alle Änderungen laufen über ListViewModel, nie direkt ans Repository.

 📝 Last Change:
 - Ersetzt ListsOverviewView (System-Sheet) durch das Design aus MyListUI 2 („MyListsScreen“).
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
    var onRename: (ListModel) -> Void = { _ in }

    @State private var openRow: OpenSwipeRow?
    @State private var listToDelete: ListModel?

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
            }
        }
        .confirmationDialog(deleteTitle, isPresented: deleteBinding, titleVisibility: .visible,
                            presenting: listToDelete) { list in
            Button("Löschen", role: .destructive) { delete(list) }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Die Liste und alle ihre Artikel werden gelöscht.")
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
        let isOwner = list.ownerId == currentUserId
        return SwipeableListCard(
            k: k, list: list,
            itemCount: listViewModel.listItemCounts[list.id] ?? 0,
            isSelected: list.id == listViewModel.listId,
            isOwner: isOwner,
            isShared: currentUserId != nil && !isOwner,
            openRow: $openRow,
            onSelect: { select(list) },
            onRename: { onRename(list) },
            onDelete: { listToDelete = list },
            onSetDefault: { listViewModel.setDefaultList(list) }
        )
    }

    // MARK: - Actions

    private var deleteTitle: String { "„\(listToDelete?.title ?? "")“ löschen?" }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { listToDelete != nil }, set: { if !$0 { listToDelete = nil } })
    }

    private func loadLists() {
        if let ownerId = currentUserId ?? listViewModel.defaultList?.ownerId {
            listViewModel.loadAllLists(ownerId: ownerId)
        }
    }

    private func select(_ list: ListModel) {
        if list.id != listViewModel.listId { listViewModel.switchToList(list) }
        onClose()
    }

    private func delete(_ list: ListModel) {
        let wasActive = list.id == listViewModel.listId
        withAnimation(.easeInOut(duration: 0.3)) { listViewModel.deleteList(list) }
        listToDelete = nil
        if wasActive { onClose() }
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
