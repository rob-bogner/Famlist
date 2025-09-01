// MARK: - Preview/In-Memory Repositories for SwiftUI Previews

import Foundation

final class PreviewProfilesRepository: ProfilesRepository {
    private var profile = Profile(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, public_id: "genius-demo")
    func upsertProfile(authUserId: UUID, publicId: String) async throws { profile = .init(id: authUserId, public_id: publicId) }
    func myProfile() async throws -> Profile { profile }
    func profileByPublicId(_ publicId: String) async throws -> Profile? { profile.public_id == publicId ? profile : nil }
}

final class PreviewListsRepository: ListsRepository {
    private var lists: [List] = [
        .init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, owner_id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "Einkaufsliste", is_default: true, created_at: nil)
    ]
    func ensureDefaultListExists(for owner: UUID) async throws -> List { lists.first { $0.owner_id == owner && $0.is_default } ?? lists[0] }
    func observeLists(for owner: UUID) -> AsyncStream<[List]> { AsyncStream { $0.yield(self.lists); $0.finish() } }
    func createList(for owner: UUID, title: String) async throws -> List {
        let l = List(id: UUID(), owner_id: owner, title: title, is_default: false, created_at: nil)
        lists.append(l); return l
    }
    func addMember(listId: UUID, profileId: UUID) async throws {}
    func removeMember(listId: UUID, profileId: UUID) async throws {}
}

final class PreviewCategoriesRepository: CategoriesRepository {
    private var cats: [Category] = [
        .init(id: UUID(), name: "Dairy", emoji: "🥛", color_hex: "#88CCFF", profile_id: nil),
        .init(id: UUID(), name: "Bakery", emoji: "🥖", color_hex: "#FFCC88", profile_id: nil)
    ]
    func all(for profileId: UUID?) async throws -> [Category] { cats }
    func create(name: String, emoji: String?, colorHex: String?) async throws -> Category {
        let c = Category(id: UUID(), name: name, emoji: emoji, color_hex: colorHex, profile_id: nil)
        cats.append(c); return c
    }
}
