/*
 WatchRemoteSource.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Was die Uhr außer Artikeln vom Server liest: Listen (eigene und geteilte, RLS), Favorit und die
   Kategorien des Kontos (Ladenweg-Reihenfolge). Protokoll, damit Tests ohne Server laufen.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
protocol WatchRemoteSource {
    /// Alle Listen, auf die das Konto Zugriff hat.
    func fetchLists(userId: UUID) async throws -> [ListModel]
    /// Favorit aus profiles.favorite_list_id (nil = keiner).
    func fetchFavoriteListId() async throws -> UUID?
    /// Eigene Kategorien nach Position; leer = Standard-Kategorien verwenden.
    func fetchCategories(userId: UUID) async throws -> [CategoryDefinition]
}
