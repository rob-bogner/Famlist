/*
 SupabaseClient.swift

 GroceryGenius
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

enum SupabaseConfigLoader { // Helper namespace for loading configuration from Secrets.plist.
    /// Tries to load Supabase config from Secrets.plist in main bundle.
    /// The file should contain keys: SUPABASE_URL (String) and SUPABASE_ANON_KEY (String)
    /// Do not commit Secrets.plist.
    static func load() -> SupabaseConfig? { // Attempts to decode a simple dictionary into SupabaseConfig.
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"), // Locate Secrets.plist in the app bundle.
              let data = try? Data(contentsOf: url), // Read the plist bytes.
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any], // Parse into a dictionary.
              let urlString = dict["SUPABASE_URL"] as? String, // Read URL string.
              let key = dict["SUPABASE_ANON_KEY"] as? String, // Read anon key.
              let supaURL = URL(string: urlString) // Convert string to URL.
        else { return nil } // If anything fails, return nil so the app can fall back.
        return SupabaseConfig(url: supaURL, anonKey: key) // Build config object for use by the client wrapper.
    }
}

// MARK: - Facade Protocols
protocol SupabaseClienting { // Protocol to hide concrete Supabase types from the rest of the app.
    var auth: AuthClient { get } // Exposes auth for login-related tasks if needed.
    var realtime: RealtimeClientV2 { get } // Exposes Realtime V2 client for live subscriptions.
    // Query entry point using new API
    func from(_ table: String) -> PostgrestQueryBuilder // Returns a query builder for the given table.
    // Minimal storage helpers to avoid exposing StorageClient type in public API
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws // Uploads a file to a bucket.
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String // Generates a signed URL string.
}

final class AppSupabaseClient: SupabaseClienting { // Concrete wrapper around SupabaseClient conforming to our facade.
    let client: SupabaseClient // The underlying Supabase client instance.
    var auth: AuthClient { client.auth } // Forward auth client for sign-in/out operations.
    var realtime: RealtimeClientV2 { client.realtimeV2 } // Forward Realtime V2 client for live subscriptions.

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
        // Optionally check/restore session asynchronously and log outcome without throwing.
        let authClient = self.client.auth // Snapshot auth client to avoid capturing self.
        Task.detached {
            do {
                _ = try await authClient.session // Attempt to read/restore an existing session.
                _ = logResult(params: ["restored": true], result: "Auth session ready")
            } catch {
                _ = logResult(params: ["restored": false, "error": String(describing: error)], result: "Auth session missing")
            }
        }
        // Optionally observe auth state changes and log lightweight events.
        Task.detached {
            for await ev in authClient.authStateChanges {
                logVoid(params: ["authEvent": String(describing: ev.event)])
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

