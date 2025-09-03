// MARK: - ListViewModel.swift

/*
 File: ListViewModel.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 ObservableObject powering shopping list screens. Manages in‑memory state of items, and provides derived projections (progress, filtered arrays) and input helper methods used by views.

 Responsibilities / Includes:
 - Start & manage items observation (live updates via repository)
 - CRUD (add / update / delete / toggle)
 - Unit measure canonicalization (free‑form user input -> normalized token)
 - Derived metrics (progressFraction, checked / unchecked arrays)
 - Form & quick‑add bridging helpers (string -> numeric / normalized fields)
 - Lightweight error & loading flags for UI feedback

 Design Notes:
 - Repository abstraction (ItemsRepository) enables mocking in tests
 - @Published drives SwiftUI diffing automatically; mutations occur on main thread

 Error Handling:
 - Failures during add/update/delete currently surface via errorMessage for UI feedback

*/

import Foundation
import SwiftUI

/// ViewModel encapsulating shopping list state and repository synchronization.
@MainActor
class ListViewModel: ObservableObject {
    // MARK: - Dependencies & Core State
    private let repository: ItemsRepository
    private(set) var listId: UUID

    @Published var items: [ItemModel] = []
    @Published var selectedItem: ItemModel?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var observeTask: Task<Void, Never>? = nil

    // MARK: - Lifecycle
    init(listId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(), repository: ItemsRepository = PreviewItemsRepository()) {
        self.listId = listId
        self.repository = repository
        startObserving()
    }
    deinit { observeTask?.cancel() }

    // MARK: - List Switching
    func switchList(to newId: UUID) {
        guard newId != self.listId else { return }
        observeTask?.cancel()
        self.listId = newId
        self.items = []
        startObserving()
    }

    // MARK: - Real-time Observation
    private func startObserving() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await snapshot in repository.observeItems(listId: listId) {
                await MainActor.run { withAnimation { self.items = snapshot } }
            }
        }
    }

    // MARK: - CRUD (bridged to async/await)
    func addItem(_ item: ItemModel) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString
        Task { [weak self] in
            do { _ = try await self?.repository.createItem(normalized) }
            catch { self?.setError(error) }
        }
    }

    func updateItem(_ item: ItemModel) {
        var normalized = item
        normalized.measure = canonicalizeMeasure(item.measure)
        normalized.listId = normalized.listId ?? listId.uuidString
        Task { [weak self] in
            do { try await self?.repository.updateItem(normalized) }
            catch { self?.setError(error) }
        }
    }

    func deleteItem(_ item: ItemModel) {
        Task { [weak self] in
            do { try await self?.repository.deleteItem(id: item.id, listId: self?.listId ?? UUID()) }
            catch { self?.setError(error) }
        }
    }

    func toggleItemChecked(_ item: ItemModel) {
        var copy = item
        copy.isChecked.toggle()
        updateItem(copy)
    }

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
        let newItem = ItemModel(imageData: imageBase64, name: name, units: Int(units) ?? 1, measure: canonical, price: 0.0, isChecked: false, listId: listId.uuidString)
        Task { [weak self] in
            do { _ = try await self?.repository.createItem(newItem) }
            catch { self?.setError(error) }
            await MainActor.run { self?.isLoading = false }
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
            brand: brand,
            listId: listId.uuidString
        )
        Task { [weak self] in
            do { try await self?.repository.updateItem(updated) }
            catch { self?.setError(error) }
            await MainActor.run { self?.isLoading = false }
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
    @MainActor
    func setError(_ error: Error) {
        self.errorMessage = (error as NSError).localizedDescription
    }
}
