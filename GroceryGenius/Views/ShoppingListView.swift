//
// GroceryGenius
// ShoppingListView.swift
// Created on: 27.11.2023
// Last updated on: 26.04.2025
//
// ------------------------------------------------------------------------
// 📄 File Overview:
//
// This file defines the main view for displaying and interacting with
// the shopping list. It includes progress tracking, a dynamic item list,
// and functionality to add new items.
//
// 🛠 Includes:
// - Navigation view setup
// - Display of shopping progress
// - List of shopping items
// - Floating add-button and modal sheet for adding items
//
// 🔰 Notes for Beginners:
// - `@EnvironmentObject` injects shared data (ListViewModel) into the view.
// - `.sheet` is used to present a modal interface.
// - `.presentationDetents` controls the sheet's height behavior.
// ------------------------------------------------------------------------

import SwiftUI // Provides UI building blocks for the app

/// A view for displaying and interacting with the shopping list.
struct ShoppingListView: View {
    
    // MARK: - Properties
    
    /// ViewModel providing the data and logic for the list.
    @EnvironmentObject var listViewModel: ListViewModel
    
    /// State to control the display of the Add New Item sheet.
    @State private var addNewItem: Bool = false
    
    // MARK: - Body
    
    /// The main layout and behavior of the ShoppingListView.
    var body: some View {
        NavigationView { // Creates a navigation context for the app
            ZStack { // Layers elements on top of each other
                Color.theme.background
                    .ignoresSafeArea() // Extends background color across the entire screen
                
                VStack(spacing: 0) { // Main vertical stack for progress view and list
                    Spacer() // Pushes elements down
                    shoppingListProgressView // Progress bar at the top
                    Spacer()
                    listView // Shopping items in a list
                    Spacer()
                }
                
                VStack { // Separate stack for floating add button
                    Spacer()
                    addButton // Positioned at the bottom right
                }
            }
            .navigationTitle("Shopping List") // Sets the title at the top of the NavigationView
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)), // Animates appearing
                    removal: .opacity.combined(with: .move(edge: .trailing)) // Animates disappearing
                )
            )
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Forces stack style for navigation on all devices
        .sheet(isPresented: $addNewItem) { // Presents the AddItemView as a modal sheet
            AddItemView()
                .presentationDetents([.fraction(0.45)]) // Sets sheet height to 25% of screen height
                .presentationCornerRadius(15) // Applies corner radius for smooth sheet edges
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
            .environmentObject(listViewModel) // Injects the ViewModel into ListView
    }
    
    /// Button to add a new item to the list.
    private var addButton: some View {
        HStack {
            Spacer() // Pushes the button to the right
            Button(action: {
                addNewItem.toggle() // Shows or hides the AddItemView when tapped
            }) {
                Image(systemName: "plus.circle.fill") // Plus icon for adding a new item
                    .font(.system(size: 45)) // Sets the size of the icon
                    .foregroundStyle(
                        Color.theme.buttonIconColor,
                        Color.theme.buttonFillColor
                    )
                    .shadow(color: Color.theme.shadow, radius: 10) // Adds a drop shadow
            }
            .padding(.trailing, 20) // Pushes button away from right edge
            .padding(.bottom, 20) // Pushes button up from bottom edge
        }
    }
}

#Preview {
    /// Preview setup with a ListViewModel.
    ShoppingListView()
        .environmentObject(ListViewModel())
}
