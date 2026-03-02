/*
 ListViewModel+InputHelpers.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Extension providing view input helpers that bridge UI inputs to ItemModel objects.

 🛠 Includes:
 - addItemFromInput (full form with image, units, measure for quick add)
 - addQuickItem (minimal text-only input for inline quick add)

 🔰 Notes for Beginners:
 - These methods handle string-to-numeric conversions.
 - They delegate to core CRUD methods after preparing the ItemModel.
 - For complex forms, use ItemFormViewModel.toItemModel() instead.

 📝 Last Change:
 - Removed deprecated updateItemFromInput (11 parameters) - use ItemFormViewModel.toItemModel() instead.
 - Simplified to focus on quick-add scenarios only.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides Int parsing.
import UIKit // UIKit provides UIImage used for image handling.

// MARK: - View Input Helpers

extension ListViewModel {
    /// Creates and persists a new item from simple text inputs as used by quick-add features.
    /// For complex forms with validation, use ItemFormViewModel.toItemModel() instead.
    /// - Parameters:
    ///   - name: Item name.
    ///   - units: Quantity as string (e.g., "1").
    ///   - measure: Measurement unit as string (e.g., "kg").
    ///   - image: Optional image to attach.
    func addItemFromInput(name: String, units: String, measure: String, image: UIImage? = nil) {
        let newItem = ItemModel(
            imageData: image?.toBase64(),
            name: name,
            units: Int(units) ?? 1,
            measure: measure, // addItem() normalisiert via canonicalizeMeasure
            price: 0.0,
            isChecked: false,
            listId: listId.uuidString
        )
        addItem(newItem)
    }
    
    /// Quick add from a single text field; trims and validates minimal input.
    /// Used by the inline quick-add button in ShoppingListView.
    /// - Parameter text: Raw user input (item name).
    func addQuickItem(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addItemFromInput(name: trimmed, units: "1", measure: "")
    }
}
