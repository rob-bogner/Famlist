/*
 LiveRealtimeSharingTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Live-Test gegen das echte Supabase-Projekt mit ZWEI angemeldeten Testkonten:
   Besitzer legt eine Wegwerf-Liste an, lädt per Token ein, das Mitglied tritt bei.
   Danach muss jede Änderung des Besitzers (Anlegen, Ändern, Löschmarkierung) beim Mitglied
   über Realtime ankommen, und das Entfernen muss das Mitglied über seinen privaten Kanal erreichen.

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_LIVE=1 xcodebuild test … -only-testing:FamlistTests/LiveRealtimeSharingTests`.
 - Zwei unabhängige SupabaseClient-Instanzen mit Sitzungsspeicher im RAM (kein Schlüsselbund),
   damit sich die Konten nicht gegenseitig abmelden.
 - Räumt am Ende auf: Die Wegwerf-Liste wird gelöscht (Artikel und Mitgliedschaften per CASCADE).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026: Realtime auf geteilten Listen absichern).
 ------------------------------------------------------------------------
 */

#if DEBUG && targetEnvironment(simulator)
import XCTest
import Supabase
@testable import Famlist

/// Sitzungsspeicher im RAM – je Client eigener, damit zwei Konten parallel angemeldet bleiben.
private final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private var values: [String: Data] = [:]
    private let lock = NSLock()
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

/// Sammelt Realtime-Ereignisse threadsicher, damit der Test darauf warten kann.
private actor EventLog {
    private(set) var entries: [String] = []
    func add(_ entry: String) { entries.append(entry) }
    func contains(_ needle: String) -> Bool { entries.contains { $0.contains(needle) } }
}

final class LiveRealtimeSharingTests: XCTestCase {
    private var owner: SupabaseClient!
    private var member: SupabaseClient!
    private var listId: UUID?

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FAMLIST_LIVE"] == "1", "nur mit TEST_RUNNER_FAMLIST_LIVE=1")
        owner = try await signedInClient(.tester)
        member = try await signedInClient(.demo)
    }

    override func tearDown() async throws {
        if let listId, let owner {
            _ = try? await owner.from("lists").delete().eq("id", value: listId.uuidString).execute()
        }
        await owner?.realtimeV2.removeAllChannels()
        await member?.realtimeV2.removeAllChannels()
    }

    private func signedInClient(_ account: SimulatorAuthHelper.TestAccount) async throws -> SupabaseClient {
        let config = try XCTUnwrap(SupabaseConfigLoader.load(), "Supabase-Konfiguration fehlt")
        let client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.anonKey,
            options: .init(auth: .init(storage: MemoryAuthStorage()))
        )
        let credentials = SimulatorAuthHelper.getCredentials(for: account)
        _ = try await client.auth.signIn(email: credentials.email, password: credentials.password)
        await client.realtimeV2.setAuth()
        return client
    }

    private func waitFor(_ description: String, timeout: TimeInterval = 10,
                         _ condition: @escaping () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Zeitüberschreitung (\(Int(timeout)) s): \(description)")
    }

    // MARK: - Test

    func test_sharedList_changesReachMember_andRemovalReachesMember() async throws {
        let ownerId = try await owner.auth.session.user.id
        let memberId = try await member.auth.session.user.id

        // 1. Wegwerf-Liste anlegen
        struct NewList: Encodable { let id: UUID; let owner_id: UUID; let title: String; let is_default: Bool }
        let newListId = UUID()
        try await owner.from("lists")
            .insert(NewList(id: newListId, owner_id: ownerId, title: "Livetest Realtime", is_default: false))
            .execute()
        listId = newListId

        // 2. Einladen und beitreten (Token-RPCs aus Migration 014)
        struct ListParam: Encodable, Sendable { let p_list_id: UUID }
        struct TokenParam: Encodable, Sendable { let p_token: String }
        struct TokenRow: Decodable { let token: String }
        let tokens: [TokenRow] = try await owner.rpc("create_list_invite", params: ListParam(p_list_id: newListId))
            .execute().value
        let token = try XCTUnwrap(tokens.first?.token)
        let joined: UUID = try await member.rpc("accept_list_invite", params: TokenParam(p_token: token)).execute().value
        XCTAssertEqual(joined, newListId)

        // 3. Mitglied abonniert die Liste (derselbe Kanal-Aufbau wie SupabaseRealtimeManager)
        let log = EventLog()
        let itemsChannel = member.realtimeV2.channel("public:items:\(newListId)")
        let inserts = itemsChannel.postgresChange(InsertAction.self, schema: "public", table: "items",
                                                  filter: .eq("list_id", value: newListId.uuidString))
        let updates = itemsChannel.postgresChange(UpdateAction.self, schema: "public", table: "items",
                                                  filter: .eq("list_id", value: newListId.uuidString))
        try await itemsChannel.subscribeWithError()
        let insertTask = Task { for await e in inserts { await log.add("insert:\(e.record["name"]?.stringValue ?? "")") } }
        let updateTask = Task {
            for await e in updates {
                let name = e.record["name"]?.stringValue ?? ""
                let units = e.record["units"]?.intValue ?? -1
                let tomb = e.record["tombstone"]?.boolValue ?? false
                await log.add("update:\(name):\(units):\(tomb)")
            }
        }
        defer { insertTask.cancel(); updateTask.cancel() }

        // Privater Kanal des Mitglieds für „entfernt“
        let userChannel = member.realtimeV2.channel("user:\(memberId.uuidString.lowercased())") { $0.isPrivate = true }
        let removals = userChannel.broadcastStream(event: "member_removed")
        try await userChannel.subscribeWithError()
        let removalTask = Task {
            for await message in removals {
                if let id = SupabaseListsRepository.listId(fromBroadcast: message) { await log.add("removed:\(id)") }
            }
        }
        defer { removalTask.cancel() }

        // 4. Besitzer legt an, ändert, markiert als gelöscht
        struct ItemRow: Encodable {
            let id: UUID; let list_id: UUID; let name: String; let units: Int
            let hlc_timestamp: Int64; let hlc_counter: Int; let hlc_node_id: String; let tombstone: Bool
        }
        let itemId = UUID()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        try await owner.from("items").insert(ItemRow(id: itemId, list_id: newListId, name: "Livetest Milch", units: 1,
                                                     hlc_timestamp: now, hlc_counter: 0, hlc_node_id: "live-owner",
                                                     tombstone: false)).execute()
        try await waitFor("INSERT beim Mitglied") { await log.contains("insert:Livetest Milch") }

        struct UnitsPatch: Encodable { let units: Int; let hlc_timestamp: Int64; let hlc_counter: Int; let hlc_node_id: String }
        try await owner.from("items").update(UnitsPatch(units: 3, hlc_timestamp: now + 1, hlc_counter: 0, hlc_node_id: "live-owner"))
            .eq("id", value: itemId.uuidString).execute()
        try await waitFor("UPDATE (Menge 3) beim Mitglied") { await log.contains("update:Livetest Milch:3:false") }

        struct TombPatch: Encodable { let tombstone: Bool; let hlc_timestamp: Int64; let hlc_counter: Int; let hlc_node_id: String }
        try await owner.from("items").update(TombPatch(tombstone: true, hlc_timestamp: now + 2, hlc_counter: 0, hlc_node_id: "live-owner"))
            .eq("id", value: itemId.uuidString).execute()
        try await waitFor("Löschmarkierung beim Mitglied") { await log.contains(":true") }

        // 5. Besitzer entfernt das Mitglied → privater Broadcast
        try await owner.from("list_members").delete()
            .eq("list_id", value: newListId.uuidString).eq("profile_id", value: memberId.uuidString).execute()
        try await waitFor("member_removed beim Mitglied") { await log.contains("removed:\(newListId)") }

        // 6. Alter Token ist danach widerrufen
        do {
            let _: UUID = try await member.rpc("accept_list_invite", params: TokenParam(p_token: token)).execute().value
            XCTFail("Widerrufener Token darf nicht mehr funktionieren")
        } catch {
            XCTAssertEqual(InviteError.from(error), .invalidOrExpired)
        }
    }
}
#endif
