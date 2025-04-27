//
// GroceryGenius
// ShoppingListView.swift
// Created by Robert Bogner on 27.11.23.
//

import SwiftUI

/// A view for displaying and interacting with the shopping list.
struct ShoppingListView: View {
    
    // MARK: - Properties
    
    /// ViewModel providing the data and logic for the list.
    @EnvironmentObject var listViewModel: ListViewModel
    
    /// State to control the display of the Add New Item sheet.
    @State private var addNewItem: Bool = false
    
    // MARK: - Body
    
    /// The content and behavior of the ShoppingListView.
    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background
                    .ignoresSafeArea() // Sets the background color.
                
                VStack(spacing: 0) {
                    Spacer()
                    shoppingListProgressView
                    Spacer()
                    listView
                    Spacer()
                }
                
                VStack {
                    Spacer()
                    addButton
                }
            }
            .navigationTitle("Shopping List")
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                )
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $addNewItem) {
            AddItemView()
                .presentationDetents([.fraction(0.25)])
                .presentationCornerRadius(15)
        }
    }
    
    // MARK: - Subviews
    
    /// Displays the progress of the shopping list.
    private var shoppingListProgressView: some View {
        ShoppingListProgressView(listViewModel: listViewModel)
    }
    
    /// Displays the list of shopping items.
    private var listView: some View {
        ListView()
            .environmentObject(listViewModel)
    }
    
    /// Button to add a new item to the list.
    private var addButton: some View {
        HStack {
            Spacer()
            Button(action: {
                addNewItem.toggle()
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 45))
                    .foregroundStyle(
                        Color.theme.buttonIconColor,
                        Color.theme.buttonFillColor
                    )
                    .shadow(color: Color.theme.shadow, radius: 10)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    /// Preview setup with a ListViewModel.
    ShoppingListView()
        .environmentObject(ListViewModel())
}
