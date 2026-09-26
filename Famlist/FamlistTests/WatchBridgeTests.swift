/*
 WatchBridgeTests.swift
 FamlistTests
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - iPhone-Seite der Apple Watch (WatchBridge):
   - Artikel vom Uhr-Sofort-Weg übernimmt das iPhone nur per HLC und reiht sie NICHT ein; eine ältere HLC
     ändert nichts.
   - Anmelde-Code nur, wenn das iPhone angemeldet ist; „zu früh“ (429) wird gemeldet.
   - Abmelden und Kontowechsel gehen über den garantierten Weg; der erste Start meldet nichts ab.
   - Weiterleiten nur bei erreichbarer Uhr, in Teilen zu 50.

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Supabase
import SwiftData
import XCTest
@testable import Famlist

/// Transport-Spion: schreibt alles mit, was die Brücke senden würde.
@MainActor
final class SpyWatchTransport: WatchTransport {
    var isReachable = true
    var receivedContext: WatchApplicationContext?
    private(set) var sent: [WatchMessage] = []
    private(set) var transferred: [WatchMessage] = []
    private(set) var contexts: [WatchApplicationContext] = []
    var replyWith: Result<WatchMessage, Error>?

    func send(_ message: WatchMessage, reply: (@MainActor (Result<WatchMessage, Error>) -> Void)?) {
        sent.append(message)
        if let reply, let replyWith { reply(replyWith) }
    }
    func transfer(_ message: WatchMessage) { transferred.append(message) }
    func updateContext(_ context: WatchApplicationContext) { contexts.append(context) }
}

/// Angemeldetes Konto (Sitzung) und eine Edge Function mit vorgegebener Antwort.
private final class GrantingClient: SupabaseClienting, @unchecked Sendable {
    let userId = UUID()
    var functionError: Error?
    private(set) var invoked: [String] = []

    private final class Auth: AuthClienting, @unchecked Sendable {
        let session: Session
        init(userId: UUID) {
            let user = User(id: userId, appMetadata: [:], userMetadata: [:], aud: "authenticated", email: "t@example.com",
                            createdAt: Date(), updatedAt: Date())
            session = Session(accessToken: "a", tokenType: "bearer", expiresIn: 3600,
                              expiresAt: Date().timeIntervalSince1970 + 3600, refreshToken: "r", user: user)
        }
        var currentUser: User? { session.user }
        var authStateChanges: AsyncStream<(event: AuthChangeEvent, session: Session?)> { AsyncStream { _ in } }
        func signInWithOTP(email: String, redirectTo: URL?) async throws {}
        func signIn(email: String, password: String) async throws -> Session { session }
        func signUp(email: String, password: String) async throws {}
        func signOut(scope: SignOutScope) async throws {}
        func session(from url: URL) async throws -> Session { session }
    }
    private lazy var authClient = Auth(userId: userId)

    var auth: any AuthClienting { authClient }
    var realtime: RealtimeClientV2 { fatalError("realtime not needed") }
    func from(_ table: String) -> PostgrestQueryBuilder { fatalError("from not needed") }
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {}
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String { "" }
    func invokeFunction<R: Decodable & Sendable>(_ name: String) async throws -> R {
        invoked.append(name)
        if let functionError { throw functionError }
        return try JSONDecoder().decode(R.self, from: Data(#"{"token_hash":"hash-1","type":"magiclink"}"#.utf8))
    }
}

@MainActor
final class WatchBridgeTests: XCTestCase {
    private var context: ModelContext!
    private var store: SwiftDataItemStore!
    private var queue: SyncOperationQueue!
    private var transport: SpyWatchTransport!
    private var defaults: UserDefaults!
    private let listId = UUID()

    override func setUp() async throws {
        let container = try ModelContainer(for: ItemEntity.self, ListEntity.self, SyncOperation.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        store = SwiftDataItemStore(context: context)
        queue = SyncOperationQueue(context: context)
        transport = SpyWatchTransport()
        defaults = UserDefaults(suiteName: "WatchBridgeTests.\(UUID().uuidString)")
    }

    private func bridge(client: SupabaseClienting? = nil) -> WatchBridge {
        WatchBridge(transport: transport, client: client, itemStore: store, defaults: defaults)
    }

    private func item(_ id: UUID, units: Int, hlc: Int64, node: String = "watch") -> ItemModel {
        ItemModel(id: id.uuidString, name: "Milch", units: units, measure: "", listId: listId.uuidString,
                  hlcTimestamp: hlc, hlcCounter: 0, hlcNodeId: node, tombstone: false)
    }

    // MARK: - Sofort-Weg von der Uhr

    func test_itemsFromWatch_mergedByHLC_notQueued() async throws {
        let id = UUID()
        _ = try store.mergeRemote(item(id, units: 1, hlc: 1_000, node: "phone"))
        try store.save()
        var merged: [ItemModel] = []
        let sut = bridge()
        sut.onItemsMerged = { merged = $0 }

        let reply = await sut.transport(didReceive: .itemsChanged([item(id, units: 4, hlc: 2_000)]))

        XCTAssertNil(reply)
        XCTAssertEqual(try store.fetchItem(id: id)?.units, 4, "neuere HLC der Uhr übernommen")
        XCTAssertEqual(queue.count, 0, "nicht erneut an den Server – das tut die Uhr")
        XCTAssertEqual(merged.map(\.units), [4])
    }

    func test_olderItemFromWatch_changesNothing() async throws {
        let id = UUID()
        _ = try store.mergeRemote(item(id, units: 7, hlc: 5_000, node: "phone"))
        try store.save()
        var called = false
        let sut = bridge()
        sut.onItemsMerged = { _ in called = true }

        _ = await sut.transport(didReceive: .itemsChanged([item(id, units: 1, hlc: 4_000)]))

        XCTAssertEqual(try store.fetchItem(id: id)?.units, 7)
        XCTAssertFalse(called)
    }

    // MARK: - Anmelde-Code

    func test_sessionRequest_withoutSignedInPhone_isRefused() async {
        let reply = await bridge(client: nil).transport(didReceive: .requestSession)
        XCTAssertEqual(reply, .sessionUnavailable(reason: .signedOut))
    }

    func test_sessionRequest_returnsGrantForSignedInAccount() async {
        let client = GrantingClient()
        let reply = await bridge(client: client).transport(didReceive: .requestSession)
        XCTAssertEqual(reply, .sessionGrant(tokenHash: "hash-1", userId: client.userId))
        XCTAssertEqual(client.invoked, ["watch-session"])
    }

    func test_sessionRequest_tooEarly_reportsRateLimit() async {
        let client = GrantingClient()
        client.functionError = FunctionsError.httpError(code: 429, data: Data())
        let reply = await bridge(client: client).transport(didReceive: .requestSession)
        XCTAssertEqual(reply, .sessionUnavailable(reason: .rateLimited))
    }

    // MARK: - Konto

    func test_firstSignIn_doesNotSignOutWatch() {
        let user = UUID()
        bridge().accountDidChange(userId: user)
        XCTAssertTrue(transport.transferred.isEmpty)
        XCTAssertEqual(transport.contexts.last?.userId, user)
    }

    func test_signOut_andAccountSwitch_useGuaranteedChannel() {
        let sut = bridge()
        let first = UUID(), second = UUID()
        sut.accountDidChange(userId: first)
        sut.accountDidChange(userId: second)                          // Kontowechsel
        XCTAssertEqual(transport.transferred, [.signedOut])
        XCTAssertEqual(transport.contexts.last?.userId, second)
        sut.accountDidChange(userId: nil)                             // Abmelden
        XCTAssertEqual(transport.transferred, [.signedOut, .signedOut])
        XCTAssertNil(transport.contexts.last?.userId)
    }

    func test_sameAccountAgain_doesNotSignOutWatch() {
        let sut = bridge()
        let user = UUID()
        sut.accountDidChange(userId: user)
        sut.accountDidChange(userId: user)                            // App-Neustart, gleiche Anmeldung
        XCTAssertTrue(transport.transferred.isEmpty)
    }

    // MARK: - Weiterleiten

    func test_forward_onlyWhenReachable_inBatches() {
        let items = (0..<60).map { _ in item(UUID(), units: 1, hlc: 1) }
        transport.isReachable = false
        bridge().forward(items)
        XCTAssertTrue(transport.sent.isEmpty, "Uhr nicht erreichbar → nichts senden (Supabase gleicht ab)")
        transport.isReachable = true
        bridge().forward(items)
        XCTAssertEqual(transport.sent.count, 2)
    }

    func test_forwardStored_readsFromStore_andHintsList() throws {
        let id = UUID()
        _ = try store.mergeRemote(item(id, units: 3, hlc: 9_000, node: "other"))
        try store.save()
        bridge().forwardStored(listId: listId, itemIds: [id.uuidString])
        guard case .itemsChanged(let items) = transport.sent.first else { return XCTFail("nichts gesendet") }
        XCTAssertEqual(items.map(\.units), [3])
        XCTAssertEqual(transport.contexts.last?.changedListIds, [listId])
    }
}
