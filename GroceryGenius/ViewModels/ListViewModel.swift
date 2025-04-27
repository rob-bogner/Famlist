// MARK: - ListViewModel.swift

import Foundation
import SwiftUI
import FirebaseFirestore

/// ViewModel responsible for managing the shopping list items and synchronizing with Firestore.
class ListViewModel: ObservableObject {

    // MARK: - Properties

    /// The list of shopping items.
    @Published var items: [ItemModel] = []

    /// The currently selected item, if any.
    @Published var selectedItem: ItemModel?

    /// The Firestore listener registration to observe real-time updates.
    private var listener: ListenerRegistration?

    // MARK: - Initialization

    /// Initializes a new instance of `ListViewModel` and starts listening to Firestore changes.
    init() {
        startListeningToFirestore()
    }

    /// Cleans up the Firestore listener when the view model is deallocated.
    deinit {
        listener?.remove()
    }

    // MARK: - Firestore Listener Handling

    /// Starts listening for real-time updates from Firestore and updates the local item list accordingly.
    func startListeningToFirestore() {
        listener = FirestoreManager.shared.addListener { [weak self] items in
            DispatchQueue.main.async {
                withAnimation {
                    self?.items = items
                }
            }
        }
    }

    // MARK: - CRUD Operationen

    /// Adds a new item to Firestore.
    /// - Parameter item: The item to be added.
    func addItem(_ item: ItemModel) {
        FirestoreManager.shared.addItem(item)
    }

    /// Updates an existing item in Firestore.
    /// - Parameter item: The item to be updated.
    func updateItem(_ item: ItemModel) {
        FirestoreManager.shared.updateItem(item)
    }

    /// Deletes an item from Firestore.
    /// - Parameter item: The item to be deleted.
    func deleteItem(_ item: ItemModel) {
        FirestoreManager.shared.deleteItem(item)
    }

    /// Toggles the `isChecked` status of an item and updates it in Firestore.
    /// - Parameter item: The item whose check status will be toggled.
    func toggleItemChecked(_ item: ItemModel) {
        var updated = item
        updated.isChecked.toggle()
        updateItem(updated)
    }

    // MARK: - ProgressBar Unterstützung

    /// The total number of items in the list.
    var totalItemCount: Int {
        items.count
    }

    /// The number of checked (completed) items.
    var checkedItemCount: Int {
        items.filter { $0.isChecked }.count
    }

    /// The fraction of completed items relative to the total number of items.
    var progressFraction: Double {
        totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount)
    }

    /// The list of unchecked (not completed) items.
    var uncheckedItems: [ItemModel] {
        items.filter { !$0.isChecked }
    }

    /// The list of checked (completed) items.
    var checkedItems: [ItemModel] {
        items.filter { $0.isChecked }
    }
}
