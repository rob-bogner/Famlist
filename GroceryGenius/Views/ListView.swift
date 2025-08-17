// MARK: - ListView.swift

/*
 File: ListView.swift
 Project: GroceryGenius
 Created: 08.01.2024
 Last Updated: 17.08.2025

 Overview:
 Displays all shopping list items grouped into unchecked and checked sections with swipe actions for edit, delete and (un)check operations.

 Responsibilities / Includes:
 - Renders unchecked items with trailing & leading swipe actions
 - Renders checked items in a collapsible style (only shown if any exist)
 - Presents EditItemView sheet for selected item
 - Maintains selected item state in ViewModel

 Design Notes:
 - Uses EnvironmentObject for shared ListViewModel state
 - Swipe actions separated by edge (leading: state toggle, trailing: destructive/edit)
 - Sheet uses presentation detents for adaptive height

 Possible Enhancements:
 - Add section collapsing for checked items
 - Provide multi-select batch actions (delete / uncheck)
 - Integrate search / filtering
*/

import SwiftUI

struct ListView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @State private var showEditItemView: Bool = false

    var body: some View {
        List {
            uncheckedItemsSection
            checkedItemsSection
        }
        .listStyle(PlainListStyle())
        .sheet(isPresented: $showEditItemView) {
            if let selectedItem = listViewModel.selectedItem {
                EditItemView(item: selectedItem)
                    .environmentObject(listViewModel)
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationCornerRadius(15)
            }
        }
    }

    // MARK: - Unchecked Items
    private var uncheckedItemsSection: some View {
        ForEach(listViewModel.uncheckedItems) { item in
            ListRowView(item: item)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.theme.background)
                .swipeActions(allowsFullSwipe: false) {
                    Button(String(localized: "swipe.notAvailable"), systemImage: "minus.circle") {}
                        .tint(.orange)
                    Button(String(localized: "swipe.edit"), systemImage: "pencil.circle") {
                        listViewModel.selectedItem = item
                        showEditItemView = true
                    }
                    .tint(.blue)
                    Button(String(localized: "swipe.delete"), systemImage: "trash.circle", role: .destructive) {
                        withAnimation { listViewModel.deleteItem(item) }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button(String(localized: "swipe.check"), systemImage: "checkmark.circle") {
                        withAnimation { listViewModel.toggleItemChecked(item) }
                    }
                    .tint(.green)
                }
        }
    }

    // MARK: - Checked Items
    private var checkedItemsSection: some View {
        Group {
            if listViewModel.checkedItemCount > 0 {
                Section(header: SectionHeader(title: String(localized: "section.checkedItems.title"))) {
                    ForEach(listViewModel.checkedItems) { item in
                        ListRowView(item: item)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.theme.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(String(localized: "swipe.uncheck"), systemImage: "arrow.uturn.backward.circle") {
                                    withAnimation { listViewModel.toggleItemChecked(item) }
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(String(localized: "swipe.delete"), systemImage: "trash.circle") {
                                    withAnimation { listViewModel.deleteItem(item) }
                                }
                                .tint(.red)
                            }
                    }
                }
            }
        }
    }
}

#Preview { ListView().environmentObject(ListViewModel()) }
