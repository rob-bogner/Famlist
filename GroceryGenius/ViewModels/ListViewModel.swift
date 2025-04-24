// MARK: - ListViewModel.swift

import Foundation
import SwiftUI
import FirebaseFirestore

class ListViewModel: ObservableObject {
    @Published var items: [ItemModel] = []
    @Published var selectedItem: ItemModel?
    private var listener: ListenerRegistration?

    init() {
        startListeningToFirestore()
    }

    deinit {
        listener?.remove()
    }

    func startListeningToFirestore() {
        listener = FirestoreManager.shared.addListener { [weak self] items in
            DispatchQueue.main.async {
                withAnimation {
                    self?.items = items
                }
            }
        }
    }

    func addItem(_ item: ItemModel) {
        FirestoreManager.shared.addItem(item)
    }

    func updateItem(_ item: ItemModel) {
        FirestoreManager.shared.updateItem(item)
    }

    func deleteItem(_ item: ItemModel) {
        FirestoreManager.shared.deleteItem(item)
    }

    func toggleItemChecked(_ item: ItemModel) {
        var updated = item
        updated.isChecked.toggle()
        updateItem(updated)
    }

    // MARK: - ProgressBar Unterstützung

    var totalItemCount: Int {
        items.count
    }

    var checkedItemCount: Int {
        items.filter { $0.isChecked }.count
    }

    var progressFraction: Double {
        totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount)
    }

    var uncheckedItems: [ItemModel] {
        items.filter { !$0.isChecked }
    }

    var checkedItems: [ItemModel] {
        items.filter { $0.isChecked }
    }
}
