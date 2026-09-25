/*
 ItemImageStorageTests.swift
 FamlistTests
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Fotos in Storage (Migration 016): Verkleinern, Pfad aus dem Inhalt, Hochladen vor dem Senden,
   offline warten, Nachladen fremder Fotos für die Offline-Anzeige, Pfad-Regeln beim Abgleich,
   Umzug alter Base64-Fotos.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
import UIKit
@testable import Famlist

@MainActor
private final class FakeImageStorage: ImageStorage {
    var uploads: [(bucket: String, path: String, bytes: Int)] = []
    var files: [String: Data] = [:]
    var failNextUpload: Error?

    func upload(_ data: Data, bucket: String, path: String) async throws {
        if let error = failNextUpload { failNextUpload = nil; throw error }
        uploads.append((bucket, path, data.count))
        files[path] = data
    }

    func download(bucket: String, path: String) async throws -> Data {
        guard let data = files[path] else { throw URLError(.fileDoesNotExist) }
        return data
    }
}

@MainActor
private final class RecordingRepository: ItemsRepository {
    var requests: [ItemUpsertRequest] = []
    func upsertItems(_ requests: [ItemUpsertRequest]) async throws -> [ItemUpsertResult] {
        self.requests += requests
        return requests.map { ItemUpsertResult(id: $0.item.id, status: .applied, item: $0.item, message: nil) }
    }
    func observeItems(listId: UUID) -> AsyncStream<[ItemModel]> { AsyncStream { _ in } }
    func fetchItems(listId: UUID, cursor: PaginationCursor?, limit: Int) async throws -> [ItemModel] { [] }
    func fetchItemsSince(listId: UUID, since: Date) async throws -> [ItemModel] { [] }
}

@MainActor
final class ItemImageStorageTests: XCTestCase {
    private var container: ModelContainer!
    private var store: SwiftDataItemStore!
    private var storage: FakeImageStorage!
    private var repository: RecordingRepository!
    private var engine: SyncEngine!
    private var online = true
    private let listId = UUID(uuidString: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB")!

    override func setUp() async throws {
        container = PersistenceController(inMemory: true).container
        store = SwiftDataItemStore(context: container.mainContext)
        storage = FakeImageStorage()
        repository = RecordingRepository()
        online = true
        engine = SyncEngine(repository: repository, itemStore: store,
                            operationQueue: SyncOperationQueue(context: container.mainContext),
                            hlcGenerator: HybridLogicalClockGenerator(nodeId: "img"),
                            imageStorage: storage, isOnline: { [unowned self] in self.online })
    }

    override func tearDown() async throws {
        engine = nil; repository = nil; storage = nil; store = nil; container = nil
    }

    private func photo(_ color: UIColor = .red, size: CGSize = CGSize(width: 3000, height: 2000)) -> String {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            color.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        return ProductImageCodec.encode(image)!
    }

    // MARK: - Codec

    func test_encode_downscalesToMax600px() throws {
        let data = try XCTUnwrap(Data(base64Encoded: photo()))
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(max(image.size.width * image.scale, image.size.height * image.scale), 600, accuracy: 1)
        XCTAssertLessThan(data.count, 200_000)
    }

    func test_storagePath_isContentHash_andStable() throws {
        let base64 = photo()
        let a = try XCTUnwrap(ProductImageCodec.storageObject(folder: listId, base64: base64))
        let b = try XCTUnwrap(ProductImageCodec.storageObject(folder: listId, base64: base64))
        XCTAssertEqual(a.path, b.path)
        XCTAssertTrue(a.path.hasPrefix(listId.uuidString.lowercased() + "/"))
        XCTAssertTrue(a.path.hasSuffix(".jpg"))
        XCTAssertNotEqual(a.path, ProductImageCodec.storageObject(folder: listId, base64: photo(.blue))?.path)
    }

    // MARK: - Hochladen vor dem Senden

    func test_newPhoto_isUploaded_andOnlyPathIsSent() async throws {
        let base64 = photo()
        await engine.createItem(ItemModel(imageData: base64, name: "Käse", listId: listId.uuidString))

        XCTAssertEqual(storage.uploads.count, 1)
        XCTAssertEqual(storage.uploads.first?.bucket, "item-images")
        let sent = try XCTUnwrap(repository.requests.last)
        XCTAssertTrue(sent.includeImage)
        XCTAssertEqual(sent.item.imagePath, storage.uploads.first?.path)
        let entity = try XCTUnwrap(store.fetchItems(listId: listId).first)
        XCTAssertEqual(entity.imagePath, storage.uploads.first?.path, "Pfad auch lokal eingetragen")
        XCTAssertEqual(entity.imageData, base64, "lokale Kopie bleibt für offline")
    }

    func test_offlinePhoto_waits_thenUploads() async throws {
        online = false
        await engine.createItem(ItemModel(imageData: photo(), name: "Brot", listId: listId.uuidString))
        XCTAssertTrue(storage.uploads.isEmpty)
        XCTAssertEqual(try store.fetchItems(listId: listId).first?.imageData != nil, true, "sofort sichtbar")

        online = true
        await engine.resumeSync()
        XCTAssertEqual(storage.uploads.count, 1)
        XCTAssertEqual(repository.requests.count, 1)
    }

    func test_uploadFailsOffline_operationStaysQueued() async throws {
        storage.failNextUpload = URLError(.notConnectedToInternet)
        await engine.createItem(ItemModel(imageData: photo(), name: "Tee", listId: listId.uuidString))
        XCTAssertTrue(repository.requests.isEmpty, "ohne Foto-Upload kein Senden")
        XCTAssertEqual(engine.pendingOperations, 1)

        await engine.resumeSync()
        XCTAssertEqual(repository.requests.count, 1)
        XCTAssertEqual(engine.pendingOperations, 0)
    }

    func test_editWithoutPhotoChange_doesNotUploadAgain() async throws {
        await engine.createItem(ItemModel(imageData: photo(), name: "Öl", listId: listId.uuidString))
        var edit = try XCTUnwrap(store.fetchItems(listId: listId).first).toItemModel()
        edit.units = 3
        await engine.updateItem(edit)
        XCTAssertEqual(storage.uploads.count, 1)
        XCTAssertEqual(repository.requests.last?.includeImage, false)
    }

    func test_removePhoto_sendsNullPath() async throws {
        await engine.createItem(ItemModel(imageData: photo(), name: "Reis", listId: listId.uuidString))
        var edit = try XCTUnwrap(store.fetchItems(listId: listId).first).toItemModel()
        edit.imageData = nil
        await engine.updateItem(edit)
        let last = try XCTUnwrap(repository.requests.last)
        XCTAssertTrue(last.includeImage)
        XCTAssertNil(last.item.imagePath)
    }

    // MARK: - Umzug alter Base64-Fotos

    func test_migrateLegacyImages_uploadsAndSetsPath() async throws {
        var legacy = ItemModel(imageData: photo(), name: "Alt", listId: listId.uuidString)
        legacy.hlcTimestamp = 1; legacy.hlcCounter = 0; legacy.hlcNodeId = "x"
        try store.upsert(model: legacy)
        try store.save()

        await engine.migrateLegacyImages(listId: listId)

        XCTAssertEqual(storage.uploads.count, 1)
        XCTAssertNotNil(try store.fetchItems(listId: listId).first?.imagePath)
        await engine.migrateLegacyImages(listId: listId)
        XCTAssertEqual(storage.uploads.count, 1, "nur einmal")
    }

    // MARK: - Abgleich und Nachladen (offline verfügbar)

    func test_remoteNewPath_dropsStaleCopy_prefetcherDownloadsIt() async throws {
        var local = ItemModel(imageData: "YWJj", name: "Milch", listId: listId.uuidString)
        local.hlcTimestamp = 1; local.hlcCounter = 0; local.hlcNodeId = "a"
        try store.upsert(model: local)
        let newPhoto = photo(.green)
        let object = try XCTUnwrap(ProductImageCodec.storageObject(folder: listId, base64: newPhoto))
        storage.files[object.path] = object.data

        var remote = local
        remote.imageData = nil
        remote.imagePath = object.path
        remote.hlcTimestamp = 2
        XCTAssertEqual(try store.mergeRemote(remote, legacyImageKnown: false), .applied)
        XCTAssertNil(try store.fetchItems(listId: listId).first?.imageData)

        var refreshed = 0
        let prefetcher = ItemImagePrefetcher(store: store, storage: storage) { refreshed += 1 }
        await prefetcher.prefetchMissing()

        XCTAssertEqual(try store.fetchItems(listId: listId).first?.imageData, newPhoto)
        XCTAssertEqual(refreshed, 1)
        XCTAssertEqual(try store.fetchItems(listId: listId).first?.syncStatus, .synced, "Nachladen sendet nichts")
    }

    func test_remoteSamePath_keepsLocalCopy() throws {
        var local = ItemModel(imagePath: "p/1.jpg", imageData: "YWJj", name: "Milch", listId: listId.uuidString)
        local.hlcTimestamp = 1; local.hlcCounter = 0; local.hlcNodeId = "a"
        try store.upsert(model: local)
        var remote = local
        remote.imageData = nil
        remote.units = 4
        remote.hlcTimestamp = 2
        try store.mergeRemote(remote, legacyImageKnown: false)
        XCTAssertEqual(try store.fetchItems(listId: listId).first?.imageData, "YWJj")
    }

    func test_realtimeUpdateWithoutImageFields_keepsLegacyPhoto() throws {
        var local = ItemModel(imageData: "YWJj", name: "Milch", listId: listId.uuidString)
        local.hlcTimestamp = 1; local.hlcCounter = 0; local.hlcNodeId = "a"
        try store.upsert(model: local)
        var remote = local
        remote.imageData = nil
        remote.hlcTimestamp = 2
        // Realtime-UPDATE: image_path = null mitgeschickt, imagedata (TOAST, unverändert) fehlt.
        try store.mergeRemote(remote, imagePathKnown: true, legacyImageKnown: false)
        XCTAssertEqual(try store.fetchItems(listId: listId).first?.imageData, "YWJj")
    }

    func test_prefetcher_offline_keepsTrying_later() async throws {
        var remote = ItemModel(imagePath: "missing/1.jpg", name: "X", listId: listId.uuidString)
        remote.hlcTimestamp = 1; remote.hlcCounter = 0; remote.hlcNodeId = "a"
        try store.mergeRemote(remote)
        let prefetcher = ItemImagePrefetcher(store: store, storage: storage) {}
        await prefetcher.prefetchMissing()                      // Datei (noch) nicht da
        XCTAssertNil(try store.fetchItems(listId: listId).first?.imageData)
        storage.files["missing/1.jpg"] = Data([1, 2, 3])
        await prefetcher.prefetchMissing()
        XCTAssertEqual(try store.fetchItems(listId: listId).first?.imageData, Data([1, 2, 3]).base64EncodedString())
    }
}
