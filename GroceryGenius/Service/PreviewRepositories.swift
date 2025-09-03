/*
 Preview/In-Memory Repositories for SwiftUI Previews

 GroceryGenius
 Created on: 01.07.2025 (est.)
 Last updated on: 03.09.2025

 ------------------------------------------------------------------------
 📄 File Overview:
 - Lightweight in-memory repository implementations used only for SwiftUI previews and offline UI demos.

 🛠 Includes:
 - PreviewProfilesRepository, PreviewListsRepository, PreviewCategoriesRepository returning canned data.

 🔰 Notes for Beginners:
 - These avoid network calls in previews so the canvas renders instantly.
 - Logic mirrors the real repositories minimally; do not ship these in production code.

 📝 Last Change:
 - Added standardized header; no functional changes.
 ------------------------------------------------------------------------
 */

import Foundation // Foundation provides UUID, AsyncStream, and basic types for these simple stores.

/// Preview implementation of ProfilesRepository storing a single profile in memory.
final class PreviewProfilesRepository: ProfilesRepository { // Used by previews to avoid network.
    private var profile = Profile(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, public_id: "genius-demo") // Seed profile for previews.
    func upsertProfile(authUserId: UUID, publicId: String) async throws { profile = .init(id: authUserId, public_id: publicId) } // Replace stored profile.
    func myProfile() async throws -> Profile { profile } // Return the stored profile.
    func profileByPublicId(_ publicId: String) async throws -> Profile? { profile.public_id == publicId ? profile : nil } // Match on public id.
}

/// Preview implementation of ListsRepository with an in-memory list array.
final class PreviewListsRepository: ListsRepository { // Simple data source for previews.
    private var lists: [List] = [ // Seed one default list.
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, owner_id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "Einkaufsliste", is_default: true, created_at: nil)
    ]
    func ensureDefaultListExists(for owner: UUID) async throws -> List { lists.first { $0.owner_id == owner && $0.is_default } ?? lists[0] } // Return default if exists else first.
    func observeLists(for owner: UUID) -> AsyncStream<[List]> { AsyncStream { $0.yield(self.lists); $0.finish() } } // Emit once and finish.
    func createList(for owner: UUID, title: String) async throws -> List { // Append a new list row.
        let l = List(id: UUID(), owner_id: owner, title: title, is_default: false, created_at: nil) // Build list.
        lists.append(l); return l // Store and return.
    }
    func addMember(listId: UUID, profileId: UUID) async throws {} // No-op in previews.
    func removeMember(listId: UUID, profileId: UUID) async throws {} // No-op in previews.
}

/// Preview implementation of CategoriesRepository returning a static list of categories.
final class PreviewCategoriesRepository: CategoriesRepository { // Simple category source.
    private var cats: [Category] = [ // Seed example categories.
        .init(id: UUID(), name: "Dairy", emoji: "🥛", color_hex: "#88CCFF", profile_id: nil),
        .init(id: UUID(), name: "Bakery", emoji: "🥖", color_hex: "#FFCC88", profile_id: nil)
    ]
    func all(for profileId: UUID?) async throws -> [Category] { cats } // Return all categories.
    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category { // Append and return new category.
        let c = Category(id: UUID(), name: name, emoji: emoji, color_hex: colorHex, profile_id: nil) // Build category.
        cats.append(c); return c // Store and return.
    }
}
