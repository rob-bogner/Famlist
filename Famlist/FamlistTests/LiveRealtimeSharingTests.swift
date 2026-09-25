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
import SwiftData
import UIKit
@testable import Famlist

/// Sitzungsspeicher im RAM – je Client eigener, damit zwei Konten parallel angemeldet bleiben.
private final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private var values: [String: Data] = [:]
    private let lock = NSLock()
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

/// Dünne Fassade um einen echten SupabaseClient – damit laufen die App-Klassen (Repository, Realtime-Manager,
/// SyncEngine) unverändert gegen das echte Backend, je Konto mit eigenem Client.
private final class LiveTestClient: SupabaseClienting {
    let client: SupabaseClient
    init(_ client: SupabaseClient) { self.client = client }
    var auth: any AuthClienting { client.auth }
    var realtime: RealtimeClientV2 { client.realtimeV2 }
    func from(_ table: String) -> PostgrestQueryBuilder { client.from(table) }
    func storageUpload(bucket: String, path: String, data: Data, contentType: String) async throws {
        _ = try await client.storage.from(bucket).upload(path, data: data,
                                                         options: FileOptions(contentType: contentType, upsert: true))
    }
    func storageDownload(bucket: String, path: String) async throws -> Data {
        try await client.storage.from(bucket).download(path: path)
    }
    func storageCreateSignedURL(bucket: String, path: String, expiresIn: Int) async throws -> String { "" }
    func rpc(_ function: String) async throws { try await client.rpc(function).execute() }
    func rpcRows<P: Encodable & Sendable, R: Decodable & Sendable>(_ function: String, params: P) async throws -> [R] {
        try await client.rpc(function, params: params).execute().value
    }
    func rpcValue<P: Encodable & Sendable, R: Decodable & Sendable>(_ function: String, params: P) async throws -> R {
        try await client.rpc(function, params: params).execute().value
    }
}

/// Ein simuliertes Gerät: eigener SwiftData-Speicher, eigene Warteschlange, echte App-Klassen.
@MainActor
private final class LiveDevice {
    let container = PersistenceController(inMemory: true).container
    let store: SwiftDataItemStore
    let repository: SupabaseItemsRepository
    let engine: SyncEngine
    let images: SupabaseImageStorage
    let prefetcher: ItemImagePrefetcher

    init(client: SupabaseClient, node: String) {
        store = SwiftDataItemStore(context: container.mainContext)
        let facade = LiveTestClient(client)
        repository = SupabaseItemsRepository(client: facade, itemStore: store)
        images = SupabaseImageStorage(client: facade)
        engine = SyncEngine(repository: repository, itemStore: store,
                            operationQueue: SyncOperationQueue(context: container.mainContext),
                            hlcGenerator: HybridLogicalClockGenerator(nodeId: node), imageStorage: images)
        prefetcher = ItemImagePrefetcher(store: store, storage: images) {}
    }

    func visible(_ listId: UUID) -> [ItemEntity] { (try? store.fetchItems(listId: listId)) ?? [] }
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
            options: .init(auth: .init(storage: MemoryAuthStorage()),
                           global: .init(session: AppSupabaseClient.uncachedSession))
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

        // 3. Mitglied abonniert den privaten Broadcast-Kanal der Liste (wie SupabaseRealtimeManager, Migration 017)
        let log = EventLog()
        let itemsChannel = member.realtimeV2.channel(SupabaseRealtimeManager.topic(for: newListId)) { $0.isPrivate = true }
        let changes = itemsChannel.broadcastStream(event: SupabaseRealtimeManager.itemChangeEvent)
        try await itemsChannel.subscribeWithError()
        let changeTask = Task {
            for await message in changes {
                guard let event = SupabaseRealtimeManager.event(from: message) else { continue }
                switch event {
                case .insert(let p):
                    let r = p["record"] as? [String: Any] ?? [:]
                    await log.add("insert:\(r["name"] as? String ?? "")")
                case .update(let p):
                    let r = p["record"] as? [String: Any] ?? [:]
                    await log.add("update:\(r["name"] as? String ?? ""):\(r["units"] as? Int ?? -1):\(r["tombstone"] as? Bool ?? false)")
                case .delete:
                    await log.add("delete")
                }
            }
        }
        defer { changeTask.cancel() }

        // Außenstehender (kein Mitglied) versucht, den Kanal mitzuhören.
        let outsider = try await signedInClient(.developer)
        let outsiderLog = EventLog()
        let spyChannel = outsider.realtimeV2.channel(SupabaseRealtimeManager.topic(for: newListId)) { $0.isPrivate = true }
        let spyChanges = spyChannel.broadcastStream(event: SupabaseRealtimeManager.itemChangeEvent)
        // Der Server verweigert den Beitritt (Policy list_topic_read); nicht länger als 5 s darauf warten.
        let outsiderJoined = await withTaskGroup(of: Bool.self) { group -> Bool in
            group.addTask { (try? await spyChannel.subscribeWithError()) != nil }
            group.addTask { try? await Task.sleep(nanoseconds: 5_000_000_000); return false }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        let spyTask = Task { for await _ in spyChanges { await outsiderLog.add("leak") } }
        defer { spyTask.cancel() }

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

        // Der Außenstehende darf nichts empfangen haben.
        let leaked = await outsiderLog.entries.count
        XCTAssertEqual(leaked, 0, "Kein Ereignis darf an Nicht-Mitglieder gehen (angemeldet: \(outsiderJoined))")
        await outsider.realtimeV2.removeAllChannels()

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

    // MARK: - Echter App-Pfad: SyncEngine → RPC → Realtime → SwiftData des anderen Geräts

    private func makeSharedList() async throws -> UUID {
        let ownerId = try await owner.auth.session.user.id
        struct NewList: Encodable { let id: UUID; let owner_id: UUID; let title: String; let is_default: Bool }
        struct ListParam: Encodable, Sendable { let p_list_id: UUID }
        struct TokenParam: Encodable, Sendable { let p_token: String }
        struct TokenRow: Decodable { let token: String }
        let newListId = UUID()
        try await owner.from("lists")
            .insert(NewList(id: newListId, owner_id: ownerId, title: "Livetest Pipeline", is_default: false)).execute()
        listId = newListId
        let tokens: [TokenRow] = try await owner.rpc("create_list_invite", params: ListParam(p_list_id: newListId)).execute().value
        let _: UUID = try await member.rpc("accept_list_invite", params: TokenParam(p_token: XCTUnwrap(tokens.first?.token))).execute().value
        return newListId
    }

    @MainActor
    func test_appPipeline_changesOnOneDevice_reachOtherDevice_andConverge() async throws {
        let list = try await makeSharedList()
        let deviceA = LiveDevice(client: owner, node: "live-A")
        let deviceB = LiveDevice(client: member, node: "live-B")

        // B beobachtet die Liste über den echten Realtime-Manager der App.
        let stream = deviceB.repository.observeItems(listId: list)
        let observer = Task { for await _ in stream {} }
        defer { observer.cancel() }
        try await Task.sleep(nanoseconds: 2_000_000_000)          // Kanal-Anmeldung abwarten

        // 1. Anlegen auf A → erscheint auf B
        await deviceA.engine.createItem(ItemModel(name: "Livetest Milch", units: 1, listId: list.uuidString))
        try await waitFor("Anlegen auf B") { await MainActor.run { deviceB.visible(list).map(\.name) == ["Livetest Milch"] } }

        // 2. Menge ändern auf A → B zeigt 3
        var milk = try XCTUnwrap(deviceA.visible(list).first).toItemModel()
        milk.units = 3
        await deviceA.engine.updateItem(milk)
        try await waitFor("Menge 3 auf B") { await MainActor.run { deviceB.visible(list).first?.units == 3 } }

        // 3. „Alle abhaken“ auf A (gebündelt) → alles abgehakt auf B
        for name in ["Livetest Brot", "Livetest Käse"] {
            await deviceA.engine.createItem(ItemModel(name: name, listId: list.uuidString))
        }
        try await waitFor("3 Artikel auf B") { await MainActor.run { deviceB.visible(list).count == 3 } }
        let allChecked = deviceA.visible(list).map { entity -> ItemModel in
            var m = entity.toItemModel(); m.isChecked = true; return m
        }
        await deviceA.engine.applyLocalChanges(allChecked)
        try await waitFor("alle abgehakt auf B") {
            await MainActor.run { deviceB.visible(list).count == 3 && deviceB.visible(list).allSatisfy(\.isChecked) }
        }

        // 4. Gleichzeitige Änderung auf beiden Geräten → beide landen beim selben (neueren) Stand
        var onB = try XCTUnwrap(deviceB.visible(list).first { $0.name == "Livetest Milch" }).toItemModel()
        onB.units = 5
        await deviceB.engine.updateItem(onB)
        var onA = try XCTUnwrap(deviceA.visible(list).first { $0.name == "Livetest Milch" }).toItemModel()
        onA.units = 9                                              // später geschrieben → gewinnt
        await deviceA.engine.updateItem(onA)
        try await waitFor("Konvergenz auf 9") {
            await MainActor.run {
                deviceA.visible(list).first { $0.name == "Livetest Milch" }?.units == 9
                    && deviceB.visible(list).first { $0.name == "Livetest Milch" }?.units == 9
            }
        }

        // 5. Löschen auf B → verschwindet auf A (A beobachtet jetzt ebenfalls)
        let streamA = deviceA.repository.observeItems(listId: list)
        let observerA = Task { for await _ in streamA {} }
        defer { observerA.cancel() }
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let toDelete = try XCTUnwrap(deviceB.visible(list).first { $0.name == "Livetest Brot" }).toItemModel()
        await deviceB.engine.deleteItem(toDelete)
        try await waitFor("Löschung auf A") {
            await MainActor.run { !deviceA.visible(list).contains { $0.name == "Livetest Brot" } }
        }

        // 6. Warteschlangen leer, nichts fehlgeschlagen
        XCTAssertEqual(deviceA.engine.pendingOperations, 0)
        XCTAssertEqual(deviceB.engine.pendingOperations, 0)
    }

    @MainActor
    func test_photo_uploadedOnA_availableOfflineOnB() async throws {
        let list = try await makeSharedList()
        let deviceA = LiveDevice(client: owner, node: "live-A")
        let deviceB = LiveDevice(client: member, node: "live-B")
        let stream = deviceB.repository.observeItems(listId: list)
        let observer = Task { for await _ in stream {} }
        defer { observer.cancel() }
        try await Task.sleep(nanoseconds: 2_000_000_000)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900), format: format).image { ctx in
            UIColor.orange.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
        }
        let base64 = try XCTUnwrap(ProductImageCodec.encode(image))
        await deviceA.engine.createItem(ItemModel(imageData: base64, name: "Livetest Foto", listId: list.uuidString))
        let path = try XCTUnwrap(deviceA.visible(list).first?.imagePath, "Pfad nach dem Hochladen gesetzt")

        try await waitFor("Pfad auf B") { await MainActor.run { deviceB.visible(list).first?.imagePath == path } }
        await deviceB.prefetcher.prefetchMissing()
        XCTAssertEqual(deviceB.visible(list).first?.imageData, base64, "B hat das Foto lokal (offline verfügbar)")

        // Datenbankzeile trägt kein Base64 mehr
        struct Row: Decodable { let imagedata: String?; let image_path: String? }
        let rows: [Row] = try await owner.from("items").select("imagedata,image_path")
            .eq("list_id", value: list.uuidString).execute().value
        XCTAssertEqual(rows.first?.image_path, path)
        XCTAssertNil(rows.first?.imagedata)

        // Nach dem Entfernen verweigert der SERVER das Foto. Frischer Client, damit kein lokaler
        // HTTP-Cache (URLCache, cache-control) das Ergebnis verfälscht.
        let memberId = try await member.auth.session.user.id
        try await owner.from("list_members").delete().eq("list_id", value: list.uuidString)
            .eq("profile_id", value: memberId.uuidString).execute()
        let freshMember = try await signedInClient(.demo)
        do {
            _ = try await freshMember.storage.from("item-images").download(path: path)
            XCTFail("Nach dem Entfernen kein Zugriff mehr auf das Foto")
        } catch {}
    }
}
#endif
