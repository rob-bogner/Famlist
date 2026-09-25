/*
 AccountAndSharingTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für Phase 4: Benutzername-Regeln und Live-Prüfung, Favorit (optimistisch + Rücknahme),
   Einladungslink, Mitglieder & Teilen (Besitzer/Mitglied, Entfernen) und „Liste verlassen“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

private final class StubProfiles: ProfilesRepository {
    var me: Profile
    var takenNames: Set<String> = []
    var failFavorite = false
    var owner: Profile?
    private(set) var favoriteCalls: [UUID?] = []

    init(me: Profile) { self.me = me }
    func upsertProfile(authUserId: UUID, publicId: String) async throws {}
    func myProfile() async throws -> Profile { me }
    func profile(id: UUID) async throws -> Profile? { owner?.id == id ? owner : nil }
    func isUsernameAvailable(_ username: String) async throws -> Bool { !takenNames.contains(username.lowercased()) }
    func setFavoriteList(_ listId: UUID?) async throws {
        favoriteCalls.append(listId)
        if failFavorite { throw URLError(.notConnectedToInternet) }
    }
}

private final class StubLists: ListsRepository {
    var members: [ListMember] = []
    private(set) var removed: [(UUID, UUID)] = []
    func ensureDefaultListExists(for owner: UUID) async throws -> List { throw URLError(.unknown) }
    func observeLists(for owner: UUID) -> AsyncStream<[List]> { AsyncStream { $0.finish() } }
    func createList(for owner: UUID, title: String) async throws -> List { throw URLError(.unknown) }
    func removeMember(listId: UUID, profileId: UUID) async throws { removed.append((listId, profileId)) }
    func fetchMembers(listId: UUID) async throws -> [ListMember] { members }
    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel { throw URLError(.unknown) }
    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel] { [] }
    func renameList(listId: UUID, title: String) async throws -> ListModel { throw URLError(.unknown) }
    func deleteList(listId: UUID) async throws {}
    func setDefaultList(listId: UUID, ownerId: UUID) async throws {}
    /// nil = offline (createInvite wirft).
    var inviteToken: String?
    func createInvite(listId: UUID) async throws -> String {
        guard let inviteToken else { throw URLError(.notConnectedToInternet) }
        return inviteToken
    }
}

@MainActor
final class AccountAndSharingTests: XCTestCase {
    /// Wartet, bis `condition` erfüllt ist (höchstens 2 s) – statt fester Pausen, die unter Last zu kurz sind.
    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<200 where !condition() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    private let meId = UUID()
    private lazy var me = Profile(id: meId, publicId: "rob123", username: "rob", fullName: "Rob",
                                  avatarUrl: nil, createdAt: nil, updatedAt: nil)

    private func makeListVM() throws -> ListViewModel {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        return ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                             itemStore: SwiftDataItemStore(context: context),
                             listStore: SwiftDataListStore(context: context), startImmediately: false)
    }

    private func makeSession(_ profiles: StubProfiles, lists: StubLists? = nil) throws -> AppSessionViewModel {
        let session = AppSessionViewModel(client: nil, profiles: profiles, lists: lists ?? StubLists(),
                                          listViewModel: try makeListVM())
        session.currentProfile = me
        return session
    }

    private func list(_ title: String, owner: UUID, isDefault: Bool = false) -> ListModel {
        ListModel(id: UUID(), ownerId: owner, title: title, isDefault: isDefault, createdAt: Date(), updatedAt: Date())
    }

    // MARK: - Benutzername

    func test_usernameRules() {
        XCTAssertTrue(AppSessionViewModel.isValidUsername("rob_42"))
        XCTAssertFalse(AppSessionViewModel.isValidUsername("ro"), "mindestens 3 Zeichen")
        XCTAssertFalse(AppSessionViewModel.isValidUsername("rob bogner"), "keine Leerzeichen")
        XCTAssertFalse(AppSessionViewModel.isValidUsername("röb"), "nur A–Z, 0–9, _")
    }

    func test_checkUsername_ownNameIsFree_takenIsTaken() async throws {
        let profiles = StubProfiles(me: me)
        profiles.takenNames = ["anna"]
        let session = try makeSession(profiles)
        let own = await session.checkUsername("Rob")
        let taken = await session.checkUsername("anna")
        let free = await session.checkUsername("berta")
        let invalid = await session.checkUsername("a b")
        XCTAssertEqual(own, .available)
        XCTAssertEqual(taken, .taken)
        XCTAssertEqual(free, .available)
        XCTAssertEqual(invalid, .invalid)
    }

    // MARK: - Favorit

    func test_favorite_fallsBackToOwnDefaultList() throws {
        let session = try makeSession(StubProfiles(me: me))
        XCTAssertTrue(session.isFavorite(list("My List", owner: meId, isDefault: true)))
        XCTAssertFalse(session.isFavorite(list("Geteilt", owner: UUID(), isDefault: true)))
    }

    func test_toggleFavorite_setsAndClears() async throws {
        let profiles = StubProfiles(me: me)
        let session = try makeSession(profiles)
        let drogerie = list("Drogerie", owner: meId)
        session.toggleFavorite(drogerie)
        XCTAssertEqual(session.currentProfile?.favoriteListId, drogerie.id)
        session.toggleFavorite(drogerie)
        XCTAssertNil(session.currentProfile?.favoriteListId)
        await waitUntil { profiles.favoriteCalls.count == 2 }
        XCTAssertEqual(profiles.favoriteCalls, [drogerie.id, nil])
    }

    func test_toggleFavorite_rollsBackOnError() async throws {
        let profiles = StubProfiles(me: me)
        profiles.failFavorite = true
        let session = try makeSession(profiles)
        session.toggleFavorite(list("Drogerie", owner: meId))
        await waitUntil { session.errorMessage != nil }
        XCTAssertNil(session.currentProfile?.favoriteListId)
        XCTAssertNotNil(session.errorMessage)
    }

    // MARK: - Einladungslink

    func test_shareMembers_loadsInviteLinkWithServerToken() async {
        let lists = StubLists()
        lists.inviteToken = "tok_123"
        let vm = ShareMembersViewModel(list: list("My List", owner: meId), me: me, lists: lists, profiles: nil)
        await vm.load()
        let url = try? XCTUnwrap(vm.inviteURL)
        let items = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        XCTAssertEqual(items.first { $0.name == "token" }?.value, "tok_123")
        XCTAssertNil(items.first { $0.name == "listId" })
    }

    func test_shareMembers_offline_noLink_retryShowsMessage() async {
        let lists = StubLists()
        let vm = ShareMembersViewModel(list: list("My List", owner: meId), me: me, lists: lists, profiles: nil)
        await vm.load()
        XCTAssertNil(vm.inviteURL)
        XCTAssertNil(vm.errorMessage, "Beim Öffnen offline kein Fehler-Toast")
        await vm.ensureInviteURL()
        XCTAssertEqual(vm.errorMessage, InviteError.unavailable.errorDescription)
    }

    // MARK: - Mitglieder & Teilen

    func test_shareMembers_ownerFirst_thenMembers() async {
        let lists = StubLists()
        lists.members = [ListMember(id: UUID(), publicId: "anna1", username: "anna", fullName: nil, addedAt: Date())]
        let vm = ShareMembersViewModel(list: list("My List", owner: meId), me: me, lists: lists, profiles: nil)
        await vm.load()
        XCTAssertEqual(vm.members.map(\.name), ["Rob (Du)", "anna"])
        XCTAssertEqual(vm.members.map(\.role), ["Besitzer", "Mitglied"])
        XCTAssertTrue(vm.isOwner)
    }

    func test_shareMembers_asMember_loadsOwnerProfile_andCannotRemove() async {
        let ownerProfile = Profile(id: UUID(), publicId: "o1", username: nil, fullName: "Olga", avatarUrl: nil,
                                   createdAt: nil, updatedAt: nil)
        let profiles = StubProfiles(me: me)
        profiles.owner = ownerProfile
        let lists = StubLists()
        lists.members = [ListMember(id: meId, publicId: "rob123", username: "rob", fullName: "Rob", addedAt: Date())]
        let vm = ShareMembersViewModel(list: list("WG", owner: ownerProfile.id), me: me, lists: lists, profiles: profiles)
        await vm.load()
        XCTAssertEqual(vm.members.map(\.name), ["Olga", "Rob (Du)"])
        vm.remove(vm.members[1])
        XCTAssertEqual(vm.members.count, 2, "Nur der Besitzer darf entfernen")
    }

    func test_shareMembers_ownerRemovesMember() async throws {
        let lists = StubLists()
        let anna = ListMember(id: UUID(), publicId: "anna1", username: "anna", fullName: nil, addedAt: Date())
        lists.members = [anna]
        let myList = list("My List", owner: meId)
        let vm = ShareMembersViewModel(list: myList, me: me, lists: lists, profiles: nil)
        await vm.load()
        vm.remove(vm.members[1])
        await waitUntil { !lists.removed.isEmpty }
        XCTAssertEqual(vm.members.count, 1)
        XCTAssertEqual(lists.removed.first?.1, anna.id)
    }

    // MARK: - Liste verlassen

    func test_leaveList_removesListAndSwitchesAway() async throws {
        let vm = try makeListVM()
        let lists = StubLists()
        vm.configure(listsRepository: lists)
        let own = list("My List", owner: meId, isDefault: true)
        let shared = list("WG", owner: UUID())
        vm.allLists = [own, shared]
        vm.switchToList(shared)
        vm.leaveList(shared, profileId: meId)
        XCTAssertEqual(vm.allLists.map(\.title), ["My List"])
        XCTAssertEqual(vm.defaultList?.id, own.id)
        await waitUntil { !lists.removed.isEmpty }
        XCTAssertEqual(lists.removed.first?.0, shared.id)
        XCTAssertEqual(lists.removed.first?.1, meId)
    }
}
