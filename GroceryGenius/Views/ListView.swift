/*
GroceryGenius
ListView.swift
Created by Robert Bogner on 08.01.24.

Presents a detailed view of the items list, allowing interaction through swipe actions.
*/

import SwiftUI

/// A view for displaying the list of items, both checked and unchecked.
struct ListView: View {
    
    // MARK: - Properties
    
    /// ViewModel providing the data and logic for the list.
    @EnvironmentObject var listViewModel: ListViewModel
    
    /// State to control the presentation of the EditItemView.
    @State private var showEditItemView: Bool = false
    
    // MARK: - Body
    
    /// The main content view displaying the list of items.
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
                    .presentationDetents([.fraction(0.45)])
                    .presentationCornerRadius(15)
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Section displaying unchecked items.
    /// Iterates through items that are not checked and presents them using `ListRowView`.
    private var uncheckedItemsSection: some View {
        ForEach(listViewModel.uncheckedItems) { item in
            ListRowView(item: item)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.theme.background)
                .swipeActions(allowsFullSwipe: false) {
                    Button("Not available", systemImage: "minus.circle") {
                        print("Not available")
                    }
                    .tint(.orange)
                    
                    Button("Edit", systemImage: "pencil.circle") {
                        listViewModel.selectedItem = item
                        showEditItemView = true
                    }
                    .tint(.blue)
                    
                    Button("Delete", systemImage: "trash.circle", role: .destructive) {
                        withAnimation {
                            listViewModel.deleteItem(item)
                        }
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("Check", systemImage: "checkmark.circle") {
                        withAnimation {
                            listViewModel.toggleItemChecked(item)
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
                Section(header: Text("Checked Items")) {
                    ForEach(listViewModel.checkedItems) { item in
                        ListRowView(item: item)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.theme.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Uncheck", systemImage: "arrow.uturn.backward.circle") {
                                    withAnimation {
                                        listViewModel.toggleItemChecked(item)
                                    }
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button("Delete", systemImage: "trash.circle") {
                                    withAnimation {
                                        listViewModel.deleteItem(item)
                                    }
                                }
                                .tint(.red)
                            }
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    ListView()
        .environmentObject(ListViewModel())
}
