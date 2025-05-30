//
// GroceryGenius
// ShoppingListView.swift
// Created on: 27.11.2023
// Last updated on: 26.05.2025
//
// ------------------------------------------------------------------------
// 📄 File Overview:
//
// This file defines the main shopping list view, featuring a decorative accent header
// background, a visually engaging progress bar, and a modern, ticket-app-inspired layout.
// The UI includes a quick-add row, floating action button, and modal for advanced item entry.
//
// 🖌️ Modern UI Features:
// - AccentHeaderBackground: Decorative, ticket-style accent header with rounded corners
// - Progress bar and list content layered in a visually distinct header section
// - Floating quick-add action button with animated icon (plus/paperplane)
// - Seamless support for Light and Dark Mode via theme colors
// - Modal sheet for advanced item creation
// - Tap-gesture overlay for dismissing quick-add input
//
// 🧑‍💻 Developer Notes:
// - Uses `@EnvironmentObject` for ListViewModel
// - Quick-Add field is always present for smooth transitions/animations
// - All accent and card backgrounds are handled via the theme extension
// - Animations and transitions utilize SwiftUI's animation system
//
// ------------------------------------------------------------------------

import SwiftUI // Provides UI building blocks for the app

/// A view for displaying and interacting with the shopping list.
struct ShoppingListView: View {
    /// Provides access to the device's safe area insets (including bottom for iPhones with Home Indicator)
    
    // MARK: - Properties
    
    /// ViewModel providing the data and logic for the list.
    @EnvironmentObject var listViewModel: ListViewModel
    
    /// State to control the display of the Add New Item sheet.
    @State private var addNewItem: Bool = false
    /// Controls if the quick-add input field is shown.
    @State private var quickAddActive: Bool = false
    /// Holds the current text entered in the quick-add field.
    @State private var quickAddText: String = ""
    /// Focus state for the quick-add input, triggers keyboard appearance.
    @FocusState private var quickAddFocused: Bool
    
    // MARK: - Body
    
    /// The main layout and behavior of the ShoppingListView.
    var body: some View {
        NavigationView { // Creates a navigation context for the app
            // Changed main container to a ZStack aligned at the top to layer header and content
            ZStack(alignment: .top) {
                // Decorative header background with accent color and rounded bottom corners
                AccentHeaderBackground()
                    .frame(height: UIScreen.main.bounds.height * 0.24) // Changed header height from 0.29 to 0.27 for better layout spacing
                    .zIndex(0) // Always at the back of the ZStack
                
                // Header content (navigation title and progress bar) overlays the accent header
                VStack(alignment: .leading, spacing: 12) { // Changed VStack alignment to leading and added spacing 12 for header layout
                    Text("Shopping List")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 30) // Changed from 48 to 30 for less top padding (adjusted as requested)
                        .padding(.leading, 18) // Changed from 24 to 18 for left alignment consistency (adjusted as requested)

                    shoppingListProgressView // Progress bar sits inside the header
                        .padding(.top, 8) // Added top padding to position progress bar lower in header

                    Spacer().frame(height: 4) // Much smaller space below progress bar (explicit 4pt)
                }
                .frame(height: UIScreen.main.bounds.height * 0.24, alignment: .top) // Changed header height from 0.29 to 0.27 for better layout spacing
                .zIndex(1) // Above background
                
                // Main app content (list, quick-add, overlay), starts exactly under the header
                VStack(spacing: 0) {
                    // Spacer to leave space for the header so content starts below it
                    Spacer().frame(height: UIScreen.main.bounds.height * 0.20) // Changed spacer height from 0.29 to 0.23 to reduce gap below header
                    
                    ZStack(alignment: .bottomTrailing) {
                        listView // Main list of items, aligned with the button below
                        
                        // The "tap outside to close" overlay is inserted below the addButton.
                        // Only active while quickAddActive is true.
                        if quickAddActive {
                            Color.black.opacity(0.001) // Invisible hit area for dismiss gesture
                                .ignoresSafeArea()
                                .contentShape(Rectangle()) // Ensures the tap area is the entire content except button/textfield
                                .onTapGesture {
                                    withAnimation {
                                        quickAddActive = false // Hide the quick-add row with animation
                                    }
                                    quickAddFocused = false // Dismiss keyboard when tap occurs outside
                                }
                                .allowsHitTesting(true) // Makes sure taps are captured outside the button/textfield
                        }
                        
                        addButton
                            .padding(.trailing, 0) // No extra padding, aligns to ListView's trailing edge
                            .padding(.bottom, 16) // Space from bottom content (not screen edge)
                    }
                    Spacer()
                }
                .zIndex(2) // Ensure content is above header and background
            }
            .navigationBarHidden(true) // Hide default navigation bar to use custom title in header
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
                .presentationDetents([.fraction(0.45), .large, .medium]) // Sets sheet height to 25% of screen height
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
    
    /// Quick-add row: The add button is always at the trailing (right) edge of the view.
    /// The text field expands from right to left, creating a seamless capsule with the button overlaid on the right.
    /// This matches native iOS behavior and the desired mockup.
    private var addButton: some View {
        ZStack(alignment: .trailing) { // Layer the button above the trailing edge of the text field
            // The TextField is always present in the view hierarchy,
            // its width and opacity are animated based on quickAddActive state.
            TextField("Add item...", text: $quickAddText, onCommit: {
                addQuickItem() // Adds the item on return key
            })
            .padding(.horizontal, 14) // Padding inside the text field
            .frame(
                minWidth: 0, // Allows collapse to zero width
                maxWidth: quickAddActive ? .infinity : 0, // Expands leftward from button when active
                alignment: .trailing // Right edge stays fixed under the button
            )
            .frame(height: 52) // Matches button height
            .background(Color.theme.background) // Text field background (adapts to light/dark mode)
            .overlay(
                Capsule().stroke(Color.theme.accent, lineWidth: 2) // Accent border
            )
            .clipShape(Capsule()) // Perfectly round corners
            .focused($quickAddFocused) // Keyboard on focus
            .opacity(quickAddActive ? 1 : 0) // Fades in/out smoothly
            .animation(.easeOut(duration: 0.2), value: quickAddActive) // Smooth, visible animation
            .transition(.identity) // No slide, only width/opacity

            // The Add button remains fixed at the trailing/right edge
            Button(action: {
                if quickAddActive {
                    addQuickItem() // Adds item if field is open
                } else {
                    quickAddFocused = true // Keyboard pops up immediately for fast typing
                    // Animate the expansion of the quick-add field slightly after the keyboard shows,
                    // so the user can instantly start typing and the animation is still visible.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation {
                            quickAddActive = true // Expands the quick add field with animation
                        }
                    }
                }
            }) {
                // The button icon switches between plus and a rotated paperplane with animation.
                Image(systemName: quickAddActive ? "paperplane.fill" : "plus")
                    .rotationEffect(quickAddActive ? .degrees(45) : .degrees(0)) // Rotates the paperplane symbol
                    .animation(.easeInOut(duration: 0.28), value: quickAddActive) // Smooth transition for icon and rotation
                    .font(.system(size: 22, weight: .bold))
                    .frame(
                        width: quickAddActive ? 38 : 48, // Button shrinks when Quick-Add is active
                        height: quickAddActive ? 38 : 48
                    )
                    .animation(.easeInOut(duration: 0.26), value: quickAddActive) // Animate size change
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.theme.accent))
                    .overlay(
                        Circle().stroke(Color.theme.accent, lineWidth: 2)
                    )
                    .offset(x: quickAddActive ? -8 : 0) // Shift left by 8pt when Quick-Add is open
                    .animation(.easeInOut(duration: 0.24), value: quickAddActive) // Animate offset change
            }
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.7).onEnded { _ in
                quickAddActive = false
                quickAddText = ""
                addNewItem = true
            })
        }
        .padding(.horizontal, 16) // Aligns with ListView edges
        .padding(.bottom, 16) // Space from the bottom of the screen
        .frame(height: 48, alignment: .trailing) // Stack height matches new sizing
    }
    
    /// Adds the item from the quick-add field.
    /// Trims whitespace, creates a new ItemModel, and passes it to the ViewModel.
    /// Resets and hides the quick-add input after adding.
    private func addQuickItem() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines) // Removes spaces at the start/end of the input
        guard !trimmed.isEmpty else { return } // Exits if the field is empty
        let newItem = ItemModel(name: trimmed) // Creates a new ItemModel using the input as name
        listViewModel.addItem(newItem)         // Passes the new ItemModel to the ViewModel (adds it to the list)
        quickAddText = ""                      // Clears the text field for future input
        withAnimation {
            quickAddActive = false             // Hides the quick-add field with animation
        }
        quickAddFocused = false // Dismiss keyboard after successfully adding item
    }
}

#Preview {
    /// Preview setup with a ListViewModel.
    ShoppingListView()
        .environmentObject(ListViewModel())
}
