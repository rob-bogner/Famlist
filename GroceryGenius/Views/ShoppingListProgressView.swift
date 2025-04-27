/*
 GroceryGenius
 ShoppingListProgressView.swift
 Created by Robert Bogner on 08.01.24.

 Provides a visual representation of the shopping list's completion progress.
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
            Text("Shopping progress")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 20)
                .padding(.vertical, 0)
            
            HStack {
                Group {
                    Image(systemName: "basket")
                    
                    ProgressView(value: listViewModel.progressFraction)
                    
                    Text("\(listViewModel.checkedItemCount)/\(listViewModel.totalItemCount)")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
            .background(Color.theme.card)
            .cornerRadius(10)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    ShoppingListProgressView(listViewModel: ListViewModel())
}
