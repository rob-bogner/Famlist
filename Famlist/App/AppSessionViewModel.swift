/*
 AppSessionViewModel.swift

 GroceryGenius
 Created on: 07.09.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Root session/view-state coordinator for authentication and initial data bootstrapping.

 🛠 Includes:
 - AppSessionViewModel orchestrating Supabase auth restore, magic-link completion, and default list loading via repositories.
 - Automatic new user onboarding with profile and default list creation.
 - currentProfile storage for UI access.

 🔰 Notes for Beginners:
 - This ViewModel owns simple flags (isAuthenticated, isLoading, errorMessage) and calls repositories after login.
 - Views bind to these flags to show AuthView or the main ShoppingListView.
 - Uses async/await and ensures UI mutations occur on the main thread (@MainActor).
 - Handles both existing users (direct profile load) and new users (auto profile creation).

 📝 Last Change:
 - Added currentProfile @Published property for ProfileView access.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID and URL used here.
import SwiftUI // Import SwiftUI to use ObservableObject and @Published.

/// Coordinates authentication lifecycle and post-login bootstrapping for the app.
@MainActor // Guarantee UI-facing state publishes on main thread.
final class AppSessionViewModel: ObservableObject { // ObservableObject so SwiftUI updates views on state changes.
    // MARK: - Published UI State
    @Published var isAuthenticated: Bool = false // Whether the user is authenticated.
    @Published var isLoading: Bool = false // Whether a background operation is in progress.
    @Published var errorMessage: String? = nil // Optional, user-presentable error message.
    @Published var isRestoringSession: Bool = false // Whether session restoration is in progress.
    @Published var currentProfile: Profile? = nil // The currently authenticated user's profile.

    // MARK: - Lightweight Toasts
    @Published var toastMessage: String? = nil
    private var toastClearTask: Task<Void, Never>? = nil

    /// Cold-start phases for user-visible toasts/logs
    enum Phase: String {
        case sessionRestore
        case profile
        case defaultList
        case itemsSnapshot

        var label: String {
            switch self {
            case .sessionRestore: return String(localized: "startup.phase.sessionRestore")
            case .profile: return String(localized: "startup.phase.profile")
            case .defaultList: return String(localized: "startup.phase.defaultList")
            case .itemsSnapshot: return String(localized: "startup.phase.itemsSnapshot")
            }
        }
    }

    // MARK: - Dependencies
    let client: SupabaseClienting? // Supabase client facade (optional to allow preview-only construction).
    private let profiles: ProfilesRepository // Repository to fetch the current profile after login.
    private let lists: ListsRepository // Repository to fetch/create the default list for the profile.
    private unowned let listViewModel: ListViewModel // Reference to list VM to start observing items after login.

    /// Creates a new AppSessionViewModel.
    /// - Parameters:
    ///   - client: Supabase client facade; can be nil for previews where no auth calls are made.
    ///   - profiles: Profiles repository used to load the current user profile.
    ///   - lists: Lists repository used to resolve the default list.
    ///   - listViewModel: The list VM that will observe items for the resolved default list.
    init(client: SupabaseClienting?, profiles: ProfilesRepository, lists: ListsRepository, listViewModel: ListViewModel) { // Store dependencies for later use.
        self.client = client // Save Supabase client (may be nil in previews).
        self.profiles = profiles // Save profiles repository.
        self.lists = lists // Save lists repository.
        self.listViewModel = listViewModel // Save list VM to switch/observe after login.
        Task { await self.restoreSession() } // Restore session on init.
    }

    /// Logs and shows a transient toast for the given cold-start phase.
    func markPhase(_ phase: Phase) async {
        // Log to console using lightweight logger if available, else print
        logVoid(params: ["phase": phase.rawValue, "label": phase.label])
        await showToast(phase.label)
    }

    /// Presents a toast message for a short duration and auto-clears it.
    private func showToast(_ message: String) async {
        self.toastMessage = message
        // Cancel any existing auto-clear task
        toastClearTask?.cancel()
        toastClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            await MainActor.run { self?.toastMessage = nil }
        }
    }

    // MARK: - Auth
    /// Starts an email OTP sign-in flow (magic link) using Supabase.
    /// - Parameter email: The email address to send the sign-in link to.
    func signInWithEmailOTP(email: String) {
        guard let client else { // Ensure we have a client capable of auth calls.
            self.errorMessage = String(localized: "auth.error.noClient") // Surface a user-friendly message.
            return // Nothing to do in previews without a Supabase client.
        }
        if isLoading { return } // Prevent concurrent sign-in attempts.
        
        Task { @MainActor in
            isLoading = true // Flip loading on for button spinners.
            defer { isLoading = false } // Always turn loading off when done.
            
            do { // Attempt to start OTP sign-in.
                let redirect = URL(string: "famlist://login-callback")! // URL scheme handled by app for magic-link return.
                try await client.auth.signInWithOTP(email: email, redirectTo: redirect) // Ask Supabase to send magic link.
                logVoid(params: (email: email, redirectTo: redirect.absoluteString)) // Log parameters.
            } catch { // Capture and present error.
                errorMessage = (error as NSError).localizedDescription // Convert to readable message.
            }
        }
    }

    /// Signs in with email and password - works in simulator unlike magic links.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    func signInWithEmailPassword(email: String, password: String) {
        guard let client else { // Ensure we have a client capable of auth calls.
            self.errorMessage = String(localized: "auth.error.noClient") // Surface a user-friendly message.
            return // Nothing to do in previews without a Supabase client.
        }
        if isLoading { return } // Prevent concurrent sign-in attempts.
        
        Task { @MainActor in
            isLoading = true // Flip loading on for button spinners.
            defer { isLoading = false } // Always turn loading off when done.
            
            do { // Attempt email/password sign-in.
                try await client.auth.signIn(email: email, password: password) // Direct sign-in with credentials.
                logVoid(params: ["email": email, "method": "password"]) // Log successful sign-in.
                await handleAuthCompletion() // Proceed to load profile and default list.
            } catch { // Capture and present error.
                errorMessage = (error as NSError).localizedDescription // Convert to readable message.
            }
        }
    }

    /// Signs up a new user with email and password - creates account immediately.
    /// - Parameters:
    ///   - email: The new user's email address.
    ///   - password: The new user's password.
    func signUpWithEmailPassword(email: String, password: String) {
        guard let client else { // Ensure we have a client capable of auth calls.
            self.errorMessage = String(localized: "auth.error.noClient") // Surface a user-friendly message.
            return // Nothing to do in previews without a Supabase client.
        }
        if isLoading { return } // Prevent concurrent sign-up attempts.
        
        Task { @MainActor in
            isLoading = true // Flip loading on for button spinners.
            defer { isLoading = false } // Always turn loading off when done.
            
            do { // Attempt email/password sign-up.
                try await client.auth.signUp(email: email, password: password) // Create new account.
                logVoid(params: ["email": email, "method": "signup"]) // Log successful sign-up.
                await handleAuthCompletion() // Proceed to load profile and default list.
            } catch { // Capture and present error.
                errorMessage = (error as NSError).localizedDescription // Convert to readable message.
            }
        }
    }

    /// Tries to restore a persisted Supabase session on app launch.
    func restoreSession() async {
        await markPhase(.sessionRestore)
        guard let client else { // Without client, default to unauthenticated previews.
            self.isAuthenticated = false // Keep unauthenticated in design previews.
            return // Exit early.
        }
        if isLoading { return } // Avoid overlapping calls.
        
        isLoading = true // Set loading flag while checking session.
        isRestoringSession = true // Mark session restoration in progress.
        defer { 
            isLoading = false
            isRestoringSession = false
        } // Reset loading and restoration when done.
        
        do { // Attempt to read an existing session.
            let session = try await client.auth.session // May throw if no session present.
            _ = logResult(params: ["hasSession": true], result: session.user.id) // Log success with user id.
            isAuthenticated = true // Flip on the auth gate.
            await handleAuthCompletion() // Proceed to load profile and default list.
        } catch { // No session or another error.
            _ = logResult(params: ["hasSession": false, "error": String(describing: error)], result: "no-session") // Log failure.
            isAuthenticated = false // Stay at auth gate.
        }
    }

    /// Completes auth after handling the magic link deep link; loads profile and default list then starts item observation.
    func handleAuthCompletion() async { // Called after deep link or on successful restore.
        isLoading = true // Indicate background work.
        defer { isLoading = false } // Ensure loading resets when function exits.
        do { // Bootstrap profile and list.
            await markPhase(.profile)
            
            // Try to load existing profile, create new one if it doesn't exist (new user scenario)
            let me: Profile
            do {
                me = try await profiles.myProfile() // Load current profile from the server.
                logVoid(params: ["action": "loadProfile", "status": "existing", "profileId": me.id]) // Log existing user.
            } catch {
                // Profile doesn't exist - this is a new user, create profile automatically
                logVoid(params: ["action": "loadProfile", "status": "notFound", "creating": true]) // Log new user detection.
                me = try await createProfileForNewUser() // Create new profile for first-time user.
                logVoid(params: ["action": "createProfile", "status": "created", "profileId": me.id]) // Log profile creation.
            }
            
            // Store profile for access in UI
            currentProfile = me
            
            await markPhase(.defaultList)
            let defaultList = try await lists.fetchDefaultList(for: me.id) // Ensure a default list exists and fetch it.
            _ = logResult(params: (profileId: me.id, defaultListId: defaultList.id), result: "bootstrapped") // Log IDs for debugging.
            // Inform the ListViewModel to use ListsRepository and switch to default list id.
            listViewModel.configure(listsRepository: lists) // Inject ListsRepository for potential later usage.
            listViewModel.defaultList = defaultList // Publish the resolved default list.
            listViewModel.switchList(to: defaultList.id) // This starts observing items for the list.
            await markPhase(.itemsSnapshot)
            self.isAuthenticated = true // Mark session as authenticated.
        } catch { // Bubble error to UI.
            self.errorMessage = (error as NSError).localizedDescription // Store readable error.
            self.isAuthenticated = false // Ensure we stay on the auth screen.
        }
    }

    // MARK: - Deep Link Handler
    /// Handles an incoming deep link URL from Supabase (magic-link flow) and finalizes authentication.
    /// - Parameter url: The URL opened by the system containing the session details.
    func handleOpenURL(_ url: URL) {
        guard let client else { return } // Without client, nothing to process.
        Task { // Run async session extraction.
            do { // Try to extract and persist session from deep link.
                _ = try await client.auth.session(from: url) // Supabase parses tokens and stores session.
                logVoid(params: ["openURL": url.absoluteString]) // Log that we processed the URL.
                await self.handleAuthCompletion() // Continue with profile/default list loading.
            } catch { // Surface error to UI.
                self.errorMessage = (error as NSError).localizedDescription // Human-friendly message.
            }
        }
    }

    // MARK: - New User Onboarding
    /// Creates a profile for a new user who doesn't have one yet (first-time magic link sign-up).
    /// - Returns: The newly created Profile with generated public_id.
    private func createProfileForNewUser() async throws -> Profile {
        guard let client else { 
            throw NSError(domain: "AppSessionViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "No client available"]) 
        } // Ensure we have a client.
        
        // Get the authenticated user ID from the current session
        let userId: UUID
        if let currentId = client.auth.currentUser?.id {
            userId = currentId // Use cached user ID if available.
        } else {
            let session = try await client.auth.session // Fallback to session lookup.
            userId = session.user.id // Extract user ID from session.
        }
        
        // Generate a unique public_id for sharing lists (8-character alphanumeric)
        let publicId = generatePublicId()
        
        // Create the profile using the repository
        try await profiles.upsertProfile(authUserId: userId, publicId: publicId)
        
        // Fetch and return the newly created profile
        let newProfile = try await profiles.myProfile()
        return newProfile
    }
    
    /// Generates a random 8-character alphanumeric string for public_id.
    /// - Returns: A string like "A3K9M2X7" for sharing purposes.
    private func generatePublicId() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" // Use uppercase and numbers for clarity.
        return String((0..<8).map { _ in characters.randomElement()! }) // Generate 8 random characters.
    }

    // MARK: - Sign Out
    /// Signs the user out from Supabase and clears local state so the UI returns to the auth screen.
    func signOut() { // Public API called by the UI (hamburger menu) to remove the saved session.
        if isLoading { return } // Avoid overlapping operations while another auth task is running.
        
        Task { @MainActor in
            isLoading = true // Show loading indicator for any interested UI.
            defer { isLoading = false } // Always reset loading when done.
            
            do { // Attempt to revoke session and clear local state.
                if let client { // Proceed only when a Supabase client exists (runtime mode).
                    try await client.auth.signOut(scope: .global) // Ask Supabase to invalidate tokens and remove Keychain session.
                    logVoid(params: ["action": "signOut", "status": "ok"]) // Log successful sign-out.
                }
                listViewModel.clearForSignOut() // Drop any loaded list data to avoid stale UI post-logout.
                isAuthenticated = false // Flip gate so RootView shows the AuthView.
                errorMessage = nil // Clear any previous error messages.
            } catch { // Handle and surface errors.
                errorMessage = (error as NSError).localizedDescription // Store readable error.
                logVoid(params: ["action": "signOut", "status": "error", "message": errorMessage ?? ""]) // Log failure.
            }
        }
    }
}

