/*
 LiveWatchServerTests.swift
 FamlistTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Live-Test der Server-Teile für die Apple Watch (Watch-Plan Phase 3) gegen das echte Supabase-Projekt:
   - Edge Function watch-session: liefert dem angemeldeten iPhone einen Code, mit dem eine ZWEITE,
     unabhängige Sitzung entsteht; die erste bleibt gültig; der Code gilt nur einmal; 1 Aufruf je 10 s;
     ungültiges Token → 401.
   - RPC catalog_note_use (Migration 022): zählt atomar, liefert use_count/last_used_at zurück.
   - Delta für mehrere Listen in einem Aufruf = Vereinigung der Einzel-Abfragen.

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_LIVE=1 xcodebuild test … -only-testing:FamlistTests/LiveWatchServerTests`.
 - Sitzungsspeicher im RAM (MemoryAuthStorage aus LiveRealtimeSharingTests), damit sich iPhone- und
   Uhr-Sitzung nicht gegenseitig überschreiben. Die Uhr-Sitzung wird am Ende abgemeldet (nur sie).
 - Legt einen Wegwerf-Eintrag im Artikelstamm an und löscht ihn wieder.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 3).
 ------------------------------------------------------------------------
 */

#if DEBUG && targetEnvironment(simulator)
import XCTest
import Supabase
import SwiftData
@testable import Famlist

/// Antwort der Edge Function watch-session.
private struct WatchSessionGrant: Decodable {
    let tokenHash: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case tokenHash = "token_hash"
        case type
    }
}

private struct IdRow: Decodable, Hashable { let id: UUID }

final class LiveWatchServerTests: XCTestCase {
    private var cleanup: [() async -> Void] = []

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FAMLIST_LIVE"] == "1", "nur mit TEST_RUNNER_FAMLIST_LIVE=1")
    }

    override func tearDown() async throws {
        for step in cleanup.reversed() { await step() }
        cleanup = []
    }

    private func freshClient() throws -> SupabaseClient {
        let config = try XCTUnwrap(SupabaseConfigLoader.load(), "Supabase-Konfiguration fehlt")
        return SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey,
                              options: .init(auth: .init(storage: MemoryAuthStorage()),
                                             global: .init(session: AppSupabaseClient.uncachedSession)))
    }

    private func signedInClient(_ account: SimulatorAuthHelper.TestAccount) async throws -> SupabaseClient {
        let client = try freshClient()
        let credentials = SimulatorAuthHelper.getCredentials(for: account)
        _ = try await client.auth.signIn(email: credentials.email, password: credentials.password)
        return client
    }

    /// Ruft watch-session auf. Ein 429 aus einem kurz vorher gelaufenen Test wird einmal abgewartet.
    private func requestGrant(_ phone: SupabaseClient) async throws -> WatchSessionGrant {
        do {
            return try await phone.functions.invoke("watch-session", options: .init(method: .post))
        } catch FunctionsError.httpError(let code, _) where code == 429 {
            try await Task.sleep(nanoseconds: 10_500_000_000)
            return try await phone.functions.invoke("watch-session", options: .init(method: .post))
        }
    }

    // MARK: - watch-session

    func test_watchSession_createsSecondIndependentSession() async throws {
        let phone = try await signedInClient(.tester)
        let phoneSession = try await phone.auth.session

        let grant = try await requestGrant(phone)
        XCTAssertEqual(grant.type, "magiclink")
        XCTAssertFalse(grant.tokenHash.isEmpty)

        let watch = try freshClient()
        _ = try await watch.auth.verifyOTP(tokenHash: grant.tokenHash, type: .magiclink)
        cleanup.append { try? await watch.auth.signOut(scope: .local) }
        let watchSession = try await watch.auth.session
        XCTAssertEqual(watchSession.user.id, phoneSession.user.id, "gleiches Konto")
        XCTAssertNotEqual(watchSession.refreshToken, phoneSession.refreshToken, "eigene Sitzung der Uhr")

        // Die Sitzung des iPhones bleibt gültig: Token erneuern und lesen.
        let renewed = try await phone.auth.refreshSession()
        XCTAssertEqual(renewed.user.id, phoneSession.user.id)
        let phoneLists: [IdRow] = try await phone.from("lists").select("id").execute().value
        let watchLists: [IdRow] = try await watch.from("lists").select("id").execute().value
        XCTAssertFalse(watchLists.isEmpty, "Uhr liest mit eigener Sitzung")
        XCTAssertEqual(Set(watchLists), Set(phoneLists), "gleiche Rechte (RLS)")

        // Der Code gilt nur einmal.
        do {
            _ = try await freshClient().auth.verifyOTP(tokenHash: grant.tokenHash, type: .magiclink)
            XCTFail("Code darf nur einmal gelten")
        } catch {}

        // Sofort erneut: Aufruf-Grenze (Migration 023).
        do {
            let _: WatchSessionGrant = try await phone.functions.invoke("watch-session", options: .init(method: .post))
            XCTFail("zweiter Aufruf innerhalb von 10 s muss abgelehnt werden")
        } catch FunctionsError.httpError(let code, _) {
            XCTAssertEqual(code, 429)
        }
    }

    func test_watchSession_rejectsInvalidToken() async throws {
        let config = try XCTUnwrap(SupabaseConfigLoader.load())
        var request = URLRequest(url: config.url.appendingPathComponent("functions/v1/watch-session"))
        request.httpMethod = "POST"
        request.setValue("Bearer kein-gueltiges-token", forHTTPHeaderField: "Authorization")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        let (data, response) = try await AppSupabaseClient.uncachedSession.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 401)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("token_hash"))
    }

    // MARK: - catalog_note_use

    @MainActor
    func test_catalogNoteUse_countsOnServer() async throws {
        let phone = try await signedInClient(.tester)
        let repo = SupabaseItemCatalogRepository(client: LiveTestClient(phone))
        let name = "zz-live-022-\(UUID().uuidString.prefix(8))"
        try await repo.save(ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "", name: name, brand: nil,
                                             category: nil, productDescription: nil, measure: "pcs", price: 0,
                                             imageData: nil))
        cleanup.append {
            _ = try? await phone.from("item_catalog").delete().eq("name_lower", value: name.lowercased()).execute()
        }

        let usedAt = Date().addingTimeInterval(-60)
        try await repo.noteUse(names: [name.uppercased(), name], at: usedAt)
        try await repo.save(ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "", name: name, brand: "Neu",
                                             category: nil, productDescription: nil, measure: "pcs", price: 0,
                                             imageData: nil))
        let stored = try await repo.search(query: name).first { $0.name == name }
        let entry = try XCTUnwrap(stored)
        XCTAssertEqual(entry.useCount, 2, "zwei Hinzufügungen; erneutes Speichern setzt nicht zurück")
        XCTAssertEqual(entry.brand, "Neu")
        let lastUsed = try XCTUnwrap(entry.lastUsedAt)
        XCTAssertEqual(lastUsed.timeIntervalSince1970, usedAt.timeIntervalSince1970, accuracy: 0.01,
                       "Zeitpunkt des Geräts übernommen")
    }

    // MARK: - Delta für mehrere Listen

    @MainActor
    func test_multiListDelta_equalsUnionOfSingleListDeltas() async throws {
        let phone = try await signedInClient(.tester)
        let ownerId = try await phone.auth.session.user.id
        let container = PersistenceController(inMemory: true).container
        let repo = SupabaseItemsRepository(client: LiveTestClient(phone),
                                           itemStore: SwiftDataItemStore(context: container.mainContext))

        // Zwei Wegwerf-Listen mit je einem Artikel (werden am Ende samt Artikeln gelöscht).
        struct NewList: Encodable { let id: UUID; let owner_id: UUID; let title: String; let is_default: Bool }
        struct ItemRow: Encodable {
            let id: UUID; let list_id: UUID; let name: String; let units: Double
            let hlc_timestamp: Int64; let hlc_counter: Int; let hlc_node_id: String; let tombstone: Bool
        }
        let temp = [UUID(), UUID()]
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        for (index, listId) in temp.enumerated() {
            try await phone.from("lists").insert(NewList(id: listId, owner_id: ownerId, title: "Livetest Uhr \(index)",
                                                         is_default: false)).execute()
            cleanup.append { _ = try? await phone.from("lists").delete().eq("id", value: listId.uuidString).execute() }
            try await phone.from("items").insert(ItemRow(id: UUID(), list_id: listId, name: "Livetest Uhr \(index)",
                                                         units: 1, hlc_timestamp: now, hlc_counter: 0,
                                                         hlc_node_id: "live-watch", tombstone: false)).execute()
        }

        // Nur die angefragten Listen, eine Zeile je Artikel.
        let tempRows = try await repo.fetchItemsSince(listIds: temp, since: .distantPast)
        XCTAssertEqual(Set(tempRows.map(\.name)), ["Livetest Uhr 0", "Livetest Uhr 1"])
        XCTAssertEqual(tempRows.count, 2)

        // Alle Listen des Kontos: ein Aufruf = Vereinigung der Einzel-Abfragen.
        let lists: [IdRow] = try await phone.from("lists").select("id").execute().value
        let listIds = lists.map(\.id)
        var single: Set<String> = []
        for listId in listIds {
            single.formUnion(try await repo.fetchItemsSince(listId: listId, since: .distantPast).map(\.id))
        }
        let combined = try await repo.fetchItemsSince(listIds: listIds, since: .distantPast)
        XCTAssertEqual(Set(combined.map(\.id)), single, "ein Aufruf liefert dasselbe wie je Liste einzeln")
        XCTAssertEqual(combined.count, single.count, "keine doppelten Zeilen")

        // Zeitmarke: Die App rechnet in Millisekunden, der Server in Mikrosekunden – die neueste Zeile kann
        // deshalb bei „seit neuestem Stand“ noch einmal kommen (harmlos, HLC-Regel). 1 s später: nichts mehr.
        let newest = try XCTUnwrap(tempRows.compactMap(\.updatedAt).max())
        let none = try await repo.fetchItemsSince(listIds: temp, since: newest.addingTimeInterval(1))
        XCTAssertTrue(none.isEmpty, "Delta nach der Zeitmarke leer")
    }
}
#endif
