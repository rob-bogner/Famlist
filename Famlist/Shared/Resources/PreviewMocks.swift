/*
 PreviewMocks.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Preview-only helpers used by SwiftUI previews. Provides sample items and a factory to create a ListViewModel preloaded with example data.

 🛠 Includes:
 - PreviewMocks struct with sampleItems and makeListViewModelWithSamples().
 - makeAppSessionViewModel() for session-related previews.

 🔰 Notes for Beginners:
 - This file helps previews render instantly without relying on network backends.
 - It uses the in-memory PreviewItemsRepository to seed data.
 - App runtime uses real repositories; this code is for previews only.

 📝 Last Change:
 - Added makeAppSessionViewModel() factory for ProfileView previews.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI for previews and environment injection.

/// Collection of preview-only helpers and sample data for SwiftUI previews.
struct PreviewMocks { // Namespace for preview data and factories.
    /// Ready-to-use sample items for list previews.
    static let sampleItems: [ItemModel] = [ // Small, realistic set of items.
        ItemModel(name: "Milk", units: 1, measure: "l", price: 1.99, isChecked: false, category: "Dairy", productDescription: "Organic whole milk 3.5%", brand: "Brand"),
        ItemModel(name: "Bread", units: 1, measure: "piece", price: 2.49, isChecked: false, category: "Bakery", productDescription: nil, brand: nil),
        ItemModel(name: "Eggs", units: 10, measure: "piece", price: 3.29, isChecked: true, category: "Dairy", productDescription: nil, brand: nil)
    ]

    /// Builds a ListViewModel preloaded with sample items using the in-memory PreviewItemsRepository.
    /// - Returns: A ListViewModel seeded with example data for previews.
    @MainActor
    static func makeListViewModelWithSamples() -> ListViewModel {
        let repo = PreviewItemsRepository() // In-memory repository for previews.
        let listId = UUID(uuidString: "00000000-0000-0000-0000-00000000ABCD") ?? UUID() // Stable preview list id.
        let vm = ListViewModel(listId: listId, repository: repo) // Start observing immediately.
        // Provide a fake default list so ShoppingListView preview doesn’t show the loading overlay.
        let owner = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID() // Stable owner id for previews.
        vm.defaultList = ListModel(id: listId, ownerId: owner, title: "Preview Default List", isDefault: true, createdAt: Date(), updatedAt: Date()) // Seed default list.
        // Seed items asynchronously so the stream delivers them to observers.
        Task {
            for var item in sampleItems { // Copy each sample and assign the preview list id.
                item.listId = listId.uuidString // Scope to our preview list.
                _ = try? await repo.createItem(item) // Insert into in-memory store.
            }
        }
        return vm // Return immediately; items will flow in.
    }
    
    /// Builds an AppSessionViewModel for previews with a sample profile
    /// - Returns: An AppSessionViewModel with preview data
    @MainActor
    static func makeAppSessionViewModel() -> AppSessionViewModel {
        let listVM = makeListViewModelWithSamples()
        let sessionVM = AppSessionViewModel(
            client: nil, // No real client in previews
            profiles: PreviewProfilesRepository(),
            lists: PreviewListsRepository(),
            listViewModel: listVM
        )
        // Set a sample profile
        sessionVM.currentProfile = Profile(
            id: UUID(),
            publicId: "ABC12345",
            username: "preview_user",
            fullName: "Preview User",
            avatarUrl: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        sessionVM.isAuthenticated = true
        return sessionVM
    }
}

#Preview { // SwiftUI preview using pre-seeded mock data.
    ShoppingListView() // Use the app's main list view.
        .environmentObject(PreviewMocks.makeListViewModelWithSamples()) // Inject a preview ListViewModel with sample data.
}
