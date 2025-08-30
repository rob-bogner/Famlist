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
@MainActor
class ListViewModel: ObservableObject {
    // MARK: - Dependencies & Core State
    private let repository: ItemsRepository
    @Published var items: [ItemModel] = []
    @Published var selectedItem: ItemModel?
    private var itemsTask: Task<Void, Never>?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var owner: PublicUserId?
    private var listId: String?

    // MARK: - Lifecycle
    init(repository: ItemsRepository = FirestoreItemsRepository()) {
        self.repository = repository
    }
    deinit { itemsTask?.cancel() }

    // MARK: - Configuration & Listener
    func configure(publicId: PublicUserId, listId: String) {
        self.owner = publicId
        self.listId = listId
        itemsTask?.cancel()
        itemsTask = Task { [weak self] in
            guard let self = self else { return }
            for await snapshot in self.repository.observeItems(for: publicId, listId: listId) {
                await MainActor.run { withAnimation { self.items = snapshot } }
            }
        }
    }

    // MARK: - CRUD
    func addItem(_ item: ItemModel) {
        guard let owner, let listId else { errorMessage = "Not configured"; return }
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        let payload = NewItemPayload(
            id: item.id,
            imageData: item.imageData,
            name: normalized.name,
            units: normalized.units,
            measure: normalized.measure,
            price: normalized.price,
            isChecked: normalized.isChecked,
            category: normalized.category,
            productDescription: normalized.productDescription,
            brand: normalized.brand
        )
        Task { [weak self] in
            do { _ = try await self?.repository.createItem(for: owner, listId: listId, payload: payload) }
            catch { await MainActor.run { self?.errorMessage = error.localizedDescription } }
        }
    }

    func updateItem(_ item: ItemModel) {
        guard let owner, let listId else { errorMessage = "Not configured"; return }
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        Task { [weak self] in
            do { try await self?.repository.updateItem(for: owner, listId: listId, item: normalized) }
            catch { await MainActor.run { self?.errorMessage = error.localizedDescription } }
        }
    }

    func deleteItem(_ item: ItemModel) {
        guard let owner, let listId else { errorMessage = "Not configured"; return }
        Task { [weak self] in
            do { try await self?.repository.deleteItem(for: owner, listId: listId, itemId: item.id) }
            catch { await MainActor.run { self?.errorMessage = error.localizedDescription } }
        }
    }

    func toggleItemChecked(_ item: ItemModel) { var copy = item; copy.isChecked.toggle(); updateItem(copy) }

    // MARK: - Derived Projections
    var totalItemCount: Int { items.count }
    var checkedItemCount: Int { items.filter { $0.isChecked }.count }
    var progressFraction: Double { totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount) }
    var uncheckedItems: [ItemModel] { items.filter { !$0.isChecked } }
    var checkedItems: [ItemModel] { items.filter { $0.isChecked } }

    // MARK: - View Input Helpers
    func addItemFromInput(name: String, units: String, measure: String, image: UIImage? = nil) {
        guard let owner, let listId else { errorMessage = "Not configured"; return }
        isLoading = true
        let imageBase64 = imageToBase64(image)
        let canonical = canonicalizeMeasure(measure)
        let payload = NewItemPayload(
            id: nil,
            imageData: imageBase64,
            name: name,
            units: Int(units) ?? 1,
            measure: canonical,
            price: 0.0,
            isChecked: false,
            category: nil,
            productDescription: nil,
            brand: nil
        )
        Task { [weak self] in
            do {
                _ = try await self?.repository.createItem(for: owner, listId: listId, payload: payload)
                await MainActor.run { self?.isLoading = false }
            } catch {
                await MainActor.run { self?.isLoading = false; self?.errorMessage = error.localizedDescription }
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
        guard let owner, let listId else { errorMessage = "Not configured"; return }
        isLoading = true
        let imageBase64 = imageToBase64(image)
        let canonical = canonicalizeMeasure(measure)
        let updated = ItemModel(
            id: id,
            ownerPublicId: owner.value,
            imageData: imageBase64,
            name: name,
            units: Int(units) ?? 1,
            measure: canonical,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0,
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId
        )
        Task { [weak self] in
            do {
                try await self?.repository.updateItem(for: owner, listId: listId, item: updated)
                await MainActor.run { self?.isLoading = false }
            } catch {
                await MainActor.run { self?.isLoading = false; self?.errorMessage = error.localizedDescription }
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
