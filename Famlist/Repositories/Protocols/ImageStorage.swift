/*
 ImageStorage.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Hoch- und Herunterladen von Produktfotos (Supabase Storage, Migration 016).

 🔰 Notes for Beginners:
 - `upload` ist wiederholbar: Der Pfad hängt am Inhalt, doppeltes Hochladen überschreibt mit
   identischen Daten.
 - `SupabaseImageStorage` nutzt die Fassade `SupabaseClienting`; Tests ersetzen das Protokoll.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Fotos in Storage).
 ------------------------------------------------------------------------
 */

import Foundation

/// `Sendable`: Umsetzungen sind @MainActor-Klassen und damit ohnehin Sendable; so darf die Referenz
/// in Task-Gruppen übergeben werden (ItemImagePrefetcher).
@MainActor
protocol ImageStorage: AnyObject, Sendable {
    func upload(_ data: Data, bucket: String, path: String) async throws
    func download(bucket: String, path: String) async throws -> Data
}

@MainActor
final class SupabaseImageStorage: ImageStorage {
    private let client: SupabaseClienting

    init(client: SupabaseClienting) {
        self.client = client
    }

    func upload(_ data: Data, bucket: String, path: String) async throws {
        try await client.storageUpload(bucket: bucket, path: path, data: data, contentType: "image/jpeg")
    }

    func download(bucket: String, path: String) async throws -> Data {
        try await client.storageDownload(bucket: bucket, path: path)
    }
}
