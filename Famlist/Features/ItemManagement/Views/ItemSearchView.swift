/*
 ItemSearchView.swift

 Famlist
 Created on: 12.03.2026
 Last updated on: 14.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Sheet shown when the user taps the Add button (FAM-60 + OpenFoodFacts integration).
 - Lets the user search personal catalog and global OFF products, or create a new item.

 🛠 Includes:
 - Live search field with debounce (fires after 2 chars).
 - Two-section results list: "Deine Artikel" (personal, ★) and "OpenFood" (global OFF products).
 - "Neu anlegen" button that opens AddItemView with the typed name pre-filled.
 - Toast confirmation after adding an item from the catalog.

 🔰 Notes for Beginners:
 - ItemSearchViewModel drives the data; this view is purely presentational.
 - Tapping a result calls listViewModel.addItem() and dismisses the sheet.
 - Global results show an AsyncImage from the OFF CDN; personal results use base64 thumbnails.

 📝 Last Change:
 - Added globalCatalogRepository parameter and SearchResult support (OpenFoodFacts integration).
 ------------------------------------------------------------------------
 */

import SwiftUI // SwiftUI for declarative UI.

// MARK: - ItemSearchView

/// Sheet allowing the user to search personal and global product catalogs, or create a new item.
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

    init(
        catalogRepository: any ItemCatalogRepository,
        globalCatalogRepository: (any GlobalProductCatalogRepository)? = nil
    ) {
        _searchVM = StateObject(wrappedValue: ItemSearchViewModel(
            catalogRepository: catalogRepository,
            globalCatalogRepository: globalCatalogRepository
        ))
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
                if !searchVM.personalResults.isEmpty {
                    sectionHeader(String(localized: "itemSearch.section.personal"))
                    ForEach(searchVM.personalResults) { result in
                        Button(action: { addToList(result) }) {
                            ItemCatalogRow(entry: result.entry, source: result.source, imageUrl: result.imageUrl)
                        }
                        .buttonStyle(.plain)
                        if result.id != searchVM.personalResults.last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }

                if !searchVM.globalResults.isEmpty {
                    sectionHeader(String(localized: "itemSearch.section.global"))
                    ForEach(searchVM.globalResults) { result in
                        Button(action: { addToList(result) }) {
                            ItemCatalogRow(entry: result.entry, source: result.source, imageUrl: result.imageUrl)
                        }
                        .buttonStyle(.plain)
                        if result.id != searchVM.globalResults.last?.id {
                            Divider().padding(.leading, 68)
                        }
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    private func addToList(_ result: SearchResult) {
        guard let ownerPublicId = listViewModel.defaultList?.ownerId.uuidString else {
            logVoid(params: (action: "addToList.skipped", reason: "defaultList.ownerId is nil"))
            return
        }
        let newItem = result.entry.toItemModel(
            listId: listViewModel.listId.uuidString,
            ownerPublicId: ownerPublicId
        )
        listViewModel.addItem(newItem)
        toastManager.show(String(localized: "itemSearch.added"))
        dismiss()
    }
}

// MARK: - ItemCatalogRow

/// A single row in the search results list showing item thumbnail, name, brand and quantity.
/// Displays a ★ badge for personal catalog entries and an AsyncImage for global OFF products.
struct ItemCatalogRow: View {
    let entry: ItemCatalogEntry
    let source: SearchResultSource
    let imageUrl: String?

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            itemThumbnail
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)

                    if source == .personal {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(Color.theme.accent)
                    }
                }

                if let brand = entry.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !entry.measure.isEmpty {
                    Text(entry.measure)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let desc = entry.productDescription, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if entry.price > 0 {
                    Text(entry.price, format: .currency(code: "EUR"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
            // Personal catalog: base64-encoded image
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let urlString = imageUrl, let url = URL(string: urlString) {
            // Global OFF catalog: remote image from CDN (online-only)
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderThumbnail
                }
            }
        } else {
            placeholderThumbnail
        }
    }

    private var placeholderThumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .overlay(
                Image(systemName: "cart")
                    .foregroundColor(.secondary)
                    .font(.body)
            )
    }
}

// MARK: - Previews

#Preview("Persönlicher Katalog") {
    ItemSearchView(catalogRepository: PreviewItemCatalogRepository())
        .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}

#Preview("Mit globalem Katalog") {
    ItemSearchView(
        catalogRepository: PreviewItemCatalogRepository(),
        globalCatalogRepository: PreviewGlobalProductCatalogRepository()
    )
    .environmentObject(PreviewMocks.makeListViewModelWithSamples())
}
