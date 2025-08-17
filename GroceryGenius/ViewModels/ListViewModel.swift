// MARK: - ListViewModel.swift

/*
 File: ListViewModel.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 ObservableObject powering shopping list screens. Manages in‑memory state of items, real‑time Firestore sync, derived projections (progress, filtered arrays) and input helper methods used by views.

 Responsibilities / Includes:
 - Start & manage Firestore listener (live updates)
 - CRUD (add / update / delete / toggle)
 - Unit measure canonicalization (free‑form user input -> normalized token)
 - Derived metrics (progressFraction, checked / unchecked arrays)
 - Form & quick‑add bridging helpers (string -> numeric / normalized fields)
 - Lightweight error & loading flags for UI feedback

 Design Notes:
 - Repository abstraction (ItemsRepository) enables mocking in tests (decouple from FirestoreManager)
 - @Published drives SwiftUI diffing automatically; mutations must occur on main thread
 - All Firestore callbacks marshalled onto main queue then animated

 Error Handling:
 - Failures during add/update/delete currently only surface via optional completion -> expand later with structured error propagation if needed

 Possible Enhancements:
 - Debounce / throttle update bursts
 - Offline caching layer
 - More granular error states (enum) vs single optional string
*/

import Foundation
import SwiftUI
import FirebaseFirestore

/// ViewModel encapsulating shopping list state and Firestore synchronization.
class ListViewModel: ObservableObject {
    // MARK: - Dependencies & Core State
    private let repository: ItemsRepository
    @Published var items: [ItemModel] = []
    @Published var selectedItem: ItemModel?
    private var listener: ItemsRepository.ListenerToken?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Lifecycle
    init(repository: ItemsRepository = FirestoreManager.shared) {
        self.repository = repository
        startListeningToFirestore()
    }
    deinit { (listener as? ListenerRegistration)?.remove() }

    // MARK: - Real-time Listener
    func startListeningToFirestore() {
        listener = repository.addListener { [weak self] items in
            DispatchQueue.main.async {
                withAnimation { self?.items = items }
            }
        }
    }

    // MARK: - CRUD
    func addItem(_ item: ItemModel) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        repository.addItem(normalized, completion: nil)
    }
    func updateItem(_ item: ItemModel) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        repository.updateItem(normalized, completion: nil)
    }
    func deleteItem(_ item: ItemModel) { repository.deleteItem(item, completion: nil) }
    func toggleItemChecked(_ item: ItemModel) { var copy = item; copy.isChecked.toggle(); updateItem(copy) }

    // MARK: - Derived Projections
    var totalItemCount: Int { items.count }
    var checkedItemCount: Int { items.filter { $0.isChecked }.count }
    var progressFraction: Double { totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount) }
    var uncheckedItems: [ItemModel] { items.filter { !$0.isChecked } }
    var checkedItems: [ItemModel] { items.filter { $0.isChecked } }

    // MARK: - View Input Helpers
    func addItemFromInput(name: String, units: String, measure: String, image: UIImage? = nil) {
        isLoading = true
        let imageBase64 = imageToBase64(image)
        let canonical = canonicalizeMeasure(measure)
        let newItem = ItemModel(imageData: imageBase64, name: name, units: Int(units) ?? 1, measure: canonical, price: 0.0, isChecked: false)
        repository.addItem(newItem) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error { self?.errorMessage = error.localizedDescription }
            }
        }
    }
    func addQuickItem(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addItemFromInput(name: trimmed, units: "1", measure: "")
    }
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
        let canonical = canonicalizeMeasure(measure)
        let updated = ItemModel(
            id: id,
            imageData: imageBase64,
            name: name,
            units: Int(units) ?? 1,
            measure: canonical,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand
        )
        repository.updateItem(updated) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error { self?.errorMessage = error.localizedDescription }
            }
        }
    }
}

// MARK: - Measure Canonicalization
private extension ListViewModel {
    func canonicalizeMeasure(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return Measure.fromExternal(trimmed).rawValue
    }
}
