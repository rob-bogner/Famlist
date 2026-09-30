/*
 RemoteProductImageTests.swift
 FamlistTests
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Produkte aus dem globalen Katalog bekommen ihr Bild (Fehler 30.09.2026: nur der Name kam in die Liste).
 - RemoteProductImage: nur https, unlesbare Daten → nil, echtes Bild → Base64-JPEG.
 - ListViewModel.addItem(_:remoteImageURL:): Artikel sofort da, Bild danach; eigenes Foto bleibt; ohne Bild
   (Loader nil) bleibt der Artikel ohne Foto; http wird nicht geladen.
 - Bildadresse im Artikelstamm (Migration 035): aus dem globalen Katalog übernommen, Speichern/Ändern ohne
   Adresse behält sie, alte lokale Dateien ohne Feld lesbar, gemerkte Adresse lädt beim Hinzufügen das Bild.

 📝 Last Change:
 - Initial creation.
 ------------------------------------------------------------------------
 */

import XCTest
import SwiftData
import UIKit
@testable import Famlist

private actor LoaderCalls {
    private(set) var count = 0
    func record() { count += 1 }
}

@MainActor
final class RemoteProductImageTests: XCTestCase {
    private var viewModel: ListViewModel!
    private var container: ModelContainer!
    private let listId = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    override func setUp() async throws {
        try await super.setUp()
        container = try ModelContainer(for: Schema([ItemEntity.self, ListEntity.self]),
                                       configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        viewModel = ListViewModel(listId: listId, repository: PreviewItemsRepository(),
                                  itemStore: SwiftDataItemStore(context: context),
                                  listStore: SwiftDataListStore(context: context), startImmediately: false)
    }

    override func tearDown() async throws {
        viewModel = nil
        container = nil
        try await super.tearDown()
    }

    private func item(_ name: String, imageData: String? = nil) -> ItemModel {
        ItemModel(id: UUID().uuidString, imageData: imageData, name: name, units: 1, measure: "", price: 0,
                  isChecked: false, listId: listId.uuidString)
    }

    private func waitForImage(named name: String) async -> String? {
        for _ in 0..<100 {
            if let data = viewModel.items.first(where: { $0.name == name })?.imageData { return data }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return nil
    }

    // MARK: - RemoteProductImage

    func testAllowedURL_onlyHttpsWithHost() {
        XCTAssertNotNil(RemoteProductImage.allowedURL("https://images.openfoodfacts.org/a.jpg"))
        XCTAssertNil(RemoteProductImage.allowedURL("http://images.openfoodfacts.org/a.jpg"))
        XCTAssertNil(RemoteProductImage.allowedURL("file:///etc/passwd"))
        XCTAssertNil(RemoteProductImage.allowedURL(""))
    }

    func testEncode_rejectsGarbage_acceptsImage() throws {
        XCTAssertNil(RemoteProductImage.encode(Data("kein Bild".utf8)))
        XCTAssertNil(RemoteProductImage.encode(Data()))
        let png = try XCTUnwrap(UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }.pngData())
        let base64 = try XCTUnwrap(RemoteProductImage.encode(png))
        XCTAssertNotNil(UIImage(data: try XCTUnwrap(Data(base64Encoded: base64))))
    }

    // MARK: - ListViewModel

    func testAddItem_addsImmediately_thenAttachesImage() async {
        viewModel.remoteImageLoader = { _ in "QkFTRTY0" }
        viewModel.addItem(item("Dunkle Schokolade"), remoteImageURL: "https://images.openfoodfacts.org/x.jpg")
        XCTAssertEqual(viewModel.items.map(\.name), ["Dunkle Schokolade"], "Artikel muss sofort da sein")
        let image = await waitForImage(named: "Dunkle Schokolade")
        XCTAssertEqual(image, "QkFTRTY0")
    }

    func testAddItem_withoutURL_orLoaderFailure_staysWithoutImage() async {
        viewModel.remoteImageLoader = { _ in nil }
        viewModel.addItem(item("Milch"), remoteImageURL: "https://images.openfoodfacts.org/x.jpg")
        viewModel.addItem(item("Brot"), remoteImageURL: nil)
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertNil(viewModel.items.first(where: { $0.name == "Milch" })?.imageData)
        XCTAssertNil(viewModel.items.first(where: { $0.name == "Brot" })?.imageData)
    }

    func testAttach_neverOverwritesOwnPhoto() {
        viewModel.addItem(item("Butter", imageData: "RUlHRU4="))
        viewModel.attachRemoteImage("S0FUQUxPRw==", toItemWithKey: ItemIdentity.normalizedKey("Butter"))
        XCTAssertEqual(viewModel.items.first?.imageData, "RUlHRU4=")
    }

    // MARK: - Bildadresse im Artikelstamm (Migration 035)

    private func entry(_ name: String, imageUrl: String?) -> ItemCatalogEntry {
        ItemCatalogEntry(id: UUID().uuidString, ownerPublicId: "o", name: name, measure: "", price: 0, imageUrl: imageUrl)
    }

    func testGlobalProduct_carriesImageUrlIntoCatalogEntry() {
        let product = GlobalProductEntry(id: "20815356", name: "Dunkle Schokolade", brand: "Lidl", category: nil,
                                         measure: nil, imageUrl: "https://images.openfoodfacts.org/x.jpg", scansN: 1)
        XCTAssertEqual(product.toItemCatalogEntry(ownerPublicId: "").imageUrl, "https://images.openfoodfacts.org/x.jpg")
    }

    func testCatalogSave_withoutUrl_keepsStoredUrl_withUrl_replacesIt() {
        let stored = [entry("Schokolade", imageUrl: "https://a.example/1.jpg")]
        let kept = CatalogOperation.save(entry("schokolade", imageUrl: nil)).apply(to: stored)
        XCTAssertEqual(kept.first?.imageUrl, "https://a.example/1.jpg", "Speichern ohne Adresse darf sie nicht löschen")
        let replaced = CatalogOperation.save(entry("Schokolade", imageUrl: "https://a.example/2.jpg")).apply(to: stored)
        XCTAssertEqual(replaced.first?.imageUrl, "https://a.example/2.jpg")
    }

    func testCatalogUpdate_keepsStoredUrl() {
        let stored = [entry("Milch", imageUrl: "https://a.example/m.jpg")]
        var edited = stored[0]
        edited.imageUrl = nil
        edited.price = 1.29
        let result = CatalogOperation.update(edited).apply(to: stored)
        XCTAssertEqual(result.first?.imageUrl, "https://a.example/m.jpg")
        XCTAssertEqual(result.first?.price, 1.29)
    }

    func testCatalogEntry_decodesOldLocalFileWithoutImageUrl() throws {
        let json = #"{"id":"1","owner_public_id":"o","name":"Brot","measure":"","price":0}"#
        let decoded = try JSONDecoder().decode(ItemCatalogEntry.self, from: Data(json.utf8))
        XCTAssertNil(decoded.imageUrl)
        XCTAssertEqual(decoded.name, "Brot")
    }

    func testAddItem_fromCatalogEntryWithStoredUrl_loadsImage() async {
        viewModel.remoteImageLoader = { _ in "U1RBTU0=" }
        let catalogEntry = entry("Haferflocken", imageUrl: "https://images.openfoodfacts.org/h.jpg")
        let listItem = catalogEntry.toItemModel(listId: listId.uuidString, ownerPublicId: nil)
        viewModel.addItem(listItem, remoteImageURL: catalogEntry.imageUrl)
        let image = await waitForImage(named: "Haferflocken")
        XCTAssertEqual(image, "U1RBTU0=")
    }

    func testLoad_ignoresHttpUrl() async {
        let calls = LoaderCalls()
        viewModel.remoteImageLoader = { _ in await calls.record(); return "eA==" }
        viewModel.addItem(item("Tee"), remoteImageURL: "http://images.openfoodfacts.org/t.jpg")
        try? await Task.sleep(nanoseconds: 100_000_000)
        let count = await calls.count
        XCTAssertEqual(count, 0)
        XCTAssertNil(viewModel.items.first?.imageData)
    }

    func testAttach_fillsExistingItemWithoutPhoto() {
        viewModel.addItem(item("Käse"))
        viewModel.attachRemoteImage("S0FUQUxPRw==", toItemWithKey: ItemIdentity.normalizedKey("käse"))
        XCTAssertEqual(viewModel.items.first?.imageData, "S0FUQUxPRw==")
    }
}
