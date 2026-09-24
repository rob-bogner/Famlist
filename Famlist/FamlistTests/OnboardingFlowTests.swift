/*
 OnboardingFlowTests.swift
 FamlistTests

 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für Phase 5: E-Mail-Prüfung vor dem Anmeldelink, „Profil anlegen“ nötig?, Benutzernamen-Vorschlag,
   Einladung annehmen/ablehnen und die Nonce-Hilfen für „Mit Apple anmelden“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 5).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

private final class JoinLists: ListsRepository {
    var lists: [ListModel] = []
    private(set) var added: [(UUID, UUID)] = []
    func ensureDefaultListExists(for owner: UUID) async throws -> List { throw URLError(.unknown) }
    func observeLists(for owner: UUID) -> AsyncStream<[List]> { AsyncStream { $0.finish() } }
    func createList(for owner: UUID, title: String) async throws -> List { throw URLError(.unknown) }
    func addMember(listId: UUID, profileId: UUID) async throws { added.append((listId, profileId)) }
    func removeMember(listId: UUID, profileId: UUID) async throws {}
    func fetchMembers(listId: UUID) async throws -> [ListMember] { [] }
    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel { throw URLError(.unknown) }
    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel] { lists }
    func renameList(listId: UUID, title: String) async throws -> ListModel { throw URLError(.unknown) }
    func deleteList(listId: UUID) async throws {}
    func setDefaultList(listId: UUID, ownerId: UUID) async throws {}
    func invitePreview(listId: UUID) async throws -> InvitePreviewRow? {
        InvitePreviewRow(title: "Edeka", itemCount: 4, memberCount: 2)
    }
}

@MainActor
final class OnboardingFlowTests: XCTestCase {
    private let meId = UUID()

    private func makeSession(lists: ListsRepository = JoinLists(), username: String? = nil) throws -> AppSessionViewModel {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let listVM = ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                                   itemStore: SwiftDataItemStore(context: context),
                                   listStore: SwiftDataListStore(context: context), startImmediately: false)
        let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(), lists: lists,
                                          listViewModel: listVM)
        session.currentProfile = Profile(id: meId, publicId: "me123", username: username, fullName: nil,
                                         avatarUrl: nil, createdAt: nil, updatedAt: nil)
        return session
    }

    func test_sendMagicLink_rejectsInvalidEmail() async throws {
        let session = try makeSession()
        let sent = await session.sendMagicLink(to: "keine-mail")
        XCTAssertFalse(sent)
        XCTAssertEqual(session.errorMessage, "Bitte gib eine gültige E-Mail-Adresse ein.")
        XCTAssertNil(session.magicLinkSentTo)
    }

    func test_needsProfileSetup_onlyWithoutUsername() throws {
        let fresh = try makeSession(username: nil)
        fresh.isAuthenticated = true
        XCTAssertTrue(fresh.needsProfileSetup)
        let done = try makeSession(username: "rob")
        done.isAuthenticated = true
        XCTAssertFalse(done.needsProfileSetup)
        let signedOut = try makeSession(username: nil)
        XCTAssertFalse(signedOut.needsProfileSetup, "Ohne Anmeldung kein Profil-Screen")
    }

    func test_invitePreview_usesRpcCounts() async throws {
        let session = try makeSession(username: "rob")
        await session.loadInvitePreview(.init(listId: UUID(), listTitle: "Alt", inviterPublicId: "unknown"))
        XCTAssertEqual(session.invitePreview?.listName, "Edeka")
        XCTAssertEqual(session.invitePreview?.itemCount, 4)
        XCTAssertEqual(session.invitePreview?.memberCount, 2)
        XCTAssertEqual(session.invitePreview?.inviterName, "unknown", "Unbekannter Einladender → öffentliche ID")
    }

    func test_acceptInvite_joinsAndOpensList() async throws {
        let lists = JoinLists()
        let shared = ListModel(id: UUID(), ownerId: UUID(), title: "WG", isDefault: false, createdAt: Date(), updatedAt: Date())
        lists.lists = [shared]
        let session = try makeSession(lists: lists, username: "rob")
        let invite = AppSessionViewModel.InvitePayload(listId: shared.id, listTitle: "WG", inviterPublicId: "x")
        session.pendingInvite = invite
        await session.acceptInviteAndOpen(invite)
        XCTAssertEqual(lists.added.first?.0, shared.id)
        XCTAssertEqual(lists.added.first?.1, meId)
        XCTAssertNil(session.pendingInvite)
        XCTAssertEqual(session.listViewModel.defaultList?.id, shared.id)
    }

    func test_declineInvite_clearsPending() throws {
        let session = try makeSession(username: "rob")
        session.pendingInvite = .init(listId: UUID(), listTitle: "WG", inviterPublicId: "x")
        session.declineInvite()
        XCTAssertNil(session.pendingInvite)
    }

    func test_appleNonce_lengthAndHash() {
        let nonce = AppleSignInCoordinator.randomNonce()
        XCTAssertEqual(nonce.count, 32)
        XCTAssertNotEqual(nonce, AppleSignInCoordinator.randomNonce())
        // SHA-256 von "abc" (FIPS 180-2 Testvektor)
        XCTAssertEqual(AppleSignInCoordinator.sha256("abc"),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
