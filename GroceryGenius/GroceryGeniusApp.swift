/*
 File: GroceryGeniusApp.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 Application entry point. Configures Firebase and locks orientation to portrait. Injects global ListViewModel and presents ShoppingListView.

 Responsibilities / Includes:
 - Firebase initialization
 - Orientation lock (portrait)
 - Root scene/window creation via WindowGroup
 - EnvironmentObject injection of ListViewModel

 Design Notes:
 - Orientation lock implemented using UIApplicationDelegateAdaptor + geometry update for iOS 16+
 - Consider moving DI (view model) into a lightweight container if scale increases
 - Using NavigationStack (future refactor) could simplify navigation state handling

 Possible Enhancements:
 - Add app-wide error logging/analytics bootstrap
 - Introduce feature flags or remote config fetch during init
 - Support dynamic orientation for image picker only (temporarily overriding lock)
*/

import SwiftUI
import FirebaseCore

// MARK: - Orientation Lock Delegate
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { AppDelegate.orientationLock }
}

@main
struct GroceryGeniusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FirebaseApp.configure()
        UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        if #available(iOS 16.0, *) {
            UIApplication.shared.connectedScenes.forEach { scene in
                guard let windowScene = scene as? UIWindowScene else { return }
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ShoppingListView()
                .environmentObject(ListViewModel())
        }
    }
}
