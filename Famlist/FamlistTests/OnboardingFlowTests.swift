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
 - Einladungen mit Token (Audit 25.09.2026): Vorschau, Annehmen, abgelaufene und alte Links.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

private final class JoinLists: ListsRepository {
    var lists: [ListModel] = []
    /// Gültige Tokens → Liste. Andere Tokens gelten als abgelaufen.
    var tokens: [String: UUID] = [:]
    private(set) var accepted: [String] = []
    func ensureDefaultListExists(for owner: UUID) async throws -> List { throw URLError(.unknown) }
    func observeLists(for owner: UUID) -> AsyncStream<[List]> { AsyncStream { $0.finish() } }
    func createList(for owner: UUID, title: String) async throws -> List { throw URLError(.unknown) }
    func removeMember(listId: UUID, profileId: UUID) async throws {}
    func fetchMembers(listId: UUID) async throws -> [ListMember] { [] }
    func observeMemberRemovals(userId: UUID) -> AsyncStream<UUID> { AsyncStream { $0.finish() } }
    func fetchDefaultList(for ownerId: UUID) async throws -> ListModel { throw URLError(.unknown) }
    func fetchAllLists(for ownerId: UUID) async throws -> [ListModel] { lists }
    func renameList(listId: UUID, title: String) async throws -> ListModel { throw URLError(.unknown) }
    func deleteList(listId: UUID) async throws {}
    func setDefaultList(listId: UUID, ownerId: UUID) async throws {}
    func invitePreview(token: String) async throws -> InvitePreviewRow? {
        guard let listId = tokens[token] else { return nil }
        return InvitePreviewRow(listId: listId, title: "Edeka", itemCount: 4, memberCount: 2, inviterName: "Rob")
    }
    func acceptInvite(token: String) async throws -> UUID {
        guard let listId = tokens[token] else { throw InviteError.invalidOrExpired }
        accepted.append(token)
        return listId
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

    func test_invitePreview_usesRpcCountsAndInviter() async throws {
        let lists = JoinLists()
        let listId = UUID()
        lists.tokens["tok"] = listId
        let session = try makeSession(lists: lists, username: "rob")
        await session.loadInvitePreview(.init(token: "tok", listTitle: "Alt"))
        XCTAssertEqual(session.invitePreview?.listId, listId)
        XCTAssertEqual(session.invitePreview?.listName, "Edeka")
        XCTAssertEqual(session.invitePreview?.itemCount, 4)
        XCTAssertEqual(session.invitePreview?.memberCount, 2)
        XCTAssertEqual(session.invitePreview?.inviterName, "Rob")
        XCTAssertNil(session.errorMessage)
    }

    func test_invitePreview_unknownToken_showsExpiredMessage() async throws {
        let session = try makeSession(username: "rob")
        await session.loadInvitePreview(.init(token: "abgelaufen", listTitle: "WG"))
        XCTAssertEqual(session.errorMessage, InviteError.invalidOrExpired.errorDescription)
        XCTAssertEqual(session.invitePreview?.listName, "WG", "Titel aus dem Link bleibt sichtbar")
        XCTAssertNil(session.invitePreview?.listId)
    }

    func test_acceptInvite_joinsAndOpensList() async throws {
        let lists = JoinLists()
        let shared = ListModel(id: UUID(), ownerId: UUID(), title: "WG", isDefault: false, createdAt: Date(), updatedAt: Date())
        lists.lists = [shared]
        lists.tokens["tok"] = shared.id
        let session = try makeSession(lists: lists, username: "rob")
        let invite = AppSessionViewModel.InvitePayload(token: "tok", listTitle: "WG")
        session.pendingInvite = invite
        await session.acceptInviteAndOpen(invite)
        XCTAssertEqual(lists.accepted, ["tok"])
        XCTAssertNil(session.pendingInvite)
        XCTAssertEqual(session.listViewModel.defaultList?.id, shared.id)
    }

    func test_acceptInvite_expiredToken_keepsInviteAndShowsMessage() async throws {
        let session = try makeSession(username: "rob")
        let invite = AppSessionViewModel.InvitePayload(token: "weg", listTitle: "WG")
        session.pendingInvite = invite
        await session.acceptInviteAndOpen(invite)
        XCTAssertEqual(session.errorMessage, InviteError.invalidOrExpired.errorDescription)
        XCTAssertEqual(session.pendingInvite, invite)
    }

    func test_handleOpenURL_parsesTokenLink() throws {
        let session = try makeSession(username: "rob")
        session.isAuthenticated = true
        session.handleOpenURL(URL(string: "famlist://invite?token=abc_-1&listTitle=WG%20Einkauf")!)
        XCTAssertEqual(session.pendingInvite, .init(token: "abc_-1", listTitle: "WG Einkauf"))
    }

    func test_handleOpenURL_legacyListIdLink_isRejected() throws {
        let session = try makeSession(username: "rob")
        session.isAuthenticated = true
        session.handleOpenURL(URL(string: "famlist://invite?listId=\(UUID().uuidString)&inviterPublicId=x&listTitle=WG")!)
        XCTAssertNil(session.pendingInvite)
        XCTAssertEqual(session.errorMessage, InviteError.invalidOrExpired.errorDescription)
    }

    func test_inviteLink_roundTrip() {
        let url = InviteLink.url(token: "abc_-1", listTitle: "WG & Co")
        let q = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(url?.scheme, "famlist")
        XCTAssertEqual(url?.host, "invite")
        XCTAssertEqual(q?.first { $0.name == "token" }?.value, "abc_-1")
        XCTAssertEqual(q?.first { $0.name == "listTitle" }?.value, "WG & Co")
        XCTAssertNil(q?.first { $0.name == "listId" }, "Listen-ID darf nicht mehr im Link stehen")
    }

    func test_declineInvite_clearsPending() throws {
        let session = try makeSession(username: "rob")
        session.pendingInvite = .init(token: "tok", listTitle: "WG")
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
