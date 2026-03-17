/*
 ListView.swift

 Famlist
 Created on: 08.01.2024
 Last updated on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Displays shopping list items grouped into unchecked and checked sections with swipe actions for edit, delete and (un)check operations.
 - Triggers cursor-based pagination when the user scrolls to the last item.

 🛠 Includes:
 - Unchecked and checked sections, swipe actions, EditItemView sheet presentation, and selected item handling via ViewModel.
 - Pagination trigger on last unchecked row (FAM-40).
 - Pull-to-Refresh (FAM-40).
 - Loading indicator at list bottom while fetching the next page (FAM-40).

 🔰 Notes for Beginners:
 - Uses EnvironmentObject to share the ListViewModel across subviews.
 - Swipe actions let you quickly edit, delete, or toggle check state.

 📝 Last Change:
 - FAM-40: Pagination trigger, pull-to-refresh, loading indicator.
 ------------------------------------------------------------------------
 */

import SwiftUI


/// Renders the two sections of items (unchecked and checked) with swipe actions and edit sheet.
struct ListView: View {
    @EnvironmentObject var listViewModel: ListViewModel
    @State private var showEditItemView: Bool = false

    var body: some View {
        SwiftUI.List {
            categoryItemsSections
            checkedItemsSection
            paginationFooter
        }
        .listStyle(PlainListStyle())
        .listRowSpacing(DS.List.rowSpacing)
        .environment(\.defaultMinListRowHeight, 0)
        .refreshable {
            await listViewModel.pullToRefresh()
        }
        .sheet(isPresented: $showEditItemView) {
            if let selectedItem = listViewModel.selectedItem {
                EditItemView(item: selectedItem)
                    .environmentObject(listViewModel)
                    .presentationDetents([.fraction(0.75), .large])
                    .presentationCornerRadius(15)
                    .presentationDragIndicator(.visible)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Category Sections

    @ViewBuilder
    private var categoryItemsSections: some View {
        ForEach(listViewModel.uncheckedItemsByCategory, id: \.category) { group in
            Section(header: CategorySectionHeader(category: group.category, itemCount: group.items.count)) {
                ForEach(group.items) { item in
                    uncheckedRow(for: item, isLast: item.id == lastUncheckedItemId)
                }
            }
        }
    }

    /// ID of the last unchecked item across all category groups — used to trigger pagination.
    private var lastUncheckedItemId: String? {
        listViewModel.uncheckedItemsByCategory.last?.items.last?.id
    }

    private func uncheckedRow(for item: ItemModel, isLast: Bool) -> some View {
        ListRowView(item: item, onRetry: { listViewModel.retryItem(item) })
            .id("unchecked-\(item.id)")
            .listRowInsets(DS.List.rowInsets)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.theme.background)
            .onAppear {
                // FAM-40: trigger next-page load when the last item becomes visible.
                if isLast && listViewModel.hasMoreItems {
                    Task { await listViewModel.loadNextPage() }
                }
            }
            .swipeActions(allowsFullSwipe: false) {
                Button(String(localized: "swipe.notAvailable"), systemImage: "minus.circle") {}
                    .tint(.orange)
                Button(String(localized: "swipe.edit"), systemImage: "pencil.circle") {
                    listViewModel.selectedItem = item
                    showEditItemView = true
                }
                .tint(.blue)
                Button(String(localized: "swipe.delete"), systemImage: "trash.circle", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        listViewModel.deleteItem(item)
                    }
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(String(localized: "swipe.check"), systemImage: "checkmark.circle") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        listViewModel.toggleItemChecked(item)
                    }
                }
                .tint(.green)
            }
    }

    // MARK: - Checked Items

    private var checkedItemsSection: some View {
        Group {
            if listViewModel.checkedItemCount > 0 {
                Section(header: SectionHeader(title: String(localized: "section.checkedItems.title"))) {
                    ForEach(listViewModel.checkedItems) { item in
                        ListRowView(item: item)
                            .id("checked-\(item.id)")
                            .listRowInsets(DS.List.rowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.theme.background)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(String(localized: "swipe.uncheck"), systemImage: "arrow.uturn.backward.circle") {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        listViewModel.toggleItemChecked(item)
                                    }
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(String(localized: "swipe.delete"), systemImage: "trash.circle") {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        listViewModel.deleteItem(item)
                                    }
                                }
                                .tint(.red)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Pagination Footer (FAM-40)

    /// Shows a spinner at the bottom of the list while the next page is being fetched.
    @ViewBuilder
    private var paginationFooter: some View {
        if listViewModel.isLoadingNextPage {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 12)
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.theme.background)
            }
        }
    }
}

#Preview { ListView().environmentObject(PreviewMocks.makeListViewModelWithSamples()) }
