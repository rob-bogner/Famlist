/*
 GroceryGeniusApp.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 26.04.2025

 ------------------------------------------------------------------------
 📄 File Overview:

 This file defines the main entry point for the Grocery Genius app.
 It configures necessary services (like Firebase) and specifies
 which view is presented to the user when the app launches.

 🛠 Includes:
 - Initialization of Firebase services
 - Setup of the main application window
 - Injecting the central ListViewModel as an EnvironmentObject

 🔰 Notes for Beginners:
 - Every SwiftUI app requires exactly one @main structure.
 - The app execution starts inside the `body` property.
 - `WindowGroup` creates the main window for your user interface.
 ------------------------------------------------------------------------
*/

import SwiftUI // Imports the SwiftUI framework for building the user interface
import FirebaseCore // Imports FirebaseCore to initialize Firebase services

// MARK: - Orientation Lock Helper

/// Hilfsklasse für die Orientierungssperre
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

/// The main application structure for Grocery Genius.
/// Defines the initial configuration and view hierarchy of the app.
@main // Marks this structure as the entry point of the app.
struct GroceryGeniusApp: App {
    // MARK: - App Delegate Registration
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - Initializer

    /// This initializer is automatically called when the app launches.
    /// Here, we configure Firebase before any views are displayed.
    init() {
        FirebaseApp.configure() // Initializes Firebase services for the app
        
        // Einschränkung auf Portrait-Modus (nur vertikale Ausrichtung)
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        
        // Unterstützte Ausrichtungen auf nur Portrait-Modus begrenzen
        if #available(iOS 16.0, *) {
            // iOS 16 und neuer
            UIApplication.shared.connectedScenes.forEach { scene in
                if let windowScene = scene as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                    windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }
    }

    // MARK: - Body

    /// Defines the main scene (window) for the app.
    /// Specifies which view will be shown first to the user.
    var body: some Scene {
        WindowGroup { // Creates a window that hosts the content view
            ShoppingListView() // Displays the ShoppingListView as the first screen
                .environmentObject(ListViewModel()) // Injects ListViewModel globally into the environment
        }
    }
}

// ------------------------------------------------------------------------
// Important Notes:
// - Without `FirebaseApp.configure()`, Firestore and Firebase Authentication won't work.
// - Using `.environmentObject()` allows child views to access ListViewModel without direct injection.
// - The app is now locked to portrait orientation only.
// ------------------------------------------------------------------------
