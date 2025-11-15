/*
 AppSessionViewModel.swift

 GroceryGenius
 Created on: 07.09.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Root session/view-state coordinator for authentication and initial data bootstrapping.

 🛠 Includes:
 - AppSessionViewModel orchestrating auth restore, magic-link completion, and default list loading.
 - Automatic new user onboarding with profile and default list creation.
 - Delegates to AuthService and OnboardingService for focused responsibilities.

 🔰 Notes for Beginners:
 - This ViewModel owns simple flags (isAuthenticated, isLoading, errorMessage).
 - Views bind to these flags to show AuthView or the main ShoppingListView.
 - Uses async/await and ensures UI mutations occur on the main thread (@MainActor).

 📝 Last Change:
 - Refactored to delegate auth/onboarding logic to separate services.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID and URL used here.
import SwiftUI // Import SwiftUI to use ObservableObject and @Published.

/// Coordinates authentication lifecycle and post-login bootstrapping for the app.
@MainActor
final class AppSessionViewModel: ObservableObject {
    
    // MARK: - Published UI State
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isRestoringSession: Bool = false
    @Published var currentProfile: Profile? = nil
    
    /// Current user's email address (if authenticated)
    var currentUserEmail: String? {
        authService?.client.auth.currentUser?.email
    }
    
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
    
    internal let authService: AuthService?
    internal let onboardingService: OnboardingService?
    private let profiles: ProfilesRepository
    private let lists: ListsRepository
    private unowned let listViewModel: ListViewModel
    
    // MARK: - Lifecycle
    
    /// Creates a new AppSessionViewModel.
    /// - Parameters:
    ///   - client: Supabase client facade; can be nil for previews.
    ///   - profiles: Profiles repository used to load the current user profile.
    ///   - lists: Lists repository used to resolve the default list.
    ///   - listViewModel: The list VM that will observe items for the resolved default list.
    init(
        client: SupabaseClienting?,
        profiles: ProfilesRepository,
        lists: ListsRepository,
        listViewModel: ListViewModel
    ) {
        self.profiles = profiles
        self.lists = lists
        self.listViewModel = listViewModel
        
        // Initialize services only if client is available
        if let client {
            self.authService = AuthService(client: client)
            self.onboardingService = OnboardingService(client: client, profiles: profiles)
        } else {
            self.authService = nil
            self.onboardingService = nil
        }
        
        Task {
            await self.restoreSession()
        }
    }
    
    // MARK: - Toast Management
    
    /// Logs and shows a transient toast for the given cold-start phase.
    func markPhase(_ phase: Phase) async {
        logVoid(params: ["phase": phase.rawValue, "label": phase.label])
        await showToast(phase.label)
    }
    
    /// Presents a toast message for a short duration and auto-clears it.
    private func showToast(_ message: String) async {
        self.toastMessage = message
        toastClearTask?.cancel()
        toastClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                self?.toastMessage = nil
            }
        }
    }
    
    // MARK: - Auth Operations
    
    /// Starts an email OTP sign-in flow (magic link) using Supabase.
    /// - Parameter email: The email address to send the sign-in link to.
    func signInWithEmailOTP(email: String) {
        guard let authService else {
            self.errorMessage = String(localized: "auth.error.noClient")
            return
        }
        if isLoading { return }
        
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await authService.signInWithEmailOTP(email: email)
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
    
    /// Signs in with email and password - works in simulator unlike magic links.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    func signInWithEmailPassword(email: String, password: String) {
        guard let authService else {
            self.errorMessage = String(localized: "auth.error.noClient")
            return
        }
        if isLoading { return }
        
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await authService.signInWithEmailPassword(email: email, password: password)
                await handleAuthCompletion()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
    
    /// Signs up a new user with email and password - creates account immediately.
    /// - Parameters:
    ///   - email: The new user's email address.
    ///   - password: The new user's password.
    func signUpWithEmailPassword(email: String, password: String) {
        guard let authService else {
            self.errorMessage = String(localized: "auth.error.noClient")
            return
        }
        if isLoading { return }
        
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await authService.signUpWithEmailPassword(email: email, password: password)
                await handleAuthCompletion()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
    
    /// Tries to restore a persisted Supabase session on app launch.
    func restoreSession() async {
        await markPhase(.sessionRestore)
        guard let authService else {
            self.isAuthenticated = false
            return
        }
        if isLoading { return }
        
        isLoading = true
        isRestoringSession = true
        defer {
            isLoading = false
            isRestoringSession = false
        }
        
        do {
            try await authService.restoreSession()
            isAuthenticated = true
            await handleAuthCompletion()
        } catch {
            _ = logResult(
                params: ["hasSession": false, "error": String(describing: error)],
                result: "no-session"
            )
            isAuthenticated = false
        }
    }
    
    /// Completes auth after handling the magic link deep link; loads profile and default list.
    func handleAuthCompletion() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            await markPhase(.profile)
            
            // Try to load existing profile, create new one if it doesn't exist
            let me: Profile
            do {
                me = try await profiles.myProfile()
                logVoid(params: [
                    "action": "loadProfile",
                    "status": "existing",
                    "profileId": me.id
                ])
            } catch {
                // Profile doesn't exist - this is a new user, create profile automatically
                logVoid(params: [
                    "action": "loadProfile",
                    "status": "notFound",
                    "creating": true
                ])
                guard let onboardingService else {
                    throw NSError(
                        domain: "AppSessionViewModel",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "No onboarding service available"]
                    )
                }
                me = try await onboardingService.createProfileForNewUser()
                logVoid(params: [
                    "action": "createProfile",
                    "status": "created",
                    "profileId": me.id
                ])
            }
            
            currentProfile = me
            
            await markPhase(.defaultList)
            let defaultList = try await lists.fetchDefaultList(for: me.id)
            _ = logResult(
                params: (profileId: me.id, defaultListId: defaultList.id),
                result: "bootstrapped"
            )
            
            listViewModel.configure(listsRepository: lists)
            listViewModel.defaultList = defaultList
            listViewModel.switchList(to: defaultList.id)
            await markPhase(.itemsSnapshot)
            self.isAuthenticated = true
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Deep Link Handler
    
    /// Handles an incoming deep link URL from Supabase (magic-link flow).
    /// - Parameter url: The URL opened by the system containing the session details.
    func handleOpenURL(_ url: URL) {
        guard let authService else { return }
        
        Task {
            do {
                try await authService.handleOpenURL(url)
                await self.handleAuthCompletion()
            } catch {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }
    
    // MARK: - Sign Out
    
    /// Signs the user out from Supabase and clears local state.
    func signOut() {
        guard let authService else { return }
        if isLoading { return }
        
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            
            do {
                try await authService.signOut()
                listViewModel.clearForSignOut()
                isAuthenticated = false
                errorMessage = nil
            } catch {
                errorMessage = (error as NSError).localizedDescription
                logVoid(params: [
                    "action": "signOut",
                    "status": "error",
                    "message": errorMessage ?? ""
                ])
            }
        }
    }
}
