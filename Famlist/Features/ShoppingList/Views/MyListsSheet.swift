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
 - Wischaktionen und Kontextmenü entfernt, langer Druck → Listen-Optionen (Handoff 24.09.2026).
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
        let isActive = list.id == listViewModel.listId
        return ListSummaryCard(k: k, list: list,
                               itemCount: listViewModel.listItemCounts[list.id] ?? 0,
                               isSelected: isActive,
                               isShared: currentUserId != nil && !isOwner,
                               isFavorite: session.isFavorite(list))
            .onTapGesture { select(list) }
            .onLongPressGesture(minimumDuration: 0.45) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOptions(list)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(isActive ? "\(list.title), aktive Liste" : "\(list.title) öffnen")
            .accessibilityAction(named: "Listen-Optionen") { onOptions(list) }
    }

    // MARK: - Actions

    private func loadLists() {
        if let ownerId = currentUserId ?? listViewModel.defaultList?.ownerId {
            listViewModel.loadAllLists(ownerId: ownerId)
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
