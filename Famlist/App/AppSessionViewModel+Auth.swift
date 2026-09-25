/*
 AppSessionViewModel+Auth.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anmelden (Magic-Link, Passwort), Registrieren, Sitzung wiederherstellen und Start nach der Anmeldung (Profil und Start-Liste laden).

 📝 Last Change:
 - Aus AppSessionViewModel.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase // PostgrestError (Profil fehlt = PGRST116).

extension AppSessionViewModel {
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
        UserLog.Auth.loadingProfile()
        if let userId = authService?.currentUserId, let cached = ProfileCache.load(userId: userId) {
            Task { await refreshProfileFromServer() }
            UserLog.Auth.profileLoaded(publicId: cached.publicId)
            return cached
        }
        do {
            let profile = try await profiles.myProfile()
            UserLog.Auth.profileLoaded(publicId: profile.publicId)
            return profile
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
}
