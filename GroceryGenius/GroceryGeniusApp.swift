/*
 GroceryGeniusApp.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 06.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Application entry point. Configures a read-only Supabase repository and shows the list.

 🛠 Includes:
 - AppDelegate for orientation lock and minimal Supabase wiring using a fixed list id.

 🔰 Notes for Beginners:
 - Simplified to read items from a single fixed list without auth or default-list logic.

 📝 Last Change:
 - Switched to ReadOnlyFixedListItemsRepository and removed auth/default-list bootstrapping.
 ------------------------------------------------------------------------
 */

import SwiftUI // Brings in SwiftUI to declare views and the App entry point.
import UIKit // Needed for UIApplication delegate and orientation management.

// Inline toast manager + modifier
/// Simple inline toast presenter used at runtime for quick status messages.
final class InlineToastManager: ObservableObject { // ObservableObject so SwiftUI updates when state changes.
    @Published var isShowing = false // Whether the inline toast is visible.
    @Published var message = "" // The current message shown in the toast.
    /// Shows a toast with text for a short duration.
    /// - Parameters:
    ///   - text: The message to display.
    ///   - duration: How long the toast stays visible.
    func show(_ text: String, duration: TimeInterval = 3.0) { // Public API to display a toast.
        Task { @MainActor in // Ensure state changes occur on the main thread for UI updates.
            self.message = text // Set the message to render.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = true } // Animate in.
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) // Wait desired duration.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = false } // Animate out.
        }
    }
}
/// Visual pill representing the inline toast content.
private struct InlineToastView: View { // Private because it’s only used here.
    let text: String // The text to show inside the toast.
    var body: some View { // View body for the toast appearance.
        HStack(spacing: 8) { // Horizontal layout with icon and text spaced 8pt.
            Image(systemName: "bolt.horizontal.circle.fill").foregroundColor(.white) // Lightning icon with white tint.
            Text(text).font(.subheadline.weight(.semibold)).foregroundColor(.white) // Message label styled for readability.
        }
        .padding(.horizontal, 14).padding(.vertical, 10) // Inner padding to create a pill shape.
        .background(Color.black.opacity(0.78)) // Dark background with some transparency.
        .clipShape(Capsule()) // Round the background into a capsule.
        .shadow(radius: 8) // Soft drop shadow for depth.
        .padding(.top, 12) // Separate from top edge.
    }
}
/// ViewModifier that overlays InlineToastView at the top when visible.
private struct InlineToastOverlay: ViewModifier { // Modifier so any view can show the toast.
    @ObservedObject var manager: InlineToastManager // Observes visibility and message changes.
    func body(content: Content) -> some View { // Required method to transform the content.
        ZStack(alignment: .top) { // Overlay toast above the content.
            content // The original content is the base layer.
            if manager.isShowing { InlineToastView(text: manager.message).transition(.move(edge: .top).combined(with: .opacity)) } // Show toast with transition if visible.
        }
    }
}
/// Convenience extension to attach the inline toast overlay.
extension View { func toastInline(using manager: InlineToastManager) -> some View { modifier(InlineToastOverlay(manager: manager)) } } // Helper function returning the modified view.

// Orientation lock delegate
/// UIApplication delegate responsible for reporting supported orientations.
final class AppDelegate: NSObject, UIApplicationDelegate { // NSObject base for Objective‑C runtime integration.
    static var orientationLock = UIInterfaceOrientationMask.portrait // Static lock defaulting to portrait.
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { AppDelegate.orientationLock } // Called by system to ask supported orientations.
}

/// The main application type; entry point marked with @main.
@main
struct GroceryGeniusApp: App { // Conforms to App to define app lifecycle and scenes.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate // Bridges UIKit delegate into SwiftUI.

    private let listViewModel: ListViewModel // Root list view model shared via environment.
    private let toastManager = InlineToastManager() // Toast manager instance injected into root view
    private let configMissingToast: Bool // Whether to show a config-missing toast on first render.

    /// Initializes dependencies and resolves the initial list context.
    init() { // App initialization occurs before the body is evaluated.
        // Orientation request for portrait
        if #available(iOS 16.0, *) { // Use iOS 16 scene geometry APIs when available.
            UIApplication.shared.connectedScenes.forEach { scene in // Iterate all connected scenes (windows).
                guard let windowScene = scene as? UIWindowScene else { return } // Only handle UIWindowScene instances.
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) // Request portrait orientation.
                let keyWindow = windowScene.windows.first { $0.isKeyWindow } // Find the key window if any.
                keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() // Ask VC to refresh supported orientations.
            }
        }
        // Use Supabase read-only repo pointing to a fixed list id.
        if let config = SupabaseConfigLoader.load(), let client = AppSupabaseClient(config: config) { // Load Supabase config and create client.
            let itemsRepo = ReadOnlyFixedListItemsRepository(client: client) // Read-only repo for fixed list.
            let fixedList = UUID(uuidString: "10000000-0000-0000-0000-000000000001") ?? UUID() // Fixed list id.
            self.listViewModel = ListViewModel(listId: fixedList, repository: itemsRepo, startImmediately: true) // VM for the fixed list.
            self.configMissingToast = false // No toast needed when config is present.
        } else { // No Supabase config -> show an error and use a minimal preview VM so UI loads.
            let previewRepo = PreviewItemsRepository() // In-memory items to keep UI responsive.
            let previewList = UUID(uuidString: "00000000-0000-0000-0000-00000000ABCD") ?? UUID() // Placeholder id for preview.
            self.listViewModel = ListViewModel(listId: previewList, repository: previewRepo, startImmediately: true) // Do not start observation.
            self.configMissingToast = true // Defer toast to body task to avoid capturing self in init.
        }
    }

    /// Defines the app's window group scene and root view composition.
    var body: some Scene { // Top-level scene container for the app's UI.
        WindowGroup { // Primary window scene for iOS apps.
            ShoppingListView() // Root content view showing the shopping list.
                .environmentObject(listViewModel) // Inject shared list view model for the entire hierarchy.
                .toastInline(using: toastManager) // Attach inline toast overlay to the root.
                .task { if configMissingToast { toastManager.show("Supabase config missing") } } // Show toast after init if needed.
        }
    }
}
