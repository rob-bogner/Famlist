/*
 ReceiptsRepository.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kassenzettel-Archiv auf dem Server: Einträge (Tabelle `receipts`) und Fotos (Bucket `receipt-images`).

 🔰 Notes for Beginners:
 - Alle Schreibvorgänge sind wiederholbar: Fotos werden mit „upsert“ hochgeladen, die Zeile mit
   „ON CONFLICT DO NOTHING“ eingefügt. Ging nur die Antwort verloren, schadet ein zweiter Versuch nicht.
 - Reihenfolge (Migration 021): Anlegen = erst Fotos, dann Zeile. Löschen = erst Fotos, dann Zeile.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
protocol ReceiptsRepository: AnyObject, Sendable {
    /// Alle Bons der Listen, auf die man Zugriff hat, neueste zuerst (mit Listen- und Personennamen).
    func fetchAll() async throws -> [ArchivedReceipt]
    func uploadPhoto(_ data: Data, path: String) async throws
    func insert(_ receipt: ArchivedReceipt) async throws
    func downloadPhoto(path: String) async throws -> Data
    func removePhotos(paths: [String]) async throws
    func delete(id: UUID) async throws
}

/// Für Vorschauen und Tests. `failWith` simuliert Netz- oder Serverfehler.
@MainActor
final class InMemoryReceiptsRepository: ReceiptsRepository {
    private(set) var receipts: [ArchivedReceipt]
    private(set) var photos: [String: Data] = [:]
    var failWith: Error?

    init(_ receipts: [ArchivedReceipt] = []) { self.receipts = receipts }

    func fetchAll() async throws -> [ArchivedReceipt] {
        try check()
        return receipts.sorted { ($0.purchasedAt, $0.createdAt) > ($1.purchasedAt, $1.createdAt) }
    }

    func uploadPhoto(_ data: Data, path: String) async throws {
        try check()
        photos[path] = data
    }

    func insert(_ receipt: ArchivedReceipt) async throws {
        try check()
        guard !receipts.contains(where: { $0.id == receipt.id }) else { return }
        var stored = receipt
        stored.isPending = false
        receipts.append(stored)
    }

    func downloadPhoto(path: String) async throws -> Data {
        try check()
        guard let data = photos[path] else { throw URLError(.fileDoesNotExist) }
        return data
    }

    func removePhotos(paths: [String]) async throws {
        try check()
        paths.forEach { photos[$0] = nil }
    }

    func delete(id: UUID) async throws {
        try check()
        receipts.removeAll { $0.id == id }
    }

    private func check() throws {
        if let failWith { throw failWith }
    }
}
