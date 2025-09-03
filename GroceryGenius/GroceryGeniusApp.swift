/*
 File: GroceryGeniusApp.swift
 Project: GroceryGenius
 Created: 27.11.2023
 Last Updated: 17.08.2025

 Overview:
 Application entry point. Configures Supabase client and locks orientation to portrait. Injects global ListViewModel and presents ShoppingListView.
*/

import SwiftUI
import UIKit

// Inline toast manager + modifier
final class InlineToastManager: ObservableObject {
    @Published var isShowing = false
    @Published var message = ""
    func show(_ text: String, duration: TimeInterval = 3.0) {
        Task { @MainActor in
            self.message = text
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = true }
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.isShowing = false }
        }
    }
}
private struct InlineToastView: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle.fill").foregroundColor(.white)
            Text(text).font(.subheadline.weight(.semibold)).foregroundColor(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.black.opacity(0.78))
        .clipShape(Capsule())
        .shadow(radius: 8)
        .padding(.top, 12)
    }
}
private struct InlineToastOverlay: ViewModifier {
    @ObservedObject var manager: InlineToastManager
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if manager.isShowing { InlineToastView(text: manager.message).transition(.move(edge: .top).combined(with: .opacity)) }
        }
    }
}
extension View { func toastInline(using manager: InlineToastManager) -> some View { modifier(InlineToastOverlay(manager: manager)) } }

// Orientation lock delegate
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask { AppDelegate.orientationLock }
}

@main
struct GroceryGeniusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let listViewModel: ListViewModel
    private let toastManager = InlineToastManager()
    private var supabaseClient: AppSupabaseClient? = nil

    init() {
        // Remove unsupported direct orientation set; we rely on geometryUpdate below
        // UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        if #available(iOS 16.0, *) {
            UIApplication.shared.connectedScenes.forEach { scene in
                guard let windowScene = scene as? UIWindowScene else { return }
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
                let keyWindow = windowScene.windows.first { $0.isKeyWindow }
                keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
        if let config = SupabaseConfigLoader.load(), let client = AppSupabaseClient(config: config) {
            self.supabaseClient = client
            let listId = GroceryGeniusApp.resolveInitialListId(using: client)
            UserDefaults.standard.set(listId.uuidString, forKey: "CurrentListID")
            let repo = SupabaseItemsRepository(client: client)
            self.listViewModel = ListViewModel(listId: listId, repository: repo)
            GroceryGeniusApp.scheduleConnectivityProbe(client: client, toastManager: toastManager, viewModel: listViewModel)
        } else {
            self.listViewModel = ListViewModel()
            let tm = self.toastManager
            Task { @MainActor in tm.show("Supabase config missing") }
        }
    }

    var body: some Scene {
        WindowGroup {
            ShoppingListView()
                .environmentObject(listViewModel)
                .toastInline(using: toastManager)
        }
    }

    // Resolve initial list id from persisted value, else DB
    private static func resolveInitialListId(using client: AppSupabaseClient) -> UUID {
        if let saved = UserDefaults.standard.string(forKey: "CurrentListID"), let savedUUID = UUID(uuidString: saved) {
            // Treat zero UUID as invalid
            let zero = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            if savedUUID != zero {
                // Verify the saved list id actually has items (or at least exists via items reference)
                do {
                    struct Row: Decodable { let id: UUID }
                    let rows: [Row] = try awaitResult {
                        try await client.from("items").select("id").eq("list_id", value: saved).limit(1).execute().value
                    }
                    if !rows.isEmpty { return savedUUID }
                } catch { /* fall through to recalc */ }
            }
        }
        var resolved: UUID? = nil
        let sema = DispatchSemaphore(value: 0)
        Task {
            do {
                struct Row: Decodable { let listId: UUID; enum CodingKeys: String, CodingKey { case listId = "list_id" } }
                let items: [Row] = try await client.from("items").select("list_id").order("created_at", ascending: true).limit(1).execute().value
                if let first = items.first { resolved = first.listId; sema.signal(); return }
                let defaults: [List] = try await client.from("lists").select().eq("is_default", value: true).limit(1).execute().value
                if let first = defaults.first { resolved = first.id; sema.signal(); return }
                let any: [List] = try await client.from("lists").select().order("created_at", ascending: true).limit(1).execute().value
                resolved = any.first?.id
            } catch {
                resolved = nil
            }
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 5)
        return resolved ?? (UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID())
    }

    // Define error type at type scope (not inside generic function) to satisfy compiler
    private enum SyncWaitError: Error { case timeout }

    // Helper: run an async block synchronously with a timeout to reuse validator above
    private static func awaitResult<T>(_ work: @escaping () async throws -> T) throws -> T {
        let sema = DispatchSemaphore(value: 0)
        var result: Result<T, Error>? = nil
        Task {
            do { result = .success(try await work()) } catch { result = .failure(error) }
            sema.signal()
        }
        let status = sema.wait(timeout: .now() + 5)
        guard status == .success, let unwrapped = result else { throw SyncWaitError.timeout }
        switch unwrapped { case .success(let value): return value; case .failure(let e): throw e }
    }

    // Connectivity probe (static to avoid self capture)
    private static func scheduleConnectivityProbe(client: AppSupabaseClient, toastManager: InlineToastManager, viewModel: ListViewModel) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await runConnectivityQuery(client: client, toastManager: toastManager, viewModel: viewModel)
        }
    }

    @MainActor
    private static func runConnectivityQuery(client: AppSupabaseClient, toastManager: InlineToastManager, viewModel: ListViewModel) async {
        struct DumpRow: Codable {
            let id: UUID
            let listId: UUID
            let ownerPublicId: String?
            let imageData: String?
            let name: String
            let units: Int
            let measure: String
            let price: Double
            let isChecked: Bool
            let category: String?
            let productDescription: String?
            let brand: String?
            let position: Int?
            let createdAt: String?
            let updatedAt: String?
            enum CodingKeys: String, CodingKey { case id; case listId = "list_id"; case ownerPublicId = "ownerpublicid"; case imageData = "imagedata"; case name, units, measure, price, isChecked, category; case productDescription = "productdescription"; case brand, position; case createdAt = "created_at"; case updatedAt = "updated_at" }
        }
        do {
            let all: [DumpRow] = try await client.from("items").select().order("created_at", ascending: true).execute().value
            var listCount = 0
            var savedId: String? = UserDefaults.standard.string(forKey: "CurrentListID")
            if let saved = savedId, let _ = UUID(uuidString: saved) {
                let scoped: [DumpRow] = try await client.from("items").select().eq("list_id", value: saved).order("created_at", ascending: true).execute().value
                listCount = scoped.count
                if let data = try? JSONEncoder().encode(scoped), let json = String(data: data, encoding: .utf8) { print("[DB Connectivity] items for list_id=\(saved): \(scoped.count) rows=\n\(json)") }
                // Auto-correct: if saved list has zero items but we do have items overall, switch to first list id
                if listCount == 0, let first = all.first?.listId {
                    let newId = first
                    UserDefaults.standard.set(newId.uuidString, forKey: "CurrentListID")
                    viewModel.switchList(to: newId)
                    toastManager.show("Switched to list • items: \(all.filter{ $0.listId == newId }.count)")
                    savedId = newId.uuidString
                }
            }
            toastManager.show("Connected to DB • items: \(all.count) • list items: \(listCount)")
            if let data = try? JSONEncoder().encode(all), let json = String(data: data, encoding: .utf8) { print("[DB Connectivity] ALL items=\(all.count) rows=\n\(json)") } else { print("[DB Connectivity] ALL items=\(all.count) (JSON encoding failed)") }
        } catch {
            toastManager.show("DB query failed: \(error.localizedDescription)")
            print("[DB Connectivity] ERROR: \(error)")
        }
    }
}
