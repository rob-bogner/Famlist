/*
 GroceryGeniusApp.swift

 GroceryGenius
 Created on: 27.11.2023
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Application entry point. Configures Supabase client, sets orientation, and wires the root SwiftUI scene with dependencies.

 🛠 Includes:
 - AppDelegate for orientation lock, InlineToast manager + modifier, Supabase config loader usage, initial list resolution, and a connectivity probe.

 🔰 Notes for Beginners:
 - @main marks the app’s entry. Dependencies are created in init and injected via environmentObject.
 - Orientation is restricted to portrait for a consistent UX; update if you support landscape.

 📝 Last Change:
 - Standardized file header and moved SyncWaitError out of a generic function to fix a Swift compile error.
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
    private let toastManager = InlineToastManager() // Toast manager instance injected into root view.
    private var supabaseClient: AppSupabaseClient? = nil // Optional Supabase client when configuration is available.

    /// Initializes dependencies and resolves the initial list context.
    init() { // App initialization occurs before the body is evaluated.
        // Remove unsupported direct orientation set; we rely on geometryUpdate below
        // UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        if #available(iOS 16.0, *) { // Use iOS 16 scene geometry APIs when available.
            UIApplication.shared.connectedScenes.forEach { scene in // Iterate all connected scenes (windows).
                guard let windowScene = scene as? UIWindowScene else { return } // Only handle UIWindowScene instances.
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) // Request portrait orientation.
                let keyWindow = windowScene.windows.first { $0.isKeyWindow } // Find the key window if any.
                keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() // Ask VC to refresh supported orientations.
            }
        }
        if let config = SupabaseConfigLoader.load(), let client = AppSupabaseClient(config: config) { // Try to load Supabase credentials and create a client.
            self.supabaseClient = client // Hold onto the client for later use (optional).
            let listId = GroceryGeniusApp.resolveInitialListId(using: client) // Compute initial list id (persisted or fetched).
            UserDefaults.standard.set(listId.uuidString, forKey: "CurrentListID") // Persist chosen list id for next app launch.
            let repo = SupabaseItemsRepository(client: client) // Concrete Items repository backed by Supabase.
            self.listViewModel = ListViewModel(listId: listId, repository: repo) // Create the view model with current list and repo.
            GroceryGeniusApp.scheduleConnectivityProbe(client: client, toastManager: toastManager, viewModel: listViewModel) // Schedule a light DB connectivity probe.
        } else { // Fallback when config is missing or client creation fails.
            self.listViewModel = ListViewModel() // Use preview/in-memory repository for offline mode.
            let tm = self.toastManager // Local binding to manager for use inside Task closure.
            Task { @MainActor in tm.show("Supabase config missing") } // Show a toast informing about missing config.
        }
    }

    /// Defines the app's window group scene and root view composition.
    var body: some Scene { // Top-level scene container for the app's UI.
        WindowGroup { // Primary window scene for iOS apps.
            ShoppingListView() // Root content view showing the shopping list.
                .environmentObject(listViewModel) // Inject shared list view model for the entire hierarchy.
                .toastInline(using: toastManager) // Attach inline toast overlay to the root.
        }
    }

    // Resolve initial list id from persisted value, else DB
    /// Picks the initial list id by checking saved preferences and falling back to database queries.
    /// - Parameter client: Supabase client used to query the database when needed.
    /// - Returns: A UUID indicating which list to load initially.
    private static func resolveInitialListId(using client: AppSupabaseClient) -> UUID { // Static helper avoids capturing self.
        if let saved = UserDefaults.standard.string(forKey: "CurrentListID"), let savedUUID = UUID(uuidString: saved) { // Try to read previously selected list id from defaults.
            // Treat zero UUID as invalid
            let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000001")! // Special invalid/placeholder UUID value.
            if savedUUID != zero { // Only accept if not the invalid placeholder.
                // Verify the saved list id actually has items (or at least exists via items reference)
                do { // Use a tiny query to confirm the list id is used in items table.
                    struct Row: Decodable { let id: UUID } // Minimal row type to decode select("id").
                    let rows: [Row] = try awaitResult { // Run async code synchronously with timeout.
                        try await client.from("items").select("id").eq("list_id", value: saved).limit(1).execute().value // DB query to check existence.
                    }
                    if !rows.isEmpty { return savedUUID } // If at least one row exists, keep saved list.
                } catch { /* fall through to recalc */ } // On failure, just ignore and re-resolve below.
            }
        }
        var resolved: UUID? = nil // Placeholder for the resolved id.
        let sema = DispatchSemaphore(value: 0) // Semaphore to wait for async work below.
        Task { // Start an async context to query DB.
            do { // Attempt several strategies in order.
                struct Row: Decodable { let listId: UUID; enum CodingKeys: String, CodingKey { case listId = "list_id" } } // Decode list_id column.
                let items: [Row] = try await client.from("items").select("list_id").order("created_at", ascending: true).limit(1).execute().value // Fetch first item's list_id if any.
                if let first = items.first { resolved = first.listId; sema.signal(); return } // Use first list id referenced by items.
                let defaults: [List] = try await client.from("lists").select().eq("is_default", value: true).limit(1).execute().value // Else try default list.
                if let first = defaults.first { resolved = first.id; sema.signal(); return } // Use default list if present.
                let any: [List] = try await client.from("lists").select().order("created_at", ascending: true).limit(1).execute().value // Else any list.
                resolved = any.first?.id // Choose the first by creation date.
            } catch { // On any error, leave resolved as nil.
                resolved = nil // Explicit nil to fall back below.
            }
            sema.signal() // Release the waiting thread regardless of outcome.
        }
        _ = sema.wait(timeout: .now() + 5) // Wait up to 5 seconds for async resolution.
        return resolved ?? (UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()) // Fallback to placeholder or a random UUID as last resort.
    }

    // Define error type at type scope (not inside generic function) to satisfy compiler
    private enum SyncWaitError: Error { case timeout } // Local error describing a timeout in synchronous wait.

    // Helper: run an async block synchronously with a timeout to reuse validator above
    /// Runs an async throwing operation and waits for completion with a small timeout.
    /// - Parameter work: Closure for async operation returning a value.
    /// - Returns: The value returned by the async operation.
    private static func awaitResult<T>(_ work: @escaping () async throws -> T) throws -> T { // Generic utility to bridge async into sync.
        let sema = DispatchSemaphore(value: 0) // Semaphore to block the current thread.
        var result: Result<T, Error>? = nil // Stores the eventual outcome of the async work.
        Task { // Fire the async task.
            do { result = .success(try await work()) } catch { result = .failure(error) } // Capture result or error.
            sema.signal() // Release the waiting thread.
        }
        let status = sema.wait(timeout: .now() + 5) // Wait at most 5 seconds.
        guard status == .success, let unwrapped = result else { throw SyncWaitError.timeout } // Throw timeout if no result.
        switch unwrapped { case .success(let value): return value; case .failure(let e): throw e } // Return or rethrow depending on result.
    }

    // Connectivity probe (static to avoid self capture)
    /// Schedules a lightweight connectivity test to Supabase after app launch.
    private static func scheduleConnectivityProbe(client: AppSupabaseClient, toastManager: InlineToastManager, viewModel: ListViewModel) { // Static to avoid capturing self strongly.
        Task { @MainActor in // Run after a brief delay on the main actor for UI
            try? await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds to avoid competing with initial UI work.
            await runConnectivityQuery(client: client, toastManager: toastManager, viewModel: viewModel) // Perform the query and show a toast.
        }
    }

    /// Executes a small query to test DB connectivity and optionally switches lists if persisted id has no items.
    @MainActor
    private static func runConnectivityQuery(client: AppSupabaseClient, toastManager: InlineToastManager, viewModel: ListViewModel) async { // Annotated @MainActor to safely interact with UI.
        struct DumpRow: Codable { // Minimal representation of an item row for the connectivity log.
            let id: UUID // Item id.
            let listId: UUID // Associated list id.
            let ownerPublicId: String? // Owner public id if present.
            let imageData: String? // Base64 image data (legacy field) if present.
            let name: String // Item name.
            let units: Int // Units quantity.
            let measure: String // Measurement unit.
            let price: Double // Price value.
            let isChecked: Bool // Checked flag.
            let category: String? // Optional category.
            let productDescription: String? // Optional description.
            let brand: String? // Optional brand.
            let position: Int? // Optional position for ordering.
            let createdAt: String? // Creation timestamp string.
            let updatedAt: String? // Update timestamp string.
            enum CodingKeys: String, CodingKey { case id; case listId = "list_id"; case ownerPublicId = "ownerpublicid"; case imageData = "imagedata"; case name, units, measure, price, isChecked, category; case productDescription = "productdescription"; case brand, position; case createdAt = "created_at"; case updatedAt = "updated_at" } // Map snake_case columns to camelCase.
        }
        do { // Attempt the connectivity queries.
            let all: [DumpRow] = try await client.from("items").select().order("created_at", ascending: true).execute().value // Fetch all items for logging.
            var listCount = 0 // Will store count of items for the current list.
            var savedId: String? = UserDefaults.standard.string(forKey: "CurrentListID") // Read persisted list id if available.
            if let saved = savedId, let _ = UUID(uuidString: saved) { // Validate saved id shape.
                let scoped: [DumpRow] = try await client.from("items").select().eq("list_id", value: saved).order("created_at", ascending: true).execute().value // Fetch items for saved list.
                listCount = scoped.count // Count them.
                if let data = try? JSONEncoder().encode(scoped), let json = String(data: data, encoding: .utf8) { print("[DB Connectivity] items for list_id=\(saved): \(scoped.count) rows=\n\(json)") } // Log JSON snapshot to console.
                // Auto-correct: if saved list has zero items but we do have items overall, switch to first list id
                if listCount == 0, let first = all.first?.listId { // No items for saved id but we have items overall.
                    let newId = first // Pick the first list id found.
                    UserDefaults.standard.set(newId.uuidString, forKey: "CurrentListID") // Persist the corrected id.
                    viewModel.switchList(to: newId) // Ask view model to switch observation to the new list.
                    toastManager.show("Switched to list • items: \(all.filter{ $0.listId == newId }.count)") // Inform user via toast.
                    savedId = newId.uuidString // Update local saved id variable too.
                }
            }
            toastManager.show("Connected to DB • items: \(all.count) • list items: \(listCount)") // Show success with counts.
            if let data = try? JSONEncoder().encode(all), let json = String(data: data, encoding: .utf8) { print("[DB Connectivity] ALL items=\(all.count) rows=\n\(json)") } else { print("[DB Connectivity] ALL items=\(all.count) (JSON encoding failed)") } // Log all items snapshot or failure.
        } catch { // On failure of any query, surface error.
            toastManager.show("DB query failed: \(error.localizedDescription)") // Show failure toast with description.
            print("[DB Connectivity] ERROR: \(error)") // Print error to console for debugging.
        }
    }
}
