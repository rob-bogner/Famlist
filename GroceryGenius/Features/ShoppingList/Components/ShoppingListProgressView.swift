/*
 ShoppingListProgressView.swift

 GroceryGenius
 Created on: 08.01.2024
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lightweight progress component showing checked vs total items. Integrated visually inside accent header.

 🛠 Includes:
 - Computes localized progress label and renders a ProgressCard with fraction and label.

 🔰 Notes for Beginners:
 - The label uses a localized format string with counts plugged in.
 - This view reads data from ListViewModel provided by the environment.

 📝 Last Change:
 - Standardized header and switched preview to use PreviewMocks for consistent data.
 ------------------------------------------------------------------------
 */

import SwiftUI // Imports SwiftUI to build the view and use ProgressCard.

/// A view that displays the progress of items being checked off in the shopping list.
struct ShoppingListProgressView: View { // Declares a SwiftUI View type.
    // MARK: - Properties
    
    /// ViewModel providing data for progress calculation.
    @ObservedObject var listViewModel: ListViewModel // Observes changes so the view updates when counts change.
    
    // MARK: - Body
    
    /// The content and behavior of the view.
    var body: some View { // Defines the view’s layout.
        VStack(alignment: .leading) { // Stack the card with leading alignment for header placement.
            let single = listViewModel.checkedItemCount == 1 // Determine singular vs plural label.
            let key = single ? "progress.single" : "progress.multi" // Choose localization key accordingly.
            let format = NSLocalizedString(key, comment: "Progress label format") // Fetch localized format string.
            let label = String(format: format, listViewModel.checkedItemCount, listViewModel.totalItemCount) // Build final label with counts.
            ProgressCard( // Reuse the card component for visuals.
                title: String(localized: "progress.title"), // Small caption above the row.
                progress: listViewModel.progressFraction, // 0...1 fraction for the progress bar.
                label: label // Human-readable label like "3 of 10".
            )
            .padding(.horizontal, 20) // Indent slightly within the header.
        }
    }
}

#Preview { // Preview shows the component with a sample view model.
    // Preview uses a ListViewModel with in-memory sample data from PreviewMocks
    ShoppingListProgressView(listViewModel: PreviewMocks.makeListViewModelWithSamples()) // Inject preview model to produce counts.
}
