/*
 FamlistApp.swift

 Famlist
 Created on: 27.11.2023
 Last updated on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Application entry point responsible only for dependency composition and root view wiring.

 🛠 Includes:
 - Supabase config/client creation, repository DI, and environment object injection for view models.

 🔰 Notes for Beginners:
 - No UI, toasts, or DB logic should live here; SwiftUI Views and ViewModels handle that.
 - When Supabase config is missing, preview/in-memory repositories are used so the app still runs.

 📝 Last Change:
 - DEBUG only: launch argument -uiTestFixture shows ShoppingListView with in-memory data (UITestFixture) for UI tests.
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
    private let categoryStore: CategoryStore // Kategorien des Nutzers (Ladenweg), Redesign „Hybrid“ Phase 6.
    private let priceBook: PriceBook // Preise aus Kassenzetteln (offline zuerst), Redesign „Hybrid“ Phase 7.

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
            // HLC-Uhr mit gespeicherter Geräte-ID und letztem Stand (über Neustarts monoton).
            let hlcGenerator = HybridLogicalClockGenerator(defaults: .standard)
            
            // Sync orchestrator serialises PageLoader and Realtime event processing (FAM-79).
            let syncOrchestrator = SyncOrchestrator()

            // Repositories backed by Supabase with CRDT support
            let itemsRepo = SupabaseItemsRepository(
                client: client,
                itemStore: itemStore,
                syncOrchestrator: syncOrchestrator
            )
            let profilesRepo = SupabaseProfilesRepository(client: client)
            let listsRepo = SupabaseListsRepository(client: client)
            
            // Produktfotos in Supabase Storage (Migration 016).
            let imageStorage = SupabaseImageStorage(client: client)

            // Create operation queue for sync engine
            let operationQueue = SyncOperationQueue(context: modelContainer.mainContext)
            
            // Create sync engine
            let syncEngine = SyncEngine(
                repository: itemsRepo,
                itemStore: itemStore,
                operationQueue: operationQueue,
                hlcGenerator: hlcGenerator,
                syncMonitor: syncMonitor,
                imageStorage: imageStorage,
                isOnline: { ConnectivityMonitor.shared.isOnline }
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
            lvm.configure(imageStorage: imageStorage)
            // Artikelstamm offline zuerst: lokale Warteschlange, Senden sofort bzw. sobald wieder Netz da ist.
            lvm.configure(catalogRepository: OfflineItemCatalogRepository(
                remote: SupabaseItemCatalogRepository(client: client),
                reconnect: connectivityMonitor.$isOnline.eraseToAnyPublisher()))
            lvm.configure(globalCatalogRepository: SupabaseGlobalProductCatalogRepository(client: client))
            // Wire pagination (FAM-79/FAM-40).
            let pageLoader = PageLoader(repository: itemsRepo)
            lvm.configure(syncOrchestrator: syncOrchestrator, pageLoader: pageLoader)
            self.listViewModel = lvm

            // Create the session VM that coordinates auth and default list bootstrap.
            self.sessionViewModel = AppSessionViewModel(client: client, profiles: profilesRepo, lists: listsRepo, listViewModel: lvm)
            self.categoryStore = CategoryStore(repository: SupabaseCategoryDefinitionsRepository(client: client))
            self.priceBook = PriceBook(repository: SupabasePricePointsRepository(client: client),
                                       reconnect: connectivityMonitor.$isOnline.eraseToAnyPublisher())
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
            lvm.configure(syncEngine: PreviewSyncEngine(repository: itemsRepo)) // Preview sync engine: delegates to in-memory repo, no CRDT needed.
            lvm.configure(catalogRepository: PreviewItemCatalogRepository()) // Preview catalog for offline demo.
            lvm.configure(globalCatalogRepository: PreviewGlobalProductCatalogRepository()) // Preview OFF catalog for offline demo.
            self.listViewModel = lvm // Save list VM.
            // Session VM without a client (auth disabled in previews); remains unauthenticated.
            self.sessionViewModel = AppSessionViewModel(client: nil, profiles: profilesRepo, lists: listsRepo, listViewModel: lvm) // Root VM with preview repos.
            self.categoryStore = CategoryStore(repository: nil)
            self.priceBook = PriceBook(repository: nil) // Ohne Supabase bleiben Preise in der lokalen Warteschlange.
        }
    }

    // MARK: - Scene
    /// Defines the app's window group scene and root view composition.
    var body: some Scene { // Top-level scene container for the app's UI.
        WindowGroup { // Primary window scene for iOS apps.
            #if DEBUG
            if UITestFixture.isActive { // UI tests (-uiTestFixture): in-memory list, no Supabase.
                UITestFixture.rootView
                    .environmentObject(UITestFixture.listVM)
                    .environmentObject(UITestFixture.session)
                    .environmentObject(UITestFixture.categoryStore)
                    .environmentObject(UITestFixture.priceBook)
            } else {
                appRoot
            }
            #else
            appRoot
            #endif
        }
    }

    /// Regular root view with all shared environment objects.
    private var appRoot: some View {
        RootView() // Root view deciding between AuthView and ShoppingListView.
            .environmentObject(sessionViewModel) // Inject shared session VM for auth state.
            .environmentObject(listViewModel) // Inject shared list VM for list screens.
            .environmentObject(syncMonitor) // Inject sync monitor for status tracking
            .environmentObject(categoryStore) // Kategorien (Ladenweg) für Liste und „Kategorien verwalten“
            .environmentObject(priceBook) // Kassenzettel → Preise, Preisverlauf
            .modelContainer(modelContainer) // Expose SwiftData container to the view hierarchy.
    }
}
