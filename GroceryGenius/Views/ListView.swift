/*
GroceryGenius
ListView.swift
Created by Robert Bogner on 08.01.24.

Presents a detailed view of the items list, allowing interaction through swipe actions.
*/

import SwiftUI

/// A view for displaying the list of items, both checked and unchecked.
struct ListView: View {
    
    @EnvironmentObject var listViewModel: ListViewModel // ViewModel providing the data and logic for the list.
    @State private var showEditItemView: Bool = false // State to control the presentation of the EditItemView.

    var body: some View {
        List {
            uncheckedItemsSection // Section displaying items that are not checked.
            checkedItemsSection // Section displaying items that are checked.
        }
        .listStyle(PlainListStyle()) // Sets the list to a plain style for a more standard look.
        .sheet(isPresented: $showEditItemView) {
            // Presents the EditItemView as a modal sheet when an item is selected for editing.
            if let selectedItem = listViewModel.selectedItem {
                EditItemView(item: selectedItem)
                    .environmentObject(listViewModel) // Passes the ListViewModel to the EditItemView.
                    .presentationDetents([.height(400)])
                    .presentationCornerRadius(15)
            }
        }
    }

    /// Section displaying unchecked items.
    /// Iterates through items that are not checked and presents them using `ListRowView`.
    private var uncheckedItemsSection: some View {
        ForEach(listViewModel.uncheckedItems) { item in
            ListRowView(item: item) // Custom view for displaying a single list item.
                .listRowSeparator(.hidden) // Hides the row separator for a cleaner look.
                .listRowBackground(Color.theme.background) // Sets the background color for the row.
                .swipeActions(allowsFullSwipe: false) {
                    // Swipe actions allow additional functionalities like edit and delete.
                    Button("Not available", systemImage: "minus.circle") {
                        print("Not available") // Placeholder action. Update as needed.
                    }
                    .tint(.orange)
                    Button("Edit", systemImage: "pencil.circle") {
                        listViewModel.selectedItem = item // Sets the selected item for editing.
                        showEditItemView = true // Triggers the presentation of the EditItemView.
                    }
                    .tint(.blue)
                    Button("Delete", systemImage: "trash.circle", role: .destructive) {
                        withAnimation {
                            listViewModel.deleteItem(item) // Deletes the item from the list.
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("Check", systemImage: "checkmark.circle") {
                        withAnimation {
                            listViewModel.toggleItemChecked(item) // Toggles the checked status of the item.
                        }
                    }
                    .tint(.green)
                }
        }
    }

    /// Section displaying checked items.
    /// Displays only if there are checked items in the list, to keep track of checked items.
    private var checkedItemsSection: some View {
        Group {
            if listViewModel.checkedItemCount > 0 {
                Section(header: Text("Checked Items")) { // Header for the checked items section.
                    ForEach(listViewModel.checkedItems) { item in
                        ListRowView(item: item) // View for each checked list item.
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.theme.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Uncheck", systemImage: "arrow.uturn.backward.circle") {
                                    withAnimation {
                                        listViewModel.toggleItemChecked(item) // Allows unchecking of an item.
                                    }
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Delete", systemImage: "trash.circle") {
                                    withAnimation {
                                        listViewModel.deleteItem(item) // Enables deletion of a checked item.
                                    }
                                }
                                .tint(.red)
                            }
                    }
                }
            } else {
                EmptyView() // Shows an empty view when there are no checked items, simplifying the user interface.
            }
        }
    }
}

#Preview {
    ListView()
        .environmentObject(ListViewModel()) // Preview setup with a ListViewModel.
}
