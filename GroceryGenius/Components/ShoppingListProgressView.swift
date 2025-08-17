// MARK: - ShoppingListProgressView.swift

/*
 File: ShoppingListProgressView.swift
 Project: GroceryGenius
 Created: 08.01.2024
 Last Updated: 17.08.2025

 Overview:
 Lightweight progress component showing checked vs total items. Integrated visually inside accent header.

 Responsibilities / Includes:
 - Computes localized progress label (singular/plural)
 - Renders ProgressCard with fraction and label

 Design Notes:
 - Formatting kept minimal; pluralization decided by count == 1
 - Layout kept flexible; parent controls horizontal padding

 Possible Enhancements:
 - Add accessibility progress description override
 - Add animation for progress change
*/

import SwiftUI

/// A view that displays the progress of items being checked off in the shopping list.
struct ShoppingListProgressView: View {
    // MARK: - Properties
    
    /// ViewModel providing data for progress calculation.
    @ObservedObject var listViewModel: ListViewModel
    
    // MARK: - Body
    
    /// The content and behavior of the view.
    var body: some View {
        VStack(alignment: .leading) {
            let single = listViewModel.checkedItemCount == 1
            let key = single ? "progress.single" : "progress.multi"
            let format = NSLocalizedString(key, comment: "Progress label format")
            let label = String(format: format, listViewModel.checkedItemCount, listViewModel.totalItemCount)
            ProgressCard(
                title: String(localized: "progress.title"),
                progress: listViewModel.progressFraction,
                label: label
            )
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    ShoppingListProgressView(listViewModel: ListViewModel()) // Preview with a new ListViewModel instance
}
