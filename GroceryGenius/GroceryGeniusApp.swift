/*
GroceryGenius
GroceryGeniusApp.swift
Created by Robert Bogner on 27.11.23.

The main entry point of the Grocery Genius app.
Configures the app's initial view and environment.
*/

import SwiftUI
import FirebaseCore // <- notwendig für FirebaseApp.configure()

@main
struct GroceryGeniusApp: App {
    init() {
        FirebaseApp.configure() // <- Initialisiere Firebase beim Start
    }

    var body: some Scene {
        WindowGroup {
            ShoppingListView()
                .environmentObject(ListViewModel())
        }
    }
}

// Note: The `@main` attribute identifies `GroceryGeniusApp` as the app's entry point.
// `WindowGroup` creates a new window for the app's UI, and `ShoppingListView` is set as the initial view.
// The `ListViewModel` is injected as an environment object to be accessible throughout the app.
