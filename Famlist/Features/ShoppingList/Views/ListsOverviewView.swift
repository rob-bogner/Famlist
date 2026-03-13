/*
 ListsOverviewView.swift

 Famlist
 Created on: 13.03.2026
 Last updated on: 13.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Übersicht aller Listen des Nutzers (FAM-34).
 - Listen-Management: Umbenennen, Löschen, Als Standard setzen (FAM-35).

 🛠 Includes:
 - CustomModalView-Shell (identisch zu AddItemView-Design).
 - SwiftUI.List mit Swipe-Aktionen und Long-Press Context Menu.
 - PrimaryButton "Neue Liste" am unteren Rand.
 - Alert für Neue Liste und Umbenennen.
 - ConfirmationDialog vor dem Löschen.

 🔰 Notes for Beginners:
 - Wird als Sheet von ShoppingListView präsentiert.
 - Nutzt @EnvironmentObject ListViewModel für alle Operationen.
 - Offline-First: alle Änderungen via ListViewModel, nicht direkt ans Repository.

 📝 Last Change:
 - Design auf CustomModalView umgestellt (gleiche Designsprache wie AddItemView).
 ------------------------------------------------------------------------
 */

import SwiftUI

/// Präsentiert alle Listen des Nutzers und ermöglicht Wechsel sowie Verwaltung.
struct ListsOverviewView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateAlert = false

    @State private var showRenameAlert = false
    @State private var listToRename: ListModel?

    @State private var listToDelete: ListModel?

    var body: some View {
        CustomModalView(title: "Meine Listen", onClose: { dismiss() }) {
            VStack(spacing: 0) {
                if listViewModel.allLists.isEmpty {
                    emptyStateView
                } else {
                    listsContent
                }

                PrimaryButton(title: "Neue Liste erstellen") {
                    showCreateAlert = true
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showCreateAlert) {
            ListNameInputSheet(
                title: "Neue Liste",
                placeholder: "Listenname",
                confirmLabel: "Erstellen",
                initialValue: ""
            ) { name in
                guard let ownerId = listViewModel.defaultList?.ownerId else { return }
                listViewModel.createNewList(title: name, ownerId: ownerId)
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRenameAlert) {
            ListNameInputSheet(
                title: "Umbenennen",
                placeholder: "Listenname",
                confirmLabel: "Speichern",
                initialValue: listToRename?.title ?? ""
            ) { name in
                if let list = listToRename {
                    listViewModel.renameList(list, to: name)
                }
                listToRename = nil
            }
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: Binding(
                get: { listToDelete != nil },
                set: { if !$0 { listToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            deleteDialogActions
        }
        .onAppear {
            if let ownerId = listViewModel.defaultList?.ownerId {
                listViewModel.loadAllLists(ownerId: ownerId)
            }
        }
    }

    // MARK: - Content Views

    private var listsContent: some View {
        SwiftUI.List {
            ForEach(listViewModel.allLists) { list in
                ListsOverviewRow(
                    list: list,
                    itemCount: listViewModel.listItemCounts[list.id] ?? 0,
                    isActive: list.id == listViewModel.listId
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    listViewModel.switchToList(list)
                    dismiss()
                }
                .contextMenu {
                    Button {
                        listToRename = list
                        showRenameAlert = true
                    } label: {
                        Label("Umbenennen", systemImage: "pencil")
                    }

                    if !list.isDefault {
                        Button {
                            listViewModel.setDefaultList(list)
                        } label: {
                            Label("Als Standard setzen", systemImage: "star")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        listToDelete = list
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    trailingSwipeActions(for: list)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    leadingSwipeActions(for: list)
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.below.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Keine Listen vorhanden")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Erstelle deine erste Liste mit dem Button unten.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func trailingSwipeActions(for list: ListModel) -> some View {
        Button(role: .destructive) {
            listToDelete = list
        } label: {
            Label("Löschen", systemImage: "trash")
        }

        Button {
            listToRename = list
            showRenameAlert = true
        } label: {
            Label("Umbenennen", systemImage: "pencil")
        }
        .tint(.orange)
    }

    @ViewBuilder
    private func leadingSwipeActions(for list: ListModel) -> some View {
        if !list.isDefault {
            Button {
                listViewModel.setDefaultList(list)
            } label: {
                Label("Standard", systemImage: "star.fill")
            }
            .tint(.yellow)
        }
    }

    // MARK: - Alerts & Dialogs

    private var deleteDialogTitle: String {
        guard let list = listToDelete else { return "" }
        return "'\(list.title)' löschen?"
    }

    @ViewBuilder
    private var deleteDialogActions: some View {
        Button("Löschen", role: .destructive) {
            if let list = listToDelete {
                let wasActive = listViewModel.listId == list.id
                listViewModel.deleteList(list)
                if wasActive { dismiss() }
            }
            listToDelete = nil
        }
        Button("Abbrechen", role: .cancel) {
            listToDelete = nil
        }
    }
}

// MARK: - ListsOverviewRow

/// Einzelne Zeile in der Listen-Übersicht.
struct ListsOverviewRow: View {
    let list: ListModel
    let itemCount: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "list.bullet.circle.fill" : "list.bullet.circle")
                .font(.system(size: 28))
                .foregroundColor(isActive ? Color.accentColor : .secondary)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(list.title)
                        .font(.body.weight(list.isDefault ? .semibold : .regular))
                    if list.isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
                Text(itemCountLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var itemCountLabel: String {
        switch itemCount {
        case 0: return "Keine Artikel"
        case 1: return "1 Artikel"
        default: return "\(itemCount) Artikel"
        }
    }
}

// MARK: - ListNameInputSheet

/// Eingabe-Sheet für Listen-Namen – gleiche Designsprache wie AddItemView.
private struct ListNameInputSheet: View {
    let title: String
    let placeholder: String
    let confirmLabel: String
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String
    @FocusState private var isFocused: Bool

    init(title: String, placeholder: String, confirmLabel: String, initialValue: String, onConfirm: @escaping (String) -> Void) {
        self.title = title
        self.placeholder = placeholder
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
        _inputText = State(initialValue: initialValue)
    }

    var body: some View {
        CustomModalView(title: title, onClose: { dismiss() }) {
            VStack(spacing: 16) {
                TextField(placeholder, text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .padding(.horizontal)
                    .padding(.top, 24)

                Spacer()

                PrimaryButton(title: confirmLabel) {
                    let trimmed = inputText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onConfirm(trimmed)
                    dismiss()
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Preview

#Preview {
    let listVM = PreviewMocks.makeListViewModelWithSamples()
    listVM.allLists = [
        ListModel(id: UUID(), ownerId: UUID(), title: "Wocheneinkauf", isDefault: true, createdAt: Date(), updatedAt: Date()),
        ListModel(id: UUID(), ownerId: UUID(), title: "Drogerie", isDefault: false, createdAt: Date(), updatedAt: Date()),
        ListModel(id: UUID(), ownerId: UUID(), title: "Baumarkt", isDefault: false, createdAt: Date(), updatedAt: Date())
    ]
    return ListsOverviewView()
        .environmentObject(listVM)
}
