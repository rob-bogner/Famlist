// MARK: - ListView.swift

/*
 ListView.swift

 GroceryGenius
 Created on: 08.01.2024
 Last updated on: 26.04.2025

 ------------------------------------------------------------------------
 📄 File Overview:

 This file defines the main view for displaying all items in the shopping list,
 both checked and unchecked. It includes swipe actions for editing, deleting,
 and toggling the check state of each item.

 🛠 Includes:
 - Display of unchecked items with swipe actions (edit, delete, check)
 - Display of checked items with swipe actions (uncheck, delete)
 - Modal sheet for editing selected items

 🔰 Notes for Beginners:
 - `@EnvironmentObject` injects shared ViewModel data.
 - `.swipeActions` provides contextual actions when swiping list rows.
 - `.sheet` displays a modal to edit existing items.
 ------------------------------------------------------------------------
*/

import SwiftUI // Provides the basic building blocks for the user interface

/// A view for displaying the list of items, both checked and unchecked.
struct ListView: View {
    
    // MARK: - Properties
    
    /// ViewModel providing the data and logic for the list.
    @EnvironmentObject var listViewModel: ListViewModel // Injects the shared ViewModel for accessing and modifying list data
    
    /// State to control the presentation of the EditItemView.
    @State private var showEditItemView: Bool = false // Controls whether the edit modal sheet is shown
    
    // MARK: - Body
    
    /// The main content view displaying the list of items.
    var body: some View {
        List { // Creates a scrolling list
            uncheckedItemsSection // Displays items that are not checked
            checkedItemsSection // Displays items that are checked
        }
        .listStyle(PlainListStyle()) // Removes the default list styling
        .sheet(isPresented: $showEditItemView) { // Presents a modal to edit an item
            if let selectedItem = listViewModel.selectedItem {
                EditItemView(item: selectedItem) // Edit view for the selected item
                    .environmentObject(listViewModel) // Passes ViewModel to the edit view
                    .presentationDetents([.fraction(0.75), .large])  // Sets sheet height to 45% of screen
                    .presentationCornerRadius(15) // Smooth rounded sheet corners
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Section displaying unchecked items.
    /// Iterates through items that are not checked and presents them using `ListRowView`.
    private var uncheckedItemsSection: some View {
        ForEach(listViewModel.uncheckedItems) { item in // Loop over unchecked items
            ListRowView(item: item) // Shows each item row
                .listRowSeparator(.hidden) // Hides the separator line between list rows
                .listRowBackground(Color.theme.background) // Sets custom background color
                .swipeActions(allowsFullSwipe: false) { // Trailing swipe actions
                    Button("Not available", systemImage: "minus.circle") {
                        print("Not available") // Currently placeholder action
                    }
                    .tint(.orange) // Sets button color to orange
                    
                    Button("Edit", systemImage: "pencil.circle") {
                        listViewModel.selectedItem = item // Sets the selected item
                        showEditItemView = true // Opens the EditItemView
                    }
                    .tint(.blue) // Sets button color to blue
                    
                    Button("Delete", systemImage: "trash.circle", role: .destructive) {
                        withAnimation {
                            listViewModel.deleteItem(item) // Deletes the item with animation
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) { // Leading swipe action
                    Button("Check", systemImage: "checkmark.circle") {
                        withAnimation {
                            listViewModel.toggleItemChecked(item) // Toggles the check status
                        }
                    }
                    .tint(.green) // Sets button color to green
                }
        }
    }
    
    /// Section displaying checked items.
    /// Displays only if there are checked items in the list, to keep track of checked items.
    private var checkedItemsSection: some View {
        Group {
            if listViewModel.checkedItemCount > 0 { // Only show if there are checked items
                Section(header: SectionHeader(title: "Checked Items")) {
                    ForEach(listViewModel.checkedItems) { item in // Loop over checked items
                        ListRowView(item: item) // Shows each checked item row
                            .listRowSeparator(.hidden) // Hide separator
                            .listRowBackground(Color.theme.background) // Set background color
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) { // Trailing swipe action
                                Button("Uncheck", systemImage: "arrow.uturn.backward.circle") {
                                    withAnimation {
                                        listViewModel.toggleItemChecked(item) // Unchecks the item
                                    }
                                }
                                .tint(.yellow) // Sets button color to yellow
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) { // Leading swipe action
                                Button("Delete", systemImage: "trash.circle") {
                                    withAnimation {
                                        listViewModel.deleteItem(item) // Deletes the item
                                    }
                                }
                                .tint(.red) // Sets button color to red
                            }
                    }
                }
            } else {
                EmptyView() // If no checked items, displays nothing
            }
        }
    }
}

#Preview {
    /// Provides a preview of the ListView with an example environment object.
    ListView()
        .environmentObject(ListViewModel()) // Injects a sample ViewModel for preview
}
