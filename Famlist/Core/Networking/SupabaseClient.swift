/*
 SupabaseClient.swift

 Famlist
 Created on: 01.07.2025 (est.)
 Last updated on: 07.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Thin facade around supabase-swift client plus a config loader for Secrets.plist.

 🛠 Includes:
 - SupabaseConfig model, loader from bundle, and AppSupabaseClient wrapper exposing minimal APIs used by repositories.

 🔰 Notes for Beginners:
 - Keep your Secrets.plist out of source control; use Secrets.example.plist as a template.
 - The wrapper lets the rest of the app avoid importing Supabase types everywhere.

 📝 Last Change:
 - Replace local debug shims with Support/Logger and add safe init/auth logs (no secrets); keep client behavior unchanged.
 ------------------------------------------------------------------------
 */

import Foundation // Provides URL, Data, Bundle for loading secrets from a plist.
import Supabase // Imports the official supabase-swift client used to talk to Supabase.

// MARK: - Config
struct SupabaseConfig: Codable { // Holds the URL and anon key needed to initialize Supabase.
    let url: URL // Supabase project URL.
    let anonKey: String // Public anon API key for client apps.
}

enum SupabaseConfigLoader { // Helper namespace for loading configuration from Build Settings or local file.
    /// Tries to load Supabase config from multiple sources (in order of preference):
    /// 1. Environment Variables (SUPABASE_URL, SUPABASE_ANON_KEY) - set in Xcode Scheme
    /// 2. Info.plist keys (not recommended for secrets)
    /// 3. Secrets.plist file in project directory (local development only - NOT bundled in app)
    /// 
    /// SECURITY: Secrets.plist is NOT included in Resources build phase, so it won't be bundled.
    /// The file is only read from the filesystem during development (Xcode copies it to app bundle).
    /// For production builds, use Environment Variables or a secure secrets management system.
    static func load() -> SupabaseConfig? {
        // Try Environment Variables first (preferred for production)
        if let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
           let supaURL = URL(string: urlString) {
            return SupabaseConfig(url: supaURL, anonKey: key)
        }
        
        // Try Info.plist keys (if configured)
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           let supaURL = URL(string: urlString) {
            return SupabaseConfig(url: supaURL, anonKey: key)
        }
        
        // Fallback: Try to load from Secrets.plist file (local development only)
        // Note: This file is NOT in the Resources build phase, so it won't be bundled in the app
        if let secretsPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: secretsPath) as? [String: Any],
           let urlString = dict["SUPABASE_URL"] as? String,
           let key = dict["SUPABASE_ANON_KEY"] as? String,
           let supaURL = URL(string: urlString) {
            return SupabaseConfig(url: supaURL, anonKey: key)
        }
        
        return nil // If all sources fail, return nil so the app can fall back to preview repos.
    }
}

// MARK: - Auth Facade Protocol

/// Narrow protocol covering only the auth operations used by the app.
/// Allows test doubles without subclassing the `final class AuthClient`.
@MainActor
protocol AuthClienting {
    var currentUser: User? { get }
    var session: Session { get async throws }
    var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> { get }
    func signInWithOTP(email: String, redirectTo: URL?) async throws
    func signIn(email: String, password: String) async throws -> Session
    func signUp(email: String, password: String) async throws
    func signOut(scope: SignOutScope) async throws
    func session(from url: URL) async throws -> Session
}

/// Makes the Supabase `AuthClient` conform to `AuthClienting` so production code keeps working.
extension AuthClient: @retroactive AuthClienting {
    func signUp(email: String, password: String) async throws {
        _ = try await signUp(email: email, password: password, data: nil)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await signIn(email: email, password: password, captchaToken: nil)
    }
}

// MARK: - Facade Protocols
protocol SupabaseClienting { // Protocol to hide concrete Supabase types from the rest of the app.
    var auth: any AuthClienting { get } // Exposes auth for login-related tasks if needed.
    var realtime: RealtimeClientV2 { get } // Exposes Realtime V2 client for live subscriptions.
    // Query entry point using new API
    func from(_ table: String) -> PostgrestQueryBuilder // Returns a query builder for the given table.
    // Minimal storage helpers to avoid exposing StorageClient type in public API
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws // Uploads a file to a bucket.
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String // Generates a signed URL string.
}

final class AppSupabaseClient: SupabaseClienting { // Concrete wrapper around SupabaseClient conforming to our facade.
    let client: SupabaseClient // The underlying Supabase client instance.
    var auth: any AuthClienting { client.auth } // Forward auth client for sign-in/out operations.
    var realtime: RealtimeClientV2 { client.realtimeV2 } // Forward Realtime V2 client for live subscriptions.

    // Stored handles allow cancellation in deinit – prevents zombie tasks and memory leaks.
    private var sessionTask: Task<Void, Never>?
    private var authStateTask: Task<Void, Never>?

    deinit {
        sessionTask?.cancel()
        authStateTask?.cancel()
    }

    init?(config: SupabaseConfig) { // Failable initializer; returns nil if misconfigured (kept simple here).
        // Configure auth to auto-refresh tokens; rely on library defaults for secure storage/persistence.
        let options = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                autoRefreshToken: true
            )
        )
        // Initialize Supabase client with URL, anon key, and configured options.
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey, options: options) // Create configured client.
        
        // Log a safe initialization line (no keys). Only log host part of URL and option flags.
        _ = logResult(
            params: (supabaseHost: config.url.host ?? "<nil>", persistSession: true, autoRefreshToken: true),
            result: "SupabaseClient initialized"
        )
        
        UserLog.Sync.supabaseInitialized(host: config.url.host ?? "unknown")
        // Optionally check/restore session asynchronously and log outcome without throwing.
        let authClient = self.client.auth // Snapshot auth client to avoid capturing self.
        // Stored as properties so they can be cancelled in deinit.
        sessionTask = Task {
            do {
                _ = try await authClient.session // Attempt to read/restore an existing session.
                _ = logResult(params: ["restored": true], result: "Auth session ready")
                UserLog.Auth.authSessionReady()
            } catch {
                _ = logResult(params: ["restored": false, "error": String(describing: error)], result: "Auth session missing")
            }
        }
        // Observe auth state changes and log lightweight events.
        authStateTask = Task {
            for await ev in authClient.authStateChanges {
                logVoid(params: ["authEvent": String(describing: ev.event)])
                UserLog.Auth.authStateChanged(event: String(describing: ev.event))
            }
        }
    }

    func from(_ table: String) -> PostgrestQueryBuilder { client.from(table) } // Forward to the underlying client.

    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws { // Uploads binary data to storage.
        // Provide a concrete cacheControl to satisfy non-optional String API
        _ = try await client.storage.from(bucket).upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: contentType, upsert: true)) // Upsert file with cache control.
        logVoid(params: (bucket: bucket, path: path, contentType: contentType, bytes: data.count)) // Log summary (no payload).
    }

    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String { // Creates a temporary URL to access a stored file.
        // createSignedURL returns URL; convert to String for consumers
        let url: URL = try await client.storage.from(bucket).createSignedURL(path: path, expiresIn: expiresIn) // Ask storage for a signed URL.
        return logResult(params: (bucket: bucket, path: path, expiresIn: expiresIn), result: url.absoluteString) // Log URL string.
    }
}

