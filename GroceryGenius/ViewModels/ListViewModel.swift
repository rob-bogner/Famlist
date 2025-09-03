// MARK: - ListViewModel.swift

/*
 ListViewModel.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - ObservableObject powering shopping list screens. Manages in‑memory state of items, and provides derived projections (progress, filtered arrays) and input helper methods used by views.

 🛠 Includes:
 - Start & manage items observation (live updates via repository)
 - CRUD (add / update / delete / toggle)
 - Unit measure canonicalization (free‑form user input -> normalized token)
 - Derived metrics (progressFraction, checked / unchecked arrays)
 - Form & quick‑add bridging helpers (string -> numeric / normalized fields)
 - Lightweight error & loading flags for UI feedback

 🔰 Notes for Beginners:
 - Repository abstraction (ItemsRepository) enables mocking in tests.
 - @Published drives SwiftUI diffing automatically; mutations occur on main thread.
 - All public methods are @MainActor-only because SwiftUI expects UI changes on the main thread.

 📝 Last Change:
 - Standardized header and added line-by-line comments to clarify each property and method for beginners. No functional changes.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID, DispatchSemaphore, and base types used here.
import SwiftUI // SwiftUI is needed for ObservableObject and @Published used by the view model.

/// ViewModel encapsulating shopping list state and repository synchronization.
@MainActor // Guarantees that all state changes happen on the main thread (UI thread).
class ListViewModel: ObservableObject { // ObservableObject lets SwiftUI observe changes to @Published properties.
    // MARK: - Dependencies & Core State
    private let repository: ItemsRepository // Abstraction over the data source (Supabase or in-memory preview).
    private(set) var listId: UUID // Current list context; switching replaces the observed stream of items.

    @Published var items: [ItemModel] = [] // The items currently displayed in the UI. Changes re-render views.
    @Published var selectedItem: ItemModel? // The item currently selected for editing (opens EditItemView sheet).
    @Published var errorMessage: String? // Optional error message surfaced to the UI on operation failures.
    @Published var isLoading: Bool = false // Indicates when the view is performing a long-running action.

    private var observeTask: Task<Void, Never>? = nil // Holds the background task that observes live item changes.

    // MARK: - Lifecycle
    /// Creates a ListViewModel with a target list and a repository (defaults to preview repo for development/previews).
    init(listId: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID(), repository: ItemsRepository = PreviewItemsRepository()) {
        self.listId = listId // Store which list we are managing.
        self.repository = repository // Store the data source implementation.
        startObserving() // Immediately begin listening for item updates for this list.
    }
    deinit { observeTask?.cancel() } // Cancel the observation task when the view model is released to avoid leaks.

    // MARK: - List Switching
    /// Switches the active list; cancels current observation and starts a new one for the new list id.
    func switchList(to newId: UUID) {
        guard newId != self.listId else { return } // Bail out if the requested list is already active.
        observeTask?.cancel() // Stop observing the old list to prevent duplicate updates.
        self.listId = newId // Update state with the new list context.
        self.items = [] // Clear current items to avoid showing stale data briefly.
        startObserving() // Start observing items for the new list.
    }

    // MARK: - Real-time Observation
    /// Starts (or restarts) the background observation of items for the current listId.
    private func startObserving() {
        observeTask?.cancel() // Ensure any previous observer is cancelled before starting a new one.
        observeTask = Task { [weak self] in // Spawn a new child task that will live until cancelled.
            guard let self else { return } // Capture self weakly to avoid retain cycles.
            for await snapshot in repository.observeItems(listId: listId) { // Iterate updates as they arrive from repository.
                await MainActor.run { withAnimation { self.items = snapshot } } // Apply with animation on main thread for smooth UI.
            }
        }
    }

    // MARK: - CRUD (bridged to async/await)
    /// Adds a new item after normalizing fields (e.g., measure, listId).
    func addItem(_ item: ItemModel) {
        var normalized = item // Work on a mutable copy to keep parameter immutable.
        normalized.measure = canonicalizeMeasure(item.measure) // Normalize user-provided measure to a known token.
        normalized.listId = normalized.listId ?? listId.uuidString // Ensure the item carries the current list id.
        Task { [weak self] in // Run the repository call asynchronously.
            do { _ = try await self?.repository.createItem(normalized) } // Create item in the repository.
            catch { self?.setError(error) } // Surface any error to UI.
        }
    }

    /// Updates an existing item after normalizing fields.
    func updateItem(_ item: ItemModel) {
        var normalized = item // Copy for mutation.
        normalized.measure = canonicalizeMeasure(item.measure) // Normalize measure text.
        normalized.listId = normalized.listId ?? listId.uuidString // Ensure list context is present.
        Task { [weak self] in // Perform async update.
            do { try await self?.repository.updateItem(normalized) } // Persist changes.
            catch { self?.setError(error) } // Show error.
        }
    }

    /// Deletes an item by id within the current list.
    func deleteItem(_ item: ItemModel) {
        Task { [weak self] in // Async call wrapper.
            do { try await self?.repository.deleteItem(id: item.id, listId: self?.listId ?? UUID()) } // Delete by id for active list.
            catch { self?.setError(error) } // Show error if it fails.
        }
    }

    /// Toggles the checked state of an item and persists the change via updateItem.
    func toggleItemChecked(_ item: ItemModel) {
        var copy = item // Copy the item so we can mutate it safely.
        copy.isChecked.toggle() // Flip the boolean from true -> false or vice versa.
        updateItem(copy) // Reuse update flow to persist.
    }

    // MARK: - Derived Projections
    /// Total number of items currently loaded.
    var totalItemCount: Int { items.count }
    /// Number of items whose isChecked flag is true.
    var checkedItemCount: Int { items.filter { $0.isChecked }.count }
    /// Returns a 0...1 fraction for progress UI (0 when list is empty to avoid NaN).
    var progressFraction: Double { totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount) }
    /// Convenience array of items that are not checked yet.
    var uncheckedItems: [ItemModel] { items.filter { !$0.isChecked } }
    /// Convenience array of items that are checked already.
    var checkedItems: [ItemModel] { items.filter { $0.isChecked } }

    // MARK: - View Input Helpers
    /// Creates and persists a new item from simple text inputs as used by the AddItemView form.
    func addItemFromInput(name: String, units: String, measure: String, image: UIImage? = nil) {
        isLoading = true // Show a lightweight loading indicator in the UI.
        let imageBase64 = imageToBase64(image) // Convert optional image to Base64 string for persistence.
        let canonical = canonicalizeMeasure(measure) // Normalize measure before storing.
        let newItem = ItemModel(imageData: imageBase64, name: name, units: Int(units) ?? 1, measure: canonical, price: 0.0, isChecked: false, listId: listId.uuidString) // Build model.
        Task { [weak self] in // Persist asynchronously to keep UI responsive.
            do { _ = try await self?.repository.createItem(newItem) } // Create in repository.
            catch { self?.setError(error) } // Show error if it fails.
            await MainActor.run { self?.isLoading = false } // Hide loading flag on main thread.
        }
    }

    /// Quick add from a single text field; trims and validates minimal input then delegates to addItemFromInput.
    func addQuickItem(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines) // Remove surrounding spaces/newlines.
        guard !trimmed.isEmpty else { return } // Ignore empty input.
        addItemFromInput(name: trimmed, units: "1", measure: "") // Default to 1 unit and no measure.
    }

    /// Updates an item using string fields from EditItemView, performing conversions and normalization.
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
        isLoading = true // Indicate background work.
        let imageBase64 = imageToBase64(image) // Convert image to Base64 if present.
        let canonical = canonicalizeMeasure(measure) // Normalize measure text.
        let updated = ItemModel(
            id: id,
            imageData: imageBase64,
            name: name,
            units: Int(units) ?? 1,
            measure: canonical,
            price: Double(price.replacingOccurrences(of: ",", with: ".")) ?? 0.0, // Convert localized string to Double.
            isChecked: isChecked,
            category: category,
            productDescription: productDescription,
            brand: brand,
            listId: listId.uuidString
        ) // Construct the updated model to persist.
        Task { [weak self] in // Async persistence.
            do { try await self?.repository.updateItem(updated) } // Update in repository.
            catch { self?.setError(error) } // Show error.
            await MainActor.run { self?.isLoading = false } // Reset loading flag.
        }
    }
}

// MARK: - Measure Canonicalization
private extension ListViewModel {
    /// Converts a free-form measure string to a normalized token using the Measure enum.
    func canonicalizeMeasure(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines) // Trim spaces.
        guard !trimmed.isEmpty else { return "" } // Keep empty when user provided nothing.
        return Measure.fromExternal(trimmed).rawValue // Map to enum case and return its canonical raw value.
    }
    /// Stores a user-presentable error string on the main actor.
    @MainActor
    func setError(_ error: Error) {
        self.errorMessage = (error as NSError).localizedDescription // Convert to readable message for UI.
    }
}
