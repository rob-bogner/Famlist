/*
 GroceryGenius
 ShoppingListProgressView.swift
 Created on: 08.01.24
 Last Updated on: 27.04.24

 This file defines ShoppingListProgressView, a SwiftUI progress bar view showing
 checked/total items in the shopping list. It is visually integrated in the accent
 header background for a modern, ticket-inspired look.
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
            ProgressCard(
                title: "Progress",
                progress: listViewModel.progressFraction,
                label: "\(listViewModel.checkedItemCount)/\(listViewModel.totalItemCount)"
            )
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    ShoppingListProgressView(listViewModel: ListViewModel()) // Preview with a new ListViewModel instance
}
