/*
 ShareArchivedMembersTests.swift
 FamlistTests
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Mitglieder & Teilen“ mit Mitgliedern, die ihr Konto gelöscht haben: nur der Besitzer sieht sie, sie zählen mit,
   „Entfernen“ ruft den Server und nimmt die Änderung bei einem Fehler zurück.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 4).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

private final class ArchivedAccounts: AccountRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var _removed: [(UUID, UUID)] = []
    let members: [ArchivedListMember]
    let failRemove: Bool
    var removed: [(UUID, UUID)] { lock.withLock { _removed } }

    init(members: [ArchivedListMember], failRemove: Bool = false) {
        self.members = members
        self.failRemove = failRemove
    }

    func status() async throws -> AccountArchiveStatus? { nil }
    func restore() async throws -> Bool { false }
    func purge() async throws {}
    func archivedMembers(listId: UUID) async throws -> [ArchivedListMember] { members }
    func removeArchivedMember(listId: UUID, profileId: UUID) async throws {
        if failRemove { throw URLError(.notConnectedToInternet) }
        lock.withLock { _removed.append((listId, profileId)) }
    }
    func unseenNotices() async throws -> [AccountNotice] { [] }
    func markNoticeSeen(_ id: UUID) async throws {}
}

@MainActor
final class ShareArchivedMembersTests: XCTestCase {
    private let meId = UUID()
    private let sofie = ArchivedListMember(id: UUID(), name: "Sofie", purgeAfter: Date().addingTimeInterval(60 * 86_400))

    private var me: Profile {
        Profile(id: meId, publicId: "me123", username: "rob", fullName: "Rob", avatarUrl: nil, createdAt: nil, updatedAt: nil)
    }

    private func list(owner: UUID) -> ListModel {
        ListModel(id: UUID(), ownerId: owner, title: "Edeka", isDefault: false, createdAt: Date(), updatedAt: Date())
    }

    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
    }

    func test_owner_seesArchivedMembers_andCountIncludesThem() async {
        let vm = ShareMembersViewModel(list: list(owner: meId), me: me, lists: PreviewListsRepository(), profiles: nil,
                                       accounts: ArchivedAccounts(members: [sofie]))
        await vm.load()
        XCTAssertEqual(vm.archivedMembers, [sofie])
        XCTAssertEqual(vm.memberCount, vm.members.count + 1)
    }

    func test_member_doesNotSeeArchivedMembers() async {
        let vm = ShareMembersViewModel(list: list(owner: UUID()), me: me, lists: PreviewListsRepository(), profiles: nil,
                                       accounts: ArchivedAccounts(members: [sofie]))
        await vm.load()
        XCTAssertTrue(vm.archivedMembers.isEmpty)
    }

    func test_removeArchived_callsServer() async {
        let accounts = ArchivedAccounts(members: [sofie])
        let owned = list(owner: meId)
        let vm = ShareMembersViewModel(list: owned, me: me, lists: PreviewListsRepository(), profiles: nil, accounts: accounts)
        await vm.load()
        vm.removeArchived(sofie)
        XCTAssertTrue(vm.archivedMembers.isEmpty, "Sofort aus der Liste (optimistisch)")
        await waitUntil { accounts.removed.count == 1 }
        XCTAssertEqual(accounts.removed.first?.0, owned.id)
        XCTAssertEqual(accounts.removed.first?.1, sofie.id)
    }

    func test_removeArchived_failure_restoresAndShowsError() async {
        let vm = ShareMembersViewModel(list: list(owner: meId), me: me, lists: PreviewListsRepository(), profiles: nil,
                                       accounts: ArchivedAccounts(members: [sofie], failRemove: true))
        await vm.load()
        vm.removeArchived(sofie)
        await waitUntil { vm.errorMessage != nil }
        XCTAssertEqual(vm.archivedMembers, [sofie])
        XCTAssertEqual(vm.errorMessage, "„Sofie“ konnte nicht entfernt werden.")
    }

    func test_shortDate_matchesBoard() {
        let date = ISO8601DateFormatter().date(from: "2026-11-26T12:00:00Z")!
        XCTAssertEqual(ShareArchivedMemberCard.shortDate(date), "26.11.")
    }
}
