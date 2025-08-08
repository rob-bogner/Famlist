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
        VStack(alignment: .leading) { // Vertical stack aligned to leading edge
            Text("Progress") // Display the title text
                .font(.caption2) // Set font to caption2 style
                .fontWeight(.bold) // Apply bold font weight
                .foregroundColor(Color.theme.background) // Set text color to theme background color
                .padding(.horizontal, 20) // Add horizontal padding of 20 points
            HStack { // Horizontal stack for icon, progress bar, and text
                Group { // Group to apply padding collectively
                    Image(systemName: "basket") // Display basket system icon
                    
                    ProgressView(value: listViewModel.progressFraction) // Show progress bar with fraction
                    
                    Text("\(listViewModel.checkedItemCount)/\(listViewModel.totalItemCount)") // Show checked/total count
                }
                .padding(.horizontal, 8) // Add horizontal padding of 8 points
                .padding(.vertical, 8) // Add vertical padding of 8 points
            }
            .frame(maxWidth: .infinity) // Make HStack take full available width
            .background(Color.theme.card) // Set background color to theme card color
            .cornerRadius(10) // Round corners with radius of 10 points
            .padding(.horizontal, 20) // Add horizontal padding of 20 points outside the background
        }
    }
}

#Preview {
    ShoppingListProgressView(listViewModel: ListViewModel()) // Preview with a new ListViewModel instance
}
