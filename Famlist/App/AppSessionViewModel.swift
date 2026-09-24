/*
 AppSessionViewModel.swift

 Famlist
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
    
    // MARK: - Invite Handling

    /// Payload aus einem Einladungs-Deep-Link.
    struct InvitePayload: Identifiable {
        var id: UUID { listId }
        let listId: UUID
        let listTitle: String       // Aus URL-Parameter (nur zur Anzeige)
        let inviterPublicId: String
    }

    /// Wird gesetzt, wenn ein Invite-Link geöffnet wird und der Nutzer eingeloggt ist.
    @Published var pendingInvite: InvitePayload? = nil
    /// Zwischenspeicher für Invites, die vor dem Login ankommen.
    private var pendingInviteStorage: InvitePayload? = nil

    // MARK: - Lightweight Toasts

    @Published var toastMessage: String? = nil
    private var toastClearTask: Task<Void, Never>? = nil
    private var restoreTask: Task<Void, Never>? = nil
    
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
    internal let profiles: ProfilesRepository
    internal let lists: ListsRepository
    private let listViewModel: ListViewModel
    
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
        
        restoreTask = Task { await self.restoreSession() }
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
            
            UserLog.Auth.loginStarted(email: email)
            
            do {
                try await authService.signInWithEmailOTP(email: email)
            } catch {
                UserLog.Error.general(message: "Anmeldung mit Magic-Link fehlgeschlagen")
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
            
            UserLog.Auth.loginStarted(email: email)
            
            do {
                try await authService.signInWithEmailPassword(email: email, password: password)
                UserLog.Auth.loginSuccess()
                await handleAuthCompletion()
            } catch {
                UserLog.Auth.loginFailed(reason: "Falsche E-Mail oder Passwort")
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
        
        UserLog.Auth.restoringSession()
        
        do {
            try await authService.restoreSession()
            UserLog.Auth.sessionRestored()
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
            // Note: User-Logs für Profil-Laden erfolgen im Repository (mit mehr Details wie publicId)
            
            // Try to load existing profile, create new one if it doesn't exist
            let me: Profile
            do {
                me = try await profiles.myProfile()
                logVoid(params: [
                    "action": "loadProfile",
                    "status": "existing",
                    "profileId": me.id
                ])
                // Note: User-Log erfolgt im Repository
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
                // Note: User-Log erfolgt im OnboardingService
            }
            
            currentProfile = me

            // Gespeicherten Invite aus dem Pre-Auth-Zustand übernehmen
            if let stored = pendingInviteStorage {
                pendingInviteStorage = nil
                pendingInvite = stored
            }

            await markPhase(.defaultList)
            let defaultList = try await lists.fetchDefaultList(for: me.id)
            listViewModel.configure(listsRepository: lists)
            // Membership-Observation starten — muss nach configure(listsRepository:) aufgerufen
            // werden, damit listsRepository gesetzt ist, sonst startet die Observation nicht (RC-5).
            listViewModel.startObservingMemberships(userId: me.id)
            listViewModel.defaultList = defaultList
            listViewModel.switchList(to: defaultList.id)
            
            _ = logResult(
                params: (profileId: me.id, defaultListId: defaultList.id),
                result: "bootstrapped"
            )
            
            UserLog.Auth.authBootstrapCompleted()
            
            await markPhase(.itemsSnapshot)
            UserLog.Data.loadingItems()
            self.isAuthenticated = true
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Deep Link Handler

    /// Handles an incoming deep link URL (invite or Supabase magic-link).
    /// - Parameter url: The URL opened by the system.
    func handleOpenURL(_ url: URL) {
        // Invite: famlist://invite?listId=X&inviterPublicId=Y&listTitle=Z
        if url.scheme == "famlist", url.host == "invite" {
            let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            guard
                let listIdStr = q?.first(where: { $0.name == "listId" })?.value,
                let listId = UUID(uuidString: listIdStr),
                let inviterPublicId = q?.first(where: { $0.name == "inviterPublicId" })?.value
            else {
                logVoid(params: ["action": "handleOpenURL.invite.invalidParams"])
                return
            }
            let listTitle = q?.first(where: { $0.name == "listTitle" })?.value ?? ""
            let invite = InvitePayload(listId: listId, listTitle: listTitle,
                                       inviterPublicId: inviterPublicId)
            if isAuthenticated { pendingInvite = invite }
            else { pendingInviteStorage = invite }
            return
        }

        // Auth magic link (existing path)
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

    // MARK: - Accept Invite

    /// Trägt den aktuellen Nutzer als Mitglied der eingeladenen Liste ein.
    func acceptInvite(_ invite: InvitePayload) {
        guard let profile = currentProfile else { return }

        // Guard: Nutzer ist bereits Owner dieser Liste
        guard !listViewModel.allLists.contains(where: {
            $0.id == invite.listId && $0.ownerId == profile.id
        }) else {
            logVoid(params: (action: "acceptInvite.alreadyOwner", listId: invite.listId))
            pendingInvite = nil
            return
        }

        // Guard: Nutzer ist bereits Mitglied (Liste ist schon in allLists)
        guard !listViewModel.allLists.contains(where: { $0.id == invite.listId }) else {
            logVoid(params: (action: "acceptInvite.alreadyMember", listId: invite.listId))
            pendingInvite = nil
            listViewModel.loadAllLists(ownerId: profile.id)
            return
        }

        Task {
            do {
                try await lists.addMember(listId: invite.listId, profileId: profile.id)
                await MainActor.run {
                    pendingInvite = nil
                    listViewModel.loadAllLists(ownerId: profile.id)
                    UserLog.Data.listJoined()
                }
            } catch {
                await MainActor.run {
                    pendingInvite = nil
                    // Unique-Constraint-Verletzung (bereits Mitglied) ist kein Fehler
                    if (error as NSError).code == 23505 {
                        listViewModel.loadAllLists(ownerId: profile.id)
                    } else {
                        errorMessage = error.localizedDescription
                        logVoid(params: (action: "acceptInvite.error",
                                         error: (error as NSError).localizedDescription))
                    }
                }
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
