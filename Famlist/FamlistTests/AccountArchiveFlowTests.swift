/*
 AccountArchiveFlowTests.swift
 FamlistTests
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Konto-Archiv im AppSessionViewModel: Anmeldung mit gelöschtem Konto, Wiederherstellen, endgültig löschen,
   Realtime-Ereignisse (auf anderem Gerät gelöscht, Mitglied gelöscht) und Hinweise für Listenbesitzer.

 🔰 Notes for Beginners:
 - Der Server wird durch StubAccounts ersetzt; SwiftData läuft nur im Speicher.
 - Ohne Supabase-Client gibt es keinen AuthService: handleAuthCompletion findet keine lokale Profilkopie und
   fragt den Archivzustand deshalb VOR dem Start ab (wie bei der ersten Anmeldung auf einem Gerät).

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
@testable import Famlist

/// Server-Ersatz für das Konto-Archiv. Wird nur vom Main Actor aus benutzt; der Lock schützt trotzdem.
private final class StubAccounts: AccountRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _status: AccountArchiveStatus?
    private var _statusError: Error?
    private var _failRestore = false
    private var _failPurge = false
    private var _restoreCalls = 0
    private var _purgeCalls = 0
    private var _notices: [AccountNotice] = []
    private var _seen: [UUID] = []

    var status: AccountArchiveStatus? { get { lock.withLock { _status } } set { lock.withLock { _status = newValue } } }
    var statusError: Error? { get { lock.withLock { _statusError } } set { lock.withLock { _statusError = newValue } } }
    var failRestore: Bool { get { lock.withLock { _failRestore } } set { lock.withLock { _failRestore = newValue } } }
    var failPurge: Bool { get { lock.withLock { _failPurge } } set { lock.withLock { _failPurge = newValue } } }
    var notices: [AccountNotice] { get { lock.withLock { _notices } } set { lock.withLock { _notices = newValue } } }
    var restoreCalls: Int { lock.withLock { _restoreCalls } }
    var purgeCalls: Int { lock.withLock { _purgeCalls } }
    var seen: [UUID] { lock.withLock { _seen } }

    func status() async throws -> AccountArchiveStatus? {
        if let error = statusError { throw error }
        return status
    }

    func restore() async throws -> Bool {
        lock.withLock { _restoreCalls += 1 }
        if failRestore { throw URLError(.badServerResponse) }
        status = nil
        return true
    }

    func purge() async throws {
        lock.withLock { _purgeCalls += 1 }
        if failPurge { throw URLError(.badServerResponse) }
    }

    func archivedMembers(listId: UUID) async throws -> [ArchivedListMember] { [] }
    func removeArchivedMember(listId: UUID, profileId: UUID) async throws {}
    func unseenNotices() async throws -> [AccountNotice] { notices }
    func markNoticeSeen(_ id: UUID) async throws { lock.withLock { _seen.append(id) } }
}

@MainActor
final class AccountArchiveFlowTests: XCTestCase {
    private let archived = AccountArchiveStatus(archivedAt: Date(), purgeAfter: Date().addingTimeInterval(60 * 86_400))

    private func makeSession(_ accounts: StubAccounts) throws -> AppSessionViewModel {
        let container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let listVM = ListViewModel(listId: UUID(), repository: PreviewItemsRepository(),
                                   itemStore: SwiftDataItemStore(context: context),
                                   listStore: SwiftDataListStore(context: context), startImmediately: false)
        return AppSessionViewModel(client: nil, profiles: PreviewProfilesRepository(), lists: PreviewListsRepository(),
                                   listViewModel: listVM, accounts: accounts)
    }

    /// Wartet auf einen Zustand, der in einem Hintergrund-Task gesetzt wird (höchstens 2 s).
    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
    }

    // MARK: - Anmeldung

    func test_authCompletion_archivedAccount_showsRestoreAndStartsNothing() async throws {
        let accounts = StubAccounts()
        accounts.status = archived
        let session = try makeSession(accounts)
        await session.handleAuthCompletion()
        XCTAssertEqual(session.archivedAccount, archived)
        XCTAssertTrue(session.isAuthenticated, "RootView braucht isAuthenticated für den Restore-Screen")
        XCTAssertNil(session.listViewModel.defaultList, "Keine Liste laden oder anlegen, solange archiviert")
    }

    func test_authCompletion_activeAccount_startsNormally() async throws {
        let session = try makeSession(StubAccounts())
        await session.handleAuthCompletion()
        XCTAssertNil(session.archivedAccount)
        XCTAssertNotNil(session.listViewModel.defaultList)
        XCTAssertTrue(session.isAuthenticated)
    }

    func test_authCompletion_statusFails_startsNormally() async throws {
        let accounts = StubAccounts()
        accounts.statusError = URLError(.notConnectedToInternet)
        let session = try makeSession(accounts)
        await session.handleAuthCompletion()
        XCTAssertNil(session.archivedAccount, "Offline-First: ohne Antwort normal starten")
        XCTAssertNotNil(session.listViewModel.defaultList)
    }

    // MARK: - Wiederherstellen

    func test_restore_clearsArchiveAndStarts() async throws {
        let accounts = StubAccounts()
        accounts.status = archived
        let session = try makeSession(accounts)
        await session.handleAuthCompletion()
        let ok = await session.restoreArchivedAccount()
        XCTAssertTrue(ok)
        XCTAssertEqual(accounts.restoreCalls, 1)
        XCTAssertNil(session.archivedAccount)
        XCTAssertNotNil(session.listViewModel.defaultList, "Nach dem Wiederherstellen normaler Start")
    }

    func test_restore_failure_keepsArchive() async throws {
        let accounts = StubAccounts()
        accounts.status = archived
        accounts.failRestore = true
        let session = try makeSession(accounts)
        await session.handleAuthCompletion()
        let ok = await session.restoreArchivedAccount()
        XCTAssertFalse(ok)
        XCTAssertEqual(session.archivedAccount, archived)
        XCTAssertNil(session.listViewModel.defaultList)
    }

    // MARK: - Endgültig löschen

    func test_purge_signsOutAndResets() async throws {
        let accounts = StubAccounts()
        accounts.status = archived
        let session = try makeSession(accounts)
        await session.handleAuthCompletion()
        let ok = await session.purgeArchivedAccount()
        XCTAssertTrue(ok)
        XCTAssertEqual(accounts.purgeCalls, 1)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(session.archivedAccount)
    }

    func test_purge_failure_keepsArchive() async throws {
        let accounts = StubAccounts()
        accounts.status = archived
        accounts.failPurge = true
        let session = try makeSession(accounts)
        await session.handleAuthCompletion()
        let ok = await session.purgeArchivedAccount()
        XCTAssertFalse(ok)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.archivedAccount, archived)
    }

    // MARK: - Konto löschen

    func test_deleteAccount_signsOut() async throws {
        let session = try makeSession(StubAccounts())
        await session.handleAuthCompletion()
        let ok = await session.deleteAccount()
        XCTAssertTrue(ok)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertFalse(session.isDeletingAccount)
    }

    // MARK: - Realtime

    func test_accountArchivedEvent_signsOutWithMessage() async throws {
        let session = try makeSession(StubAccounts())
        await session.handleAuthCompletion()
        session.handleUserEvent(.accountArchived)
        await waitUntil { !session.isAuthenticated }
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertEqual(session.errorMessage,
                       "Dein Konto wurde auf einem anderen Gerät gelöscht. Melde dich an, um es wiederherzustellen.")
    }

    func test_accountArchivedEvent_ignoredWhileDeletingHere() async throws {
        let session = try makeSession(StubAccounts())
        await session.handleAuthCompletion()
        session.isDeletingAccount = true
        session.handleUserEvent(.accountArchived)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertNil(session.errorMessage)
    }

    func test_memberArchivedEvent_addsNoticeOnce() async throws {
        let session = try makeSession(StubAccounts())
        let notice = AccountNotice(id: UUID(), listId: UUID(), subjectName: "Sofie")
        session.handleUserEvent(.memberArchived(notice))
        session.handleUserEvent(.memberArchived(notice))
        XCTAssertEqual(session.accountNotices, [notice])
    }

    // MARK: - Hinweise

    func test_loadNotices_mergesWithoutDuplicates() async throws {
        let accounts = StubAccounts()
        let known = AccountNotice(id: UUID(), listId: UUID(), subjectName: "Sofie")
        let fresh = AccountNotice(id: UUID(), listId: nil, subjectName: "Max")
        accounts.notices = [known, fresh]
        let session = try makeSession(accounts)
        session.handleUserEvent(.memberArchived(known))
        await session.loadAccountNotices()
        XCTAssertEqual(session.accountNotices, [known, fresh])
    }

    func test_markNoticeSeen_removesAndTellsServer() async throws {
        let accounts = StubAccounts()
        let session = try makeSession(accounts)
        let notice = AccountNotice(id: UUID(), listId: UUID(), subjectName: "Sofie")
        session.handleUserEvent(.memberArchived(notice))
        session.markNoticeSeen(notice)
        XCTAssertTrue(session.accountNotices.isEmpty)
        await waitUntil { accounts.seen == [notice.id] }
        XCTAssertEqual(accounts.seen, [notice.id])
    }

    func test_resetLocalState_clearsArchiveAndNotices() async throws {
        let accounts = StubAccounts()
        accounts.status = archived
        let session = try makeSession(accounts)
        await session.handleAuthCompletion()
        session.handleUserEvent(.memberArchived(AccountNotice(id: UUID(), listId: nil, subjectName: "Sofie")))
        session.resetLocalState()
        XCTAssertNil(session.archivedAccount)
        XCTAssertTrue(session.accountNotices.isEmpty)
    }
}
