/*
 FamlistApp.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 15.11.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Application entry point responsible only for dependency composition and root view wiring.

 🛠 Includes:
 - Supabase config/client creation, repository DI, and environment object injection for view models.

 🔰 Notes for Beginners:
 - No UI, toasts, or DB logic should live here; SwiftUI Views and ViewModels handle that.
 - When Supabase config is missing, preview/in-memory repositories are used so the app still runs.

 📝 Last Change:
 - Injected ConnectivityMonitor so view models resume realtime sync after backgrounding or offline periods.
 ------------------------------------------------------------------------
 */

import SwiftUI // SwiftUI defines the App protocol and view system used in this project.
import SwiftData // SwiftData provides the local model container for offline-first storage.

/// The main application type; entry point marked with @main.
@main
struct FamlistApp: App { // Conforms to App to define app lifecycle and scenes.
    // MARK: - Root ViewModels
    private let listViewModel: ListViewModel // Shared list VM used by list screens.
    private let sessionViewModel: AppSessionViewModel // Root session/auth coordinator.
    private let modelContainer: ModelContainer // Shared SwiftData container backing local-first storage.
    private let connectivityMonitor: ConnectivityMonitor // Shared connectivity observer injected into view models.
    private let syncMonitor: SyncMonitor // Shared sync monitor for tracking sync status and metrics.

    // MARK: - Init (Dependency Composition)
    /// Initializes repositories and view models for the app.
    @MainActor
    init() { // Construct dependencies for the running app.
        let persistenceController: PersistenceController // Decide which persistence flavour to use.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { // Detect SwiftUI preview context.
            persistenceController = .preview // Use transient in-memory storage during previews.
        } else {
            persistenceController = .shared // Use the disk-backed container for the live app.
        }
        self.modelContainer = persistenceController.container // Store container for scene modifier injection.
        self.connectivityMonitor = ConnectivityMonitor.shared // Store connectivity monitor for later dependency injection.
        self.syncMonitor = SyncMonitor() // Create sync monitor for tracking sync operations
        
        // Initialize SwiftData stores
        let itemStore = SwiftDataItemStore(context: modelContainer.mainContext)
        let listStore = SwiftDataListStore(context: modelContainer.mainContext)

        if let config = SupabaseConfigLoader.load(), // Try to load Supabase secrets from bundle.
           let client = AppSupabaseClient(config: config) { // Initialize the Supabase client if configured.
            // Initialize CRDT components
            let conflictResolver = ConflictResolver()
            let hlcGenerator = HybridLogicalClockGenerator()
            
            // Repositories backed by Supabase with CRDT support
            let itemsRepo = SupabaseItemsRepository(
                client: client,
                itemStore: itemStore,
                conflictResolver: conflictResolver
            )
            let profilesRepo = SupabaseProfilesRepository(client: client)
            let listsRepo = SupabaseListsRepository(client: client)
            
            // Create operation queue for sync engine
            let operationQueue = OperationQueue(context: modelContainer.mainContext)
            
            // Create sync engine
            let syncEngine = SyncEngine(
                repository: itemsRepo,
                itemStore: itemStore,
                operationQueue: operationQueue,
                conflictResolver: conflictResolver,
                hlcGenerator: hlcGenerator
            )
            
            // Create list VM without starting observation; it will start after auth completes.
            let initialList = UUID() // Placeholder id until default list is resolved.
            let lvm = ListViewModel(
                listId: initialList,
                repository: itemsRepo,
                itemStore: itemStore,
                listStore: listStore,
                startImmediately: false
            )
            lvm.configure(connectivityMonitor: connectivityMonitor)
            lvm.configure(syncEngine: syncEngine)
            self.listViewModel = lvm
            
            // Create the session VM that coordinates auth and default list bootstrap.
            self.sessionViewModel = AppSessionViewModel(client: client, profiles: profilesRepo, lists: listsRepo, listViewModel: lvm)
        } else { // Fallback when Supabase config is missing: use preview/in-memory repos.
            // In-memory repositories for previews/offline demo.
            let itemsRepo = PreviewItemsRepository() // Items repo in memory.
            let profilesRepo = PreviewProfilesRepository() // Profiles repo in memory.
            let listsRepo = PreviewListsRepository() // Lists repo in memory.
            // Create list VM (observation can start now, but no items until user adds some).
            let previewList = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID() // Stable preview id.
            let lvm = ListViewModel(
                listId: previewList,
                repository: itemsRepo,
                itemStore: itemStore,
                listStore: listStore,
                startImmediately: true
            ) // Start observing immediately in preview mode.
            lvm.configure(connectivityMonitor: connectivityMonitor) // Wire connectivity monitoring for preview repos too, keeping API usage consistent.
            self.listViewModel = lvm // Save list VM.
            // Session VM without a client (auth disabled in previews); remains unauthenticated.
            self.sessionViewModel = AppSessionViewModel(client: nil, profiles: profilesRepo, lists: listsRepo, listViewModel: lvm) // Root VM with preview repos.
        }
    }

    // MARK: - Scene
    /// Defines the app's window group scene and root view composition.
    var body: some Scene { // Top-level scene container for the app's UI.
        WindowGroup { // Primary window scene for iOS apps.
            RootView() // Root view deciding between AuthView and ShoppingListView.
                .environmentObject(sessionViewModel) // Inject shared session VM for auth state.
                .environmentObject(listViewModel) // Inject shared list VM for list screens.
                .environmentObject(syncMonitor) // Inject sync monitor for status tracking
                .modelContainer(modelContainer) // Expose SwiftData container to the view hierarchy.
        }
    }
}
