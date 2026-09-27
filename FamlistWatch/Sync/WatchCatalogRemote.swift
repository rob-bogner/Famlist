/*
 WatchCatalogRemote.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Artikelstamm-Zugriff der Uhr: wie SupabaseItemCatalogRepository, aber ohne Fotos. Die Uhr zeigt unter
   „Oft gekauft“ keine Bilder; das Herunterladen aller Fotos würde Akku und Speicher kosten.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class WatchCatalogRemote: ItemCatalogRepository {
    private let base: SupabaseItemCatalogRepository

    init(client: SupabaseClienting) {
        base = SupabaseItemCatalogRepository(client: client)
    }

    func search(query: String) async throws -> [ItemCatalogEntry] { try await base.search(query: query) }
    func save(_ entry: ItemCatalogEntry) async throws { try await base.save(entry) }
    func fetchAll() async throws -> [ItemCatalogEntry] { try await base.fetchAll() }
    func update(_ entry: ItemCatalogEntry) async throws { try await base.update(entry) }
    func delete(id: String) async throws { try await base.delete(id: id) }
    func find(barcode: String) async throws -> ItemCatalogEntry? { try await base.find(barcode: barcode) }
    func noteUse(names: [String], at date: Date) async throws { try await base.noteUse(names: names, at: date) }
    /// Keine Fotos auf der Uhr.
    func downloadImage(path: String) async throws -> Data? { nil }
}
