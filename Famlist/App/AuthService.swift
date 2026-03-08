/*
 AuthService.swift

 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Service handling authentication operations (sign in, sign up, sign out, deep links).

 🛠 Includes:
 - Email OTP (magic link) sign-in
 - Email/password sign-in and sign-up
 - Sign-out with session cleanup
 - Deep link handling for magic link callbacks

 🔰 Notes for Beginners:
 - Extracted from AppSessionViewModel to follow Single Responsibility principle.
 - All methods are async and handle errors by throwing or returning Result types.
 - The service is stateless; state management remains in AppSessionViewModel.

 📝 Last Change:
 - Extracted from AppSessionViewModel.swift to reduce file size and improve testability.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides URL and error types.

/// Service handling all authentication-related operations.
@MainActor
final class AuthService {
    
    // MARK: - Dependencies
    
    internal let client: SupabaseClienting
    
    // MARK: - Lifecycle
    
    /// Creates an AuthService with the given Supabase client.
    /// - Parameter client: Supabase client facade for auth operations.
    init(client: SupabaseClienting) {
        self.client = client
    }
    
    // MARK: - Sign In Methods
    
    /// Starts an email OTP sign-in flow (magic link) using Supabase.
    /// - Parameter email: The email address to send the sign-in link to.
    /// - Throws: Error if the OTP request fails.
    func signInWithEmailOTP(email: String) async throws {
        let redirect = URL(string: "famlist://login-callback")!
        try await client.auth.signInWithOTP(email: email, redirectTo: redirect)
        logVoid(params: (email: email, redirectTo: redirect.absoluteString))
    }
    
    /// Signs in with email and password - works in simulator unlike magic links.
    /// - Parameters:
    ///   - email: The user's email address.
    ///   - password: The user's password.
    /// - Throws: Error if sign-in fails.
    func signInWithEmailPassword(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
        logVoid(params: ["email": email, "method": "password"])
    }
    
    /// Signs up a new user with email and password - creates account immediately.
    /// - Parameters:
    ///   - email: The new user's email address.
    ///   - password: The new user's password.
    /// - Throws: Error if sign-up fails.
    func signUpWithEmailPassword(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
        logVoid(params: ["email": email, "method": "signup"])
    }
    
    // MARK: - Session Management
    
    /// Tries to restore a persisted Supabase session on app launch.
    /// - Returns: The restored session if available, nil otherwise.
    func restoreSession() async throws {
        let session = try await client.auth.session
        _ = logResult(params: ["hasSession": true], result: session.user.id)
    }
    
    /// Signs the user out from Supabase and clears local state.
    /// - Throws: Error if sign-out fails.
    func signOut() async throws {
        UserLog.Auth.loggedOut()
        try await client.auth.signOut(scope: .global)
        logVoid(params: ["action": "signOut", "status": "ok"])
    }
    
    // MARK: - Deep Link Handler
    
    /// Handles an incoming deep link URL from Supabase (magic-link flow) and finalizes authentication.
    /// - Parameter url: The URL opened by the system containing the session details.
    /// - Throws: Error if session extraction fails.
    func handleOpenURL(_ url: URL) async throws {
        _ = try await client.auth.session(from: url)
        logVoid(params: ["openURL": url.absoluteString])
    }
}

