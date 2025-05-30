/*
 GroceryGenius
 ShoppingListProgressView.swift
 Created on 08.01.24
 Last Updated on 27.04.24

 This file defines ShoppingListProgressView, a SwiftUI view that visually represents
 the progress of checking off items in a shopping list. It displays a progress bar,
 an icon, and a textual count of checked versus total items.
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
                .fontWeight(.medium) // Apply medium font weight
                .padding(.horizontal, 20) // Add horizontal padding of 20 points
                .padding(.vertical, 0) // Add vertical padding of 0 points
            
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
