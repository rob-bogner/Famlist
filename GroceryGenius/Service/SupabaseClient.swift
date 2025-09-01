// MARK: - Supabase Client Facade & Config Loader

import Foundation
import Supabase

// MARK: - Config
struct SupabaseConfig: Codable {
    let url: URL
    let anonKey: String
}

enum SupabaseConfigLoader {
    /// Tries to load Supabase config from Secrets.plist in main bundle.
    /// The file should contain keys: SUPABASE_URL (String) and SUPABASE_ANON_KEY (String)
    /// Do not commit Secrets.plist.
    static func load() -> SupabaseConfig? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let urlString = dict["SUPABASE_URL"] as? String,
              let key = dict["SUPABASE_ANON_KEY"] as? String,
              let supaURL = URL(string: urlString)
        else { return nil }
        return SupabaseConfig(url: supaURL, anonKey: key)
    }
}

// MARK: - Facade Protocols
protocol SupabaseClienting {
    var auth: AuthClient { get }
    // Query entry point using new API
    func from(_ table: String) -> PostgrestQueryBuilder
    // Minimal storage helpers to avoid exposing StorageClient type in public API
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String
}

final class AppSupabaseClient: SupabaseClienting {
    let client: SupabaseClient
    var auth: AuthClient { client.auth }

    init?(config: SupabaseConfig) {
        // Use URL as required by supabase-swift in this project version
        self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
    }

    func from(_ table: String) -> PostgrestQueryBuilder { client.from(table) }

    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {
        // Provide a concrete cacheControl to satisfy non-optional String API
        _ = try await client.storage.from(bucket).upload(path, data: data, options: FileOptions(cacheControl: "3600", contentType: contentType, upsert: true))
    }

    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String {
        // createSignedURL returns URL; convert to String for consumers
        let url: URL = try await client.storage.from(bucket).createSignedURL(path: path, expiresIn: expiresIn)
        return url.absoluteString
    }
}
