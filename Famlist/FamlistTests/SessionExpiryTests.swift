/*
 SessionExpiryTests.swift
 FamlistTests
 Created on: 04.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Abgelaufene Anmeldung: Das SDK meldet `.signedOut`, ohne dass in der App abgemeldet wurde (Konto gelöscht).
   Dann zurück zur Anmeldung mit Hinweis, Einladung bleibt erhalten; ein Abmelden aus der App zeigt keinen Hinweis.
 - Einladung annehmen ohne gültige Anmeldung: Hinweis „Anmeldung abgelaufen“ statt „prüfe die Verbindung“.

 📝 Last Change:
 - Initial creation (Meldung Robert 04.10.2026: Einladung ließ sich nicht annehmen).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
import Supabase
@testable import Famlist

@MainActor
final class SessionExpiryTests: XCTestCase {
    private let meId = UUID()
    private let invite = AppSessionViewModel.InvitePayload(token: "tok", listTitle: "Edeka")

    override func setUp() async throws {
        try await super.setUp()
        LocalAccountData.setExpiredSessionUserId(nil)
    }

    override func tearDown() async throws {
        LocalAccountData.setExpiredSessionUserId(nil)
        try await super.tearDown()
    }

    /// Ohne `await` im Test: Der Start-Task des ViewModels (restoreSession) kann nicht dazwischenlaufen.
    private func makeSession() throws -> AppSessionViewModel {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let listVM = ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                                   itemStore: SwiftDataItemStore(context: context),
                                   listStore: SwiftDataListStore(context: context), startImmediately: false)
        let session = AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(),
                                          lists: PreviewListsRepository(), listViewModel: listVM)
        session.currentProfile = Profile(id: meId, publicId: "me123", username: "rob", fullName: nil,
                                         avatarUrl: nil, createdAt: nil, updatedAt: nil)
        return session
    }

    func test_signedOutBySDK_whileSignedIn_returnsToSignInAndKeepsInvite() throws {
        let session = try makeSession()
        session.isAuthenticated = true
        session.pendingInvite = invite

        session.handleSignedOutBySDK()

        XCTAssertFalse(session.isAuthenticated)
        XCTAssertEqual(session.errorMessage, UserFacingError.sessionExpired)
        XCTAssertNil(session.pendingInvite)
        XCTAssertEqual(session.pendingInviteStorage, invite, "Nach der neuen Anmeldung soll die Einladung wieder erscheinen")
        XCTAssertEqual(LocalAccountData.expiredSessionUserId(), meId)
    }

    func test_signedOutBySDK_whileSignedOut_doesNothing() throws {
        let session = try makeSession()
        session.isAuthenticated = false

        session.handleSignedOutBySDK()

        XCTAssertNil(session.errorMessage)
        XCTAssertNil(LocalAccountData.expiredSessionUserId())
    }

    func test_signOutFromApp_isMarkedAndConsumedOnce() async throws {
        let auth = MockAuthClient()
        auth.stubbedUser = User(id: UUID(), appMetadata: [:], userMetadata: [:], aud: "authenticated",
                                email: nil, createdAt: Date(), updatedAt: Date())
        let service = AuthService(client: MockSupabaseClientForAuth(auth: auth))

        try await service.signOut()

        XCTAssertTrue(service.consumeExpectedSignOut(), "Die .signedOut-Meldung gehört zum Abmelden aus der App")
        XCTAssertFalse(service.consumeExpectedSignOut(), "Eine spätere Meldung ist wieder eine abgelaufene Anmeldung")
    }

    func test_signOutWithoutStoredSession_expectsNoEvent() async throws {
        let service = AuthService(client: MockSupabaseClientForAuth(auth: MockAuthClient()))

        try await service.signOut()

        XCTAssertFalse(service.consumeExpectedSignOut(), "Ohne gespeicherte Anmeldung sendet das SDK kein .signedOut")
    }

    func test_otherAccountSignsIn_discardsOldDataButKeepsInvite() throws {
        let session = try makeSession()
        LocalAccountData.setExpiredSessionUserId(UUID())
        session.pendingInviteStorage = invite

        session.discardDataOfExpiredSession()

        XCTAssertNil(session.currentProfile, "Daten des alten Kontos wurden gelöscht")
        XCTAssertEqual(session.pendingInviteStorage, invite)
        XCTAssertNil(LocalAccountData.expiredSessionUserId())
    }

    func test_withoutExpiredSession_keepsData() throws {
        let session = try makeSession()

        session.discardDataOfExpiredSession()

        XCTAssertEqual(session.currentProfile?.id, meId)
    }

    func test_acceptMessage_permissionDenied_meansSessionExpired() {
        let denied = PostgrestError(code: "42501", message: "permission denied for function accept_list_invite")
        XCTAssertEqual(InviteError.acceptMessage(for: denied), UserFacingError.sessionExpired)
    }

    func test_acceptMessage_expiredInvite_and_network() {
        let expired = PostgrestError(code: "P0002", message: "invite invalid or expired")
        XCTAssertEqual(InviteError.acceptMessage(for: expired), InviteError.invalidOrExpired.errorDescription)
        XCTAssertEqual(InviteError.acceptMessage(for: URLError(.timedOut)), InviteError.acceptFailed.errorDescription)
    }
}
