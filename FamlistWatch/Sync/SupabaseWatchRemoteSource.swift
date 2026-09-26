/*
 SupabaseWatchRemoteSource.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - WatchRemoteSource über die geteilten Supabase-Repositories des iPhones (Listen, Profil, Kategorien).

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

/// Supabase-Umsetzung über die geteilten Repositories des iPhones.
@MainActor
final class SupabaseWatchRemoteSource: WatchRemoteSource {
    private let lists: SupabaseListsRepository
    private let profiles: SupabaseProfilesRepository
    private let categories: SupabaseCategoryDefinitionsRepository

    init(client: SupabaseClienting) {
        lists = SupabaseListsRepository(client: client)
        profiles = SupabaseProfilesRepository(client: client)
        categories = SupabaseCategoryDefinitionsRepository(client: client)
    }

    func fetchLists(userId: UUID) async throws -> [ListModel] {
        try await lists.fetchAllLists(for: userId)
    }

    func fetchFavoriteListId() async throws -> UUID? {
        try await profiles.myProfile().favoriteListId
    }

    func fetchCategories(userId: UUID) async throws -> [CategoryDefinition] {
        try await categories.fetch(profileId: userId)
    }
}
