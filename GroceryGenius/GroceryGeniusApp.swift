/*
 File: GroceryGeniusApp.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 Application entry point. Configures Firebase and locks orientation to portrait. Routes into SessionGateView (onboarding/auth) and injects dependencies.
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
        #if DEBUG
        if let app = FirebaseApp.app() {
            let o = app.options
            // Cast to optional to handle both optional and non-optional properties uniformly without warnings
            let pid = (o.projectID as String?) ?? "-"
            let cid = (o.clientID as String?) ?? "-"
            let bid = (o.bundleID as String?) ?? (Bundle.main.bundleIdentifier ?? "-")
            print("[Firebase] projectID=\(pid) appID=\(o.googleAppID) clientID=\(cid) bundleID=\(bid)")
        } else {
            print("[Firebase] FirebaseApp not configured. Ensure GoogleService-Info.plist is in target and FirebaseApp.configure() is called.")
        }
        #endif
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
            // Root gate now auto-provisions a user id
            SessionGateView(idService: FirestoreUserIdService())
                .environmentObject(ListViewModel())
        }
    }
}
