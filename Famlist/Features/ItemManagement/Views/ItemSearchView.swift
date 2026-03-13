/*
 ItemSearchView.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 12.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet shown when the user taps the Add button (FAM-60).
 - Lets the user search their personal item catalog and pick an existing item,
   or fall back to the full AddItemView to create a new one.

 🛠 Includes:
 - Live search field with debounce (fires after 2 chars).
 - Top-5 results list with item thumbnail, name, brand and quantity.
 - "Neu anlegen" button that opens AddItemView with the typed name pre-filled.
 - Toast confirmation after adding an item from the catalog.

 🔰 Notes for Beginners:
 - ItemSearchViewModel drives the data; this view is purely presentational.
 - Tapping a result calls listViewModel.addItem() and dismisses the sheet.
 - The sheet for AddItemView is presented on top of this sheet (stacked sheets).

 📝 Last Change:
 - Initial creation for FAM-60 smart search feature.
 ------------------------------------------------------------------------
 */

import SwiftUI // SwiftUI for declarative UI.

// MARK: - ItemSearchView

/// Sheet allowing the user to search their personal item catalog or create a new item.
struct ItemSearchView: View {

    // MARK: - Environment & Dependencies

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var listViewModel: ListViewModel

    // MARK: - State

    @StateObject private var searchVM: ItemSearchViewModel
    @StateObject private var toastManager = ToastManager()
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showAddItem: Bool = false

    // MARK: - Init

    init(catalogRepository: any ItemCatalogRepository) {
        _searchVM = StateObject(wrappedValue: ItemSearchViewModel(catalogRepository: catalogRepository))
    }

    // MARK: - Body

    var body: some View {
        CustomModalView(title: String(localized: "itemSearch.title"), onClose: { dismiss() }) {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()

                if searchVM.isSearching {
                    ProgressView()
                        .padding(.top, 40)
                    Spacer()
                } else {
                    resultsList
                }

                Divider()

                newItemButton
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { isSearchFieldFocused = true }
        .sheet(isPresented: $showAddItem) {
            AddItemView(
                initialName: searchVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines),
                onItemAdded: { dismiss() }
            )
            .presentationDetents([.fraction(0.45), .large, .medium])
            .presentationCornerRadius(15)
            .presentationDragIndicator(.visible)
        }
        .toast(using: toastManager)
        .presentationDetents([.large])
        .presentationCornerRadius(15)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(String(localized: "itemSearch.placeholder"), text: $searchVM.searchText)
                .focused($isSearchFieldFocused)
                .autocorrectionDisabled()
                .onChange(of: searchVM.searchText) { _, _ in
                    searchVM.onSearchTextChanged()
                }
            if !searchVM.searchText.isEmpty {
                Button(action: { searchVM.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(searchVM.results) { entry in
                    Button(action: { addToList(entry) }) {
                        ItemCatalogRow(entry: entry)
                    }
                    .buttonStyle(.plain)

                    if entry.id != searchVM.results.last?.id {
                        Divider()
                            .padding(.leading, 68)
                    }
                }

                if let error = searchVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
    }

    // MARK: - "Neu anlegen" Button

    private var newItemButton: some View {
        let trimmed = searchVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let label: String
        if trimmed.count >= 2 {
            label = String(format: String(localized: "itemSearch.createNew.withName"), trimmed)
        } else {
            label = String(localized: "itemSearch.createNew")
        }

        return PrimaryButton(title: label) {
            showAddItem = true
        }
    }

    // MARK: - Actions

    private func addToList(_ entry: ItemCatalogEntry) {
        let newItem = entry.toItemModel(
            listId: listViewModel.listId.uuidString,
            ownerPublicId: listViewModel.defaultList?.ownerId.uuidString
        )
        listViewModel.addItem(newItem)
        toastManager.show(String(localized: "itemSearch.added"))
        dismiss()
    }
}

// MARK: - ItemCatalogRow

/// A single row in the search results list showing item thumbnail, name, brand and quantity.
struct ItemCatalogRow: View {
    let entry: ItemCatalogEntry

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            itemThumbnail
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(.primary)

                if let brand = entry.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("\(entry.units) \(entry.measure)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "plus")
                .foregroundColor(Color.theme.accent)
                .padding(.trailing, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var itemThumbnail: some View {
        if let imageData = entry.imageData,
           let image = ImageCache.shared.image(fromBase64: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .overlay(
                    Image(systemName: "cart")
                        .foregroundColor(.secondary)
                        .font(.body)
                )
        }
    }
}

// MARK: - Previews

#Preview {
    ItemSearchView(catalogRepository: PreviewItemCatalogRepository())
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
