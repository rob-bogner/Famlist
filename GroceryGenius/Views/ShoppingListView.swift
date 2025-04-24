/*
GroceryGenius
ShoppingListView.swift
Created by Robert Bogner on 27.11.23.

Presents a view for managing and displaying a shopping list within the Grocery Genius app.
*/

import SwiftUI

/// A view for displaying and interacting with the shopping list.
struct ShoppingListView: View {
    
    @EnvironmentObject var listViewModel: ListViewModel // ViewModel providing the data and logic for the list.
    @State private var addNewItem: Bool = false // State to control the display of the add new item view.

    var body: some View {
        NavigationView {
            ZStack {
                Color.theme.background.ignoresSafeArea() // Sets the background color of the view.
                
                VStack(spacing: 0) {
                    Spacer()
                    shoppingListProgressView // Displays the progress of the shopping list.
                    Spacer()
                    listView // Displays the list of items.
                    Spacer()
                }
                
                VStack {
                    Spacer()
                    addButton // Button to add a new item to the list.
                }
            }
            .navigationTitle("Shopping List") // Sets the navigation bar title.
            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .leading)), removal: .opacity.combined(with: .move(edge: .trailing)))) // Custom transition for the view.
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Sets the navigation view style.
    }
    
    /// View component displaying the progress of the shopping list.
    private var shoppingListProgressView: some View {
        ShoppingListProgressView(listViewModel: listViewModel)
    }
    
    /// View component displaying the list of items.
    private var listView: some View {
        ListView().environmentObject(listViewModel)
    }
    
    /// Button for adding a new item to the list.
    private var addButton: some View {
        HStack {
            Spacer()
            Button(action: {
                addNewItem.toggle() // Toggles the state to show or hide the add new item view.
            }, label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 45))
                    .foregroundStyle(
                        Color.theme.buttonIconColor,
                        Color.theme.buttonFillColor
                    )
                    .shadow(color: Color.theme.shadow, radius: 10)
            })
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .sheet(isPresented: $addNewItem, content: {
                AddItemView() // Presents the view for adding a new item.
                    .presentationDetents([.height(150)])
                    .presentationCornerRadius(15)
            })
        }
    }
}

#Preview {
    ShoppingListView()
        .environmentObject(ListViewModel()) // Preview setup with a ListViewModel.
}
