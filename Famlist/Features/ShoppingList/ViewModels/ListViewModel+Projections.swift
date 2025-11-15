/*
 ListViewModel+Projections.swift

 GroceryGenius
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Extension providing computed properties and derived data projections from ListViewModel state.

 🛠 Includes:
 - Progress metrics (totalItemCount, checkedItemCount, progressFraction)
 - Filtered item arrays (uncheckedItems, checkedItems)

 🔰 Notes for Beginners:
 - These computed properties maintain stable sort order by preserving the order from items array.
 - Views can bind directly to these properties for reactive UI updates.

 📝 Last Change:
 - Extracted from ListViewModel.swift to follow one-type-per-file rule and reduce file size.
 ------------------------------------------------------------------------
 */

import Foundation // Provides array filtering capabilities.

// MARK: - Derived Projections

extension ListViewModel {
    /// Total number of items currently loaded.
    var totalItemCount: Int {
        items.count
    }
    
    /// Number of items whose isChecked flag is true.
    var checkedItemCount: Int {
        items.filter { $0.isChecked }.count
    }
    
    /// Returns a 0...1 fraction for progress UI (0 when list is empty to avoid NaN).
    var progressFraction: Double {
        totalItemCount == 0 ? 0 : Double(checkedItemCount) / Double(totalItemCount)
    }
    
    /// Convenience array of items that are not checked yet.
    /// Maintains stable sort order by preserving the order from items array.
    var uncheckedItems: [ItemModel] {
        items.filter { !$0.isChecked }
    }
    
    /// Convenience array of items that are checked already.
    /// Maintains stable sort order by preserving the order from items array.
    var checkedItems: [ItemModel] {
        items.filter { $0.isChecked }
    }
}

