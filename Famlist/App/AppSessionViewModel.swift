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
import Supabase // PostgrestError (Profil fehlt = PGRST116).

/// Coordinates authentication lifecycle and post-login bootstrapping for the app.
@MainActor
final class AppSessionViewModel: ObservableObject {
    
    // MARK: - Published UI State
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isRestoringSession: Bool = false
    /// Jede Änderung (Laden, Benutzername, Favorit, Foto) landet auch in der lokalen Kopie – sonst startet
    /// die App offline mit einem veralteten Profil (z. B. wieder „Profil anlegen“).
    @Published var currentProfile: Profile? = nil {
        didSet { if let currentProfile { ProfileCache.save(currentProfile) } }
    }
    /// Adresse, an die zuletzt ein Anmeldelink ging (Toast „Wir haben dir einen Link geschickt“).
    @Published var magicLinkSentTo: String? = nil
    /// Vorschau der offenen Einladung (Name des Einladenden, Liste, Zahlen) für „Einladung annehmen“.
    @Published var invitePreview: InvitePreviewInfo? = nil
    /// Letzter Schreibauftrag für den Favoriten; neue Aufträge warten darauf (Reihenfolge beim Server = Tipp-Reihenfolge).
    internal var favoriteWriteTask: Task<Void, Never>? = nil
    /// Profilfoto des angemeldeten Nutzers (aus dem privaten Bucket `avatars`, per signiertem Link geladen).
    @Published var avatarImage: UIImage? = nil
    
    /// Current user's email address (if authenticated)
    var currentUserEmail: String? {
        authService?.client.auth.currentUser?.email
    }
    
    // MARK: - Invite Handling

    /// Payload aus einem Einladungs-Deep-Link.
    /// Einladung aus dem Link `famlist://invite?token=…&listTitle=…` (Migration 014).
    struct InvitePayload: Identifiable, Equatable {
        var id: String { token }
        let token: String
        let listTitle: String       // Aus URL-Parameter (nur zur Anzeige, bis die Vorschau geladen ist)
    }

    /// Wird gesetzt, wenn ein Invite-Link geöffnet wird und der Nutzer eingeloggt ist.
    @Published var pendingInvite: InvitePayload? = nil
    /// Zwischenspeicher für Invites, die vor dem Login ankommen.
    internal var pendingInviteStorage: InvitePayload? = nil

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
    internal let listViewModel: ListViewModel
    
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
    
    /// Completes auth: loads profile and start list and opens the list.
    /// Offline-First: Mit einem gespeicherten Profil startet die App sofort aus der lokalen Kopie; das
    /// Profil wird im Hintergrund aktualisiert. Vorher führte ein Start ohne Netz auf „Anmelden“ (Audit K6).
    func handleAuthCompletion() async {
        do {
            await markPhase(.profile)
            let me = try await loadProfile()
            currentProfile = me

            // Gespeicherten Invite aus dem Pre-Auth-Zustand übernehmen
            if let stored = pendingInviteStorage {
                pendingInviteStorage = nil
                pendingInvite = stored
            }

            await markPhase(.defaultList)
            let startList = try await startList(for: me)
            listViewModel.configure(listsRepository: lists)
            // Membership-Observation starten — muss nach configure(listsRepository:) aufgerufen
            // werden, damit listsRepository gesetzt ist, sonst startet die Observation nicht (RC-5).
            listViewModel.startObservingMemberships(userId: me.id)
            listViewModel.defaultList = startList
            listViewModel.switchList(to: startList.id)
            _ = logResult(params: (profileId: me.id, startListId: startList.id), result: "bootstrapped")
            UserLog.Auth.authBootstrapCompleted()

            await markPhase(.itemsSnapshot)
            UserLog.Data.loadingItems()
            self.isAuthenticated = true
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
            self.isAuthenticated = false
        }
    }

    /// Profil: lokale Kopie sofort (Aktualisierung im Hintergrund), sonst vom Server.
    /// Ein neues Profil wird NUR angelegt, wenn der Server ausdrücklich „keine Zeile“ meldet (PGRST116) –
    /// vorher genügte ein kurzer Netzfehler, und die öffentliche ID wurde überschrieben (Audit H6).
    private func loadProfile() async throws -> Profile {
        if let userId = authService?.currentUserId, let cached = ProfileCache.load(userId: userId) {
            Task { await refreshProfileFromServer() }
            return cached
        }
        do {
            return try await profiles.myProfile()
        } catch let error as PostgrestError where error.code == "PGRST116" {
            logVoid(params: ["action": "loadProfile", "status": "notFound", "creating": true])
            guard let onboardingService else { throw error }
            return try await onboardingService.createProfileForNewUser()
        }
    }

    /// Server-Stand des Profils übernehmen (z. B. auf einem anderen Gerät geändert). Fehler sind unkritisch.
    func refreshProfileFromServer() async {
        guard let me = try? await profiles.myProfile(), currentProfile?.id == me.id else { return }
        currentProfile = me
    }
    
    // MARK: - Deep Link Handler

    /// Handles an incoming deep link URL (invite or Supabase magic-link).
    /// - Parameter url: The URL opened by the system.
    func handleOpenURL(_ url: URL) {
        // Invite: famlist://invite?token=T&listTitle=Z
        if url.scheme == "famlist", url.host == "invite" {
            let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            guard let token = q?.first(where: { $0.name == "token" })?.value, !token.isEmpty else {
                // Alte Links im Format ?listId=… sind seit Migration 014 ungültig.
                logVoid(params: ["action": "handleOpenURL.invite.invalidParams"])
                errorMessage = InviteError.invalidOrExpired.errorDescription
                return
            }
            let listTitle = q?.first(where: { $0.name == "listTitle" })?.value ?? ""
            let invite = InvitePayload(token: token, listTitle: listTitle)
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

    // MARK: - Sign Out

    /// Weitere lokale Speicher, die beim Abmelden geleert werden (Preise, Kategorien – verdrahtet in FamlistApp).
    private(set) var signOutHandlers: [@MainActor () -> Void] = []

    func onSignOut(_ handler: @escaping @MainActor () -> Void) {
        signOutHandlers.append(handler)
    }

    /// Abmelden: offene Änderungen möglichst noch senden, dann abmelden und IMMER alle lokalen Daten
    /// des Kontos löschen – auch wenn der Server nicht erreichbar ist (Audit H5).
    func signOut() {
        guard let authService else { return }
        if isLoading { return }
        Task { @MainActor in
            isLoading = true
            defer { isLoading = false }
            await listViewModel.commitPendingDeletion()?.value
            await listViewModel.syncEngine?.resumeSync()          // letzte Änderungen senden, falls online
            do {
                try await authService.signOut()
            } catch {
                logVoid(params: ["action": "signOut", "status": "remoteFailed", "message": (error as NSError).localizedDescription])
            }
            resetLocalState()
            UserLog.Auth.loggedOut()
            isAuthenticated = false
            errorMessage = nil
        }
    }

    /// Löscht alles, was zum abgemeldeten Konto gehört: Artikel, Listen, Warteschlangen, Fotos,
    /// Profil-Kopie, Preise, Kategorien, Einstellungen je Liste.
    func resetLocalState() {
        listViewModel.clearForSignOut()
        (lists as? OfflineListsRepository)?.clearLocalData()
        signOutHandlers.forEach { $0() }
        ProfileCache.clearAll()
        LocalAccountData.removeListPreferences()
        currentProfile = nil
        avatarImage = nil
        pendingInvite = nil
        pendingInviteStorage = nil
        invitePreview = nil
        logVoid(params: ["action": "resetLocalState"])
    }
}
