/*
 AccountArchiveRepositoryTests.swift
 FamlistTests
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - SupabaseAccountRepository ruft die richtigen RPCs mit den richtigen Parametern auf (Migrationen 027/028);
   Realtime-Nachrichten des Kanals user:<id> werden richtig übersetzt; Resttage; „Konto löschen“ löscht das
   Profilfoto nicht mehr (es muss beim Wiederherstellen zurückkommen).

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import XCTest
import Supabase
@testable import Famlist

/// Schreibt RPC-, Function- und Storage-Aufrufe mit; Antworten kommen aus `responses` (JSON je Name).
private final class RecordingClient: SupabaseClienting, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [(name: String, params: [String: String])] = []
    var calls: [(name: String, params: [String: String])] { lock.withLock { _calls } }
    var responses: [String: String] = [:]

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    var auth: any AuthClienting { fatalError("auth not needed") }
    var realtime: RealtimeClientV2 { fatalError("realtime not needed") }
    func from(_ table: String) -> PostgrestQueryBuilder { fatalError("from not needed") }
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {}
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String { "" }

    private func record<P: Encodable>(_ name: String, _ params: P?) {
        var flat: [String: String] = [:]
        if let params, let data = try? JSONEncoder().encode(params),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in json { flat[key] = "\(value)".lowercased() }
        }
        lock.withLock { _calls.append((name, flat)) }
    }

    private func answer<R: Decodable>(_ name: String) throws -> R {
        try decoder.decode(R.self, from: Data((responses[name] ?? "null").utf8))
    }

    func rpc(_ function: String) async throws { record(function, Optional<[String: String]>.none) }
    func storageRemove(bucket: String, paths: [String]) async throws { record("storage:\(bucket)", ["paths": paths.joined()]) }
    func rpcRows<P: Encodable & Sendable, R: Decodable & Sendable>(_ function: String, params: P) async throws -> [R] {
        record(function, params)
        return try answer(function)
    }
    func rpcValue<P: Encodable & Sendable, R: Decodable & Sendable>(_ function: String, params: P) async throws -> R {
        record(function, params)
        return try answer(function)
    }
    func invokeFunction<R: Decodable & Sendable>(_ name: String) async throws -> R {
        record("fn:\(name)", Optional<[String: String]>.none)
        return try answer("fn:\(name)")
    }
}

final class AccountArchiveRepositoryTests: XCTestCase {
    private let listId = UUID(uuidString: "E5DC1AAF-0463-4CF7-9FCF-A0F9045F42D1")!
    private let memberId = UUID(uuidString: "134D94AA-9A95-4BCA-AA9E-5C972C71F513")!

    // MARK: - RPCs

    func test_status_withoutRow_isActive() async throws {
        let client = RecordingClient()
        client.responses["my_account_status"] = "[]"
        let status = try await SupabaseAccountRepository(client: client).status()
        XCTAssertNil(status)
        XCTAssertEqual(client.calls.map(\.name), ["my_account_status"])
    }

    func test_status_mapsDates() async throws {
        let client = RecordingClient()
        client.responses["my_account_status"] =
            #"[{"archived_at":"2026-09-27T18:05:59Z","purge_after":"2026-11-26T18:05:59Z"}]"#
        let status = try await SupabaseAccountRepository(client: client).status()
        XCTAssertEqual(status?.archivedAt, ISO8601DateFormatter().date(from: "2026-09-27T18:05:59Z"))
        XCTAssertEqual(status?.purgeAfter, ISO8601DateFormatter().date(from: "2026-11-26T18:05:59Z"))
    }

    func test_restore_callsRPC() async throws {
        let client = RecordingClient()
        client.responses["restore_my_account"] = "true"
        let restored = try await SupabaseAccountRepository(client: client).restore()
        XCTAssertTrue(restored)
        XCTAssertEqual(client.calls.map(\.name), ["restore_my_account"])
    }

    func test_purge_invokesEdgeFunction() async throws {
        let client = RecordingClient()
        client.responses["fn:purge-my-account"] = #"{"purged":true}"#
        try await SupabaseAccountRepository(client: client).purge()
        XCTAssertEqual(client.calls.map(\.name), ["fn:purge-my-account"])
    }

    func test_archivedMembers_passesListAndMapsNameFallback() async throws {
        let client = RecordingClient()
        client.responses["archived_list_members"] =
            #"[{"profile_id":"134d94aa-9a95-4bca-aa9e-5c972c71f513","name":null,"purge_after":"2026-11-26T18:05:59Z"}]"#
        let members = try await SupabaseAccountRepository(client: client).archivedMembers(listId: listId)
        XCTAssertEqual(members.map(\.id), [memberId])
        XCTAssertEqual(members.first?.name, "Mitglied")
        XCTAssertEqual(client.calls.first?.params["p_list_id"], listId.uuidString.lowercased())
    }

    func test_removeArchivedMember_passesBothIds() async throws {
        let client = RecordingClient()
        client.responses["remove_archived_member"] = "true"
        try await SupabaseAccountRepository(client: client).removeArchivedMember(listId: listId, profileId: memberId)
        XCTAssertEqual(client.calls.first?.name, "remove_archived_member")
        XCTAssertEqual(client.calls.first?.params["p_list_id"], listId.uuidString.lowercased())
        XCTAssertEqual(client.calls.first?.params["p_profile_id"], memberId.uuidString.lowercased())
    }

    func test_markNoticeSeen_passesId() async throws {
        let client = RecordingClient()
        client.responses["mark_notice_seen"] = "true"
        let id = UUID()
        try await SupabaseAccountRepository(client: client).markNoticeSeen(id)
        XCTAssertEqual(client.calls.first?.params["p_id"], id.uuidString.lowercased())
    }

    func test_deleteAccount_onlyArchives_keepsAvatar() async throws {
        let client = RecordingClient()
        try await SupabaseProfilesRepository(client: client).deleteAccount()
        XCTAssertEqual(client.calls.map(\.name), ["delete_my_account"], "Kein Löschen im Storage vor dem Archivieren")
    }

    // MARK: - Realtime user:<id>

    func test_userEvent_memberArchived_buildsNotice() {
        let noticeId = UUID()
        let message: JSONObject = ["payload": .object(["notice_id": .string(noticeId.uuidString.lowercased()),
                                                       "list_id": .string(listId.uuidString.lowercased()),
                                                       "subject_name": .string("Sofie")])]
        let event = SupabaseListsRepository.userEvent("member_archived", message: message)
        XCTAssertEqual(event, .memberArchived(AccountNotice(id: noticeId, listId: listId, subjectName: "Sofie")))
    }

    func test_userEvent_memberRemovedAndRestored_andAccountArchived() {
        let message: JSONObject = ["payload": .object(["list_id": .string(listId.uuidString.lowercased())])]
        XCTAssertEqual(SupabaseListsRepository.userEvent("member_removed", message: message), .memberRemoved(listId: listId))
        XCTAssertEqual(SupabaseListsRepository.userEvent("member_restored", message: message), .memberRestored(listId: listId))
        XCTAssertEqual(SupabaseListsRepository.userEvent("account_archived", message: [:]), .accountArchived)
    }

    func test_userEvent_incompleteMessages_areIgnored() {
        XCTAssertNil(SupabaseListsRepository.userEvent("member_archived", message: ["payload": .object([:])]))
        XCTAssertNil(SupabaseListsRepository.userEvent("member_removed", message: [:]))
        XCTAssertNil(SupabaseListsRepository.userEvent("unbekannt", message: [:]))
    }

    // MARK: - Resttage

    func test_daysLeft_countsCalendarDaysAndNeverNegative() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 20))!
        let purge = calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 18))!
        let status = AccountArchiveStatus(archivedAt: now, purgeAfter: purge)
        XCTAssertEqual(status.daysLeft(now: now, calendar: calendar), 60)
        let later = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1))!
        XCTAssertEqual(status.daysLeft(now: later, calendar: calendar), 0)
    }

    func test_archiveDateText_germanFormat() async {
        let date = ISO8601DateFormatter().date(from: "2026-11-26T12:00:00Z")!
        let text = await MainActor.run { AppSessionViewModel.archiveDateText(date) }
        XCTAssertEqual(text, "26.11.2026")
    }
}
