// MARK: - ListViewModel.swift

/*
 ListViewModel.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 26.04.2025

 ------------------------------------------------------------------------
 📄 File Overview:

 This file defines the ViewModel responsible for managing shopping list items,
 handling real-time synchronization with Firestore, and supporting UI updates like the progress bar.

 🛠 Includes:
 - CRUD operations (Create, Read, Update, Delete) on shopping list items
 - Real-time Firestore synchronization
 - Progress calculation for a progress bar component
 - Support for separating checked and unchecked items

 🔰 Notes for Beginners:
 - `@Published` properties automatically notify SwiftUI views when changes occur.
 - Firestore provides real-time updates via a listener.
 - Functions like `addItem`, `updateItem`, and `deleteItem` interact with Firestore via `FirestoreManager`.
 ------------------------------------------------------------------------
*/

import Foundation // Provides essential types like Array, String, and DispatchQueue
import SwiftUI // Provides @Published, ObservableObject, and animation support
import FirebaseFirestore // Provides Firestore database interaction

/// ViewModel responsible for managing the shopping list items and synchronizing with Firestore.
class ListViewModel: ObservableObject {

    // MARK: - Properties

    /// Abstraktes Repository für Items (ermöglicht Mocking/Testbarkeit)
    private let repository: ItemsRepository

    /// The list of shopping items.
    @Published var items: [ItemModel] = [] // Automatically updates the UI when the list changes

    /// The currently selected item, if any.
    @Published var selectedItem: ItemModel? // Holds a selected item (e.g., for editing)

    /// The Firestore listener registration to observe real-time updates.
    private var listener: ItemsRepository.ListenerToken? // Used to keep track of Firestore's real-time listener

    /// Fehler- und Ladezustand für UI-Feedback
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false

    // MARK: - Initialization

    /// Ermöglicht Injektion eines benutzerdefinierten Repositories (z.B. Mock im Test)
    init(repository: ItemsRepository = FirestoreManager.shared) {
        self.repository = repository
        startListeningToFirestore() // Immediately begins syncing with Firestore when the ViewModel is created
    }

    /// Cleans up the Firestore listener when the view model is deallocated.
    deinit { (listener as? ListenerRegistration)?.remove() } // Stops the listener to prevent memory leaks

    // MARK: - Firestore Listener Handling

    /// Starts listening for real-time updates from Firestore and updates the local item list accordingly.
    func startListeningToFirestore() {
        listener = repository.addListener { [weak self] items in
            DispatchQueue.main.async { // Ensure UI updates happen on the main thread
                withAnimation { // Animate the list changes smoothly
                    self?.items = items // Update the local list of items
                }
            }
        }
    }

    // MARK: - CRUD Operations

    /// Adds a new item to Firestore.
    /// - Parameter item: The item to be added.
    func addItem(_ item: ItemModel) {
        repository.addItem(item, completion: nil) // Delegate adding item to FirestoreManager
    }

    /// Updates an existing item in Firestore.
    /// - Parameter item: The item to be updated.
    func updateItem(_ item: ItemModel) {
        repository.updateItem(item, completion: nil) // Delegate updating item to FirestoreManager
    }

    /// Deletes an item from Firestore.
    /// - Parameter item: The item to be deleted.
    func deleteItem(_ item: ItemModel) {
        repository.deleteItem(item, completion: nil) // Delegate deleting item to FirestoreManager
    }

    /// Toggles the `isChecked` status of an item and updates it in Firestore.
    /// - Parameter item: The item whose check status will be toggled.
    func toggleItemChecked(_ item: ItemModel) {
        var updated = item // Create a mutable copy of the item
        updated.isChecked.toggle() // Invert the isChecked property
        updateItem(updated) // Save the updated item back to Firestore
    }

    // MARK: - ProgressBar Support

    /// The total number of items in the list.
    var totalItemCount: Int {
        items.count // Return the total number of items
    }

    /// The number of checked (completed) items.
    var checkedItemCount: Int {
        items.filter { $0.isChecked }.count // Filter and count only the checked items
    }

    /// The fraction of completed items relative to the total number of items.
    var progressFraction: Double {
        totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount) // Avoid division by zero
    }

    /// The list of unchecked (not completed) items.
    var uncheckedItems: [ItemModel] {
        items.filter { !$0.isChecked } // Return all items that are not checked
    }

    /// The list of checked (completed) items.
    var checkedItems: [ItemModel] {
        items.filter { $0.isChecked } // Return all items that are checked
    }

    // MARK: - Neue Methoden für View-Input (Business-Logik aus Views entfernen)

    /// Fügt ein Item aus einfachen Eingabewerten hinzu (z.B. aus AddItemView oder Quick-Add)
    func addItemFromInput(name: String, units: String, measure: String, image: UIImage? = nil) {
        isLoading = true
        let imageBase64 = imageToBase64(image)
        let newItem = ItemModel(
            imageData: imageBase64,
            name: name,
            units: Int(units) ?? 1,
            measure: measure,
            price: 0.0,
            isChecked: false
        )
        repository.addItem(newItem) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Fügt ein Item aus Quick-Add-Text hinzu
    func addQuickItem(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addItemFromInput(name: trimmed, units: "1", measure: "")
    }

    /// Aktualisiert ein Item aus Edit-Input
    func updateItemFromInput(
        id: String,
        name: String,
        units: String,
        measure: String,
        price: String,
        isChecked: Bool,
        category: String?,
        productDescription: String?,
        brand: String?,
        image: UIImage?
    ) {
        isLoading = true
        let imageBase64 = imageToBase64(image)
        let updatedItem = ItemModel(
            id: id,
            imageData: imageBase64,
            name: name,
            units: Int(units) ?? 1,
            measure: measure,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand
        )
        repository.updateItem(updatedItem) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
