/*
 ListView.swift

 GroceryGenius
 Created on: 08.01.2024
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Displays shopping list items grouped into unchecked and checked sections with swipe actions for edit, delete and (un)check operations.

 🛠 Includes:
 - Unchecked and checked sections, swipe actions, EditItemView sheet presentation, and selected item handling via ViewModel.

 🔰 Notes for Beginners:
 - Uses EnvironmentObject to share the ListViewModel across subviews.
 - Swipe actions let you quickly edit, delete, or toggle check state.

 📝 Last Change:
 - Standardized header and updated Preview to use PreviewMocks for consistent data. No functional changes.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to build declarative interfaces and use property wrappers.


/// Renders the two sections of items (unchecked and checked) with swipe actions and edit sheet.
struct ListView: View { // Declares a SwiftUI view for the list content.
    @EnvironmentObject var listViewModel: ListViewModel // Shared view model providing items and actions.
    @State private var showEditItemView: Bool = false // Controls presentation of the EditItemView sheet.

    var body: some View { // Builds the UI for the list.
        SwiftUI.List { // Uses SwiftUI's List to render rows efficiently.
            uncheckedItemsSection // First show items that are not checked yet.
            checkedItemsSection // Then optionally show items that are already checked.
        }
        .listStyle(PlainListStyle()) // Use plain style for a clean, minimal look.
        .listRowSpacing(DS.List.rowSpacing) // Explicit row spacing for iOS version consistency.
        .environment(\.defaultMinListRowHeight, 0) // Remove minimum row height to prevent unwanted spacing.
        .sheet(isPresented: $showEditItemView) { // Present the edit sheet when toggled on.
            if let selectedItem = listViewModel.selectedItem { // Only show if we have a selected item.
                EditItemView(item: selectedItem) // Inject the selected item into the editor.
                    .environmentObject(listViewModel) // Share the same view model with the editor.
                    .presentationDetents([.fraction(0.75), .large]) // Allow sheet to be medium-ish or full screen.
                    .presentationCornerRadius(15) // Rounded sheet corners for a modern look.
            }
        }
    }

    // MARK: - Unchecked Items
    /// Section containing all unchecked items with swipe to edit/delete and leading swipe to check.
    private var uncheckedItemsSection: some View { // Computed view for unchecked items.
        ForEach(listViewModel.uncheckedItems) { item in // Iterate each unchecked item and make a row.
            ListRowView(item: item) // Render a row UI for the item.
                .listRowInsets(DS.List.rowInsets) // Explicit insets for consistent appearance across iOS versions.
                .listRowSeparator(.hidden) // Hide the default list separators for a card look.
                .listRowBackground(Color.theme.background) // Match row background to our theme.
                .swipeActions(allowsFullSwipe: false) { // Trailing swipe actions (no full swipe commit).
                    Button(String(localized: "swipe.notAvailable"), systemImage: "minus.circle") {} // Placeholder action.
                        .tint(.orange) // Orange color to indicate not available.
                    Button(String(localized: "swipe.edit"), systemImage: "pencil.circle") { // Edit action.
                        listViewModel.selectedItem = item // Set the selected item for editing.
                        showEditItemView = true // Show the edit sheet.
                    }
                    .tint(.blue) // Blue for edit.
                    Button(String(localized: "swipe.delete"), systemImage: "trash.circle", role: .destructive) { // Delete action.
                        withAnimation { listViewModel.deleteItem(item) } // Animate and request deletion through the VM.
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) { // Leading swipe to quickly check the item.
                    Button(String(localized: "swipe.check"), systemImage: "checkmark.circle") { // Check action.
                        withAnimation { listViewModel.toggleItemChecked(item) } // Toggle checked state with animation.
                    }
                    .tint(.green) // Green for check.
                }
        }
    }

    // MARK: - Checked Items
    /// Optional section listing already checked items with swipe to uncheck or delete.
    private var checkedItemsSection: some View { // Computed view for checked items.
        Group { // Conditional wrapper to avoid building empty sections.
            if listViewModel.checkedItemCount > 0 { // Only show when there are checked items.
                Section(header: SectionHeader(title: String(localized: "section.checkedItems.title"))) { // Section with a reusable header.
                    ForEach(listViewModel.checkedItems) { item in // Iterate all checked items.
                        ListRowView(item: item) // Render each checked item.
                            .listRowInsets(DS.List.rowInsets) // Explicit insets for consistent appearance across iOS versions.
                            .listRowSeparator(.hidden) // Hide default separators.
                            .listRowBackground(Color.theme.background) // Match theme.
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) { // Trailing swipe to uncheck.
                                Button(String(localized: "swipe.uncheck"), systemImage: "arrow.uturn.backward.circle") { // Uncheck action.
                                    withAnimation { listViewModel.toggleItemChecked(item) } // Toggle back to unchecked.
                                }
                                .tint(.yellow) // Yellow indicates undo/uncheck.
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) { // Leading swipe to delete.
                                Button(String(localized: "swipe.delete"), systemImage: "trash.circle") { // Delete action.
                                    withAnimation { listViewModel.deleteItem(item) } // Delete with animation.
                                }
                                .tint(.red) // Red for destructive action.
                            }
                    }
                }
            }
        }
    }
}

#Preview { ListView().environmentObject(PreviewMocks.makeListViewModelWithSamples()) } // Preview rendering the list with sample data.
