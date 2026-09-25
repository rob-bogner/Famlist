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
 - Anmeldung/Start → AppSessionViewModel+Auth.swift, Links → AppSessionViewModel+DeepLink.swift
   ausgelagert (Audit 25.09.2026).
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
    /// Gesetzt, wenn beim Abmelden noch Änderungen ungesendet sind → Einstellungen fragen nach.
    @Published var unsentChangesBeforeSignOut: Int? = nil
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
    
    // MARK: - Sign Out

    /// Weitere lokale Speicher, die beim Abmelden geleert werden (Preise, Kategorien – verdrahtet in FamlistApp).
    private(set) var signOutHandlers: [@MainActor () -> Void] = []

    func onSignOut(_ handler: @escaping @MainActor () -> Void) {
        signOutHandlers.append(handler)
    }

    /// Zähler für noch nicht gesendete Änderungen weiterer Speicher (Preise, Kategorien – FamlistApp).
    private(set) var unsentChangeCounters: [@MainActor () -> Int] = []

    func countUnsentChanges(with counter: @escaping @MainActor () -> Int) {
        unsentChangeCounters.append(counter)
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
