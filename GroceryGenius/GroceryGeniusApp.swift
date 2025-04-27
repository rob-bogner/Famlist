/*
 GroceryGenius
 GroceryGeniusApp.swift
 Created by Robert Bogner on 27.11.23.

 The main entry point for the Grocery Genius app.
 Initializes Firebase services and sets up the initial view and environment.
*/

import SwiftUI
import FirebaseCore // Necessary for initializing FirebaseApp

/// The main application structure for Grocery Genius.
@main
struct GroceryGeniusApp: App {
    
    // MARK: - Initializer
    
    init() {
        FirebaseApp.configure() // Initializes Firebase when the app launches
    }

    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ShoppingListView()
                .environmentObject(ListViewModel())
        }
    }
}

// Note:
// - The `@main` attribute marks GroceryGeniusApp as the app’s entry point.
// - `WindowGroup` creates a new window displaying ShoppingListView.
// - The `ListViewModel` is injected as an environment object for global accessibility.
