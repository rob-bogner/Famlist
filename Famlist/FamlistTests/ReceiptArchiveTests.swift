/*
 ReceiptArchiveTests.swift
 FamlistTests

 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Tests für das Kassenzettel-Archiv: Warteschlange offline → online, Schalter aus, Löschen (Preise bleiben),
   abgelehnte Aufträge, Abmelden.

 🔰 Notes for Beginners:
 - Jeder Test bekommt eigene Ordner und eigene UserDefaults; nichts bleibt zwischen den Tests liegen.
 - `InMemoryReceiptsRepository.failWith` simuliert „kein Netz“ (URLError) oder „vom Server abgelehnt“.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

@MainActor
final class ReceiptArchiveTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private let listId = UUID()

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ReceiptArchiveTests-\(UUID().uuidString)")
        defaults = UserDefaults(suiteName: "ReceiptArchiveTests")
        defaults.removePersistentDomain(forName: "ReceiptArchiveTests")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
        defaults.removePersistentDomain(forName: "ReceiptArchiveTests")
    }

    private func makeStore() -> ReceiptArchiveLocalStore {
        ReceiptArchiveLocalStore(directory: root.appendingPathComponent("support"),
                                 photoCache: root.appendingPathComponent("caches"))
    }

    private func makeArchive(_ repo: InMemoryReceiptsRepository?, store: ReceiptArchiveLocalStore? = nil) -> ReceiptArchive {
        ReceiptArchive(repository: repo, store: store ?? makeStore(), defaults: defaults)
    }

    private func draft(pages: Int = 2, store: String = "REWE") -> ReceiptArchiveDraft {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 60, height: 120)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 60, height: 120))
        }
        return ReceiptArchiveDraft(pages: Array(repeating: image, count: pages), listId: listId, listTitle: "Wocheneinkauf",
                                   createdBy: UUID(), creatorName: "Robert", storeName: store, purchasedAt: Date(),
                                   total: Decimal(string: "23.47")!, lineCount: 9, savedPriceCount: 7)
    }

    // MARK: - Offline → online

    func test_archiveOffline_isVisibleAtOnce_andUploadedWhenOnline() async throws {
        let repo = InMemoryReceiptsRepository()
        repo.failWith = URLError(.notConnectedToInternet)
        let archive = makeArchive(repo)
        let saved = await archive.archive(draft())
        let receipt = try XCTUnwrap(saved)
        XCTAssertEqual(archive.receipts.map(\.id), [receipt.id])
        XCTAssertTrue(archive.receipts[0].isPending)
        XCTAssertEqual(archive.pendingCount, 1)
        XCTAssertTrue(repo.receipts.isEmpty)

        repo.failWith = nil
        await archive.flush()
        XCTAssertEqual(repo.receipts.map(\.id), [receipt.id])
        XCTAssertEqual(Set(repo.photos.keys), Set(receipt.photoPaths))
        XCTAssertEqual(archive.pendingCount, 0)
        XCTAssertFalse(try XCTUnwrap(archive.receipts.first).isPending)
        XCTAssertNotNil(archive.store.photo(path: receipt.photoPaths[0]), "Foto liegt danach im Cache")
    }

    func test_queueSurvivesRestart() async throws {
        let repo = InMemoryReceiptsRepository()
        repo.failWith = URLError(.notConnectedToInternet)
        let receiptSaved = await makeArchive(repo).archive(draft())
        let receipt = try XCTUnwrap(receiptSaved)

        let restarted = makeArchive(repo)                    // neuer Speicher auf denselben Ordnern
        XCTAssertEqual(restarted.receipts.map(\.id), [receipt.id])
        repo.failWith = nil
        await restarted.flush()
        XCTAssertEqual(repo.receipts.map(\.id), [receipt.id])
    }

    func test_photoPaths_areLowercaseListAndReceiptFolders() async throws {
        let receiptSaved = await makeArchive(nil).archive(draft(pages: 3))
        let receipt = try XCTUnwrap(receiptSaved)
        XCTAssertEqual(receipt.photoPaths.count, 3)
        XCTAssertEqual(receipt.photoPaths[2],
                       "\(listId.uuidString.lowercased())/\(receipt.id.uuidString.lowercased())/3.jpg")
        XCTAssertGreaterThan(receipt.bytes, 0)
    }

    // MARK: - Schalter

    func test_switchOff_savesNothing() async {
        defaults.set(false, forKey: ReceiptArchiveSetting.storageKey)
        let repo = InMemoryReceiptsRepository()
        let archive = makeArchive(repo)
        let saved = await archive.archive(draft())
        XCTAssertNil(saved)
        XCTAssertTrue(archive.receipts.isEmpty)
        XCTAssertEqual(archive.pendingCount, 0)
        XCTAssertTrue(repo.receipts.isEmpty && repo.photos.isEmpty)
        let files = (try? FileManager.default.subpathsOfDirectory(atPath: root.path)) ?? []
        XCTAssertFalse(files.contains { $0.hasSuffix(".jpg") }, "Keine Fotodatei lokal")
    }

    func test_switchDefault_isOn() {
        XCTAssertTrue(ReceiptArchiveSetting.isEnabled(defaults))
    }

    // MARK: - Löschen

    func test_deleteUploaded_removesPhotosAndRow_pricesStay() async throws {
        let repo = InMemoryReceiptsRepository()
        let points = InMemoryPricePointsRepository()
        let priceBook = PriceBook(repository: points, defaults: defaults)
        await priceBook.save([PricePoint(itemName: "Butter", storeName: "REWE", purchasedAt: Date(), price: 2.49)])
        let archive = makeArchive(repo)
        let receiptSaved = await archive.archive(draft())
        let receipt = try XCTUnwrap(receiptSaved)
        await archive.flush()

        await archive.delete(try XCTUnwrap(archive.receipts.first))
        XCTAssertTrue(repo.receipts.isEmpty)
        XCTAssertTrue(repo.photos.isEmpty)
        XCTAssertTrue(archive.receipts.isEmpty)
        XCTAssertNil(archive.store.photo(path: receipt.photoPaths[0]))
        XCTAssertEqual(points.stored.map(\.itemName), ["Butter"], "Preispunkte bleiben")
    }

    func test_deletePendingOffline_neverReachesServer() async throws {
        let repo = InMemoryReceiptsRepository()
        repo.failWith = URLError(.notConnectedToInternet)
        let archive = makeArchive(repo)
        let receiptSaved = await archive.archive(draft())
        let receipt = try XCTUnwrap(receiptSaved)
        await archive.delete(receipt)
        XCTAssertTrue(archive.receipts.isEmpty)
        XCTAssertEqual(archive.pendingCount, 0)
        XCTAssertNil(archive.store.photo(path: receipt.photoPaths[0]))

        repo.failWith = nil
        await archive.flush()
        XCTAssertTrue(repo.receipts.isEmpty && repo.photos.isEmpty)
    }

    func test_deleteOffline_isQueuedAndSentLater() async throws {
        let repo = InMemoryReceiptsRepository()
        let archive = makeArchive(repo)
        _ = await archive.archive(draft())
        await archive.flush()
        repo.failWith = URLError(.notConnectedToInternet)
        await archive.delete(try XCTUnwrap(archive.receipts.first))
        XCTAssertTrue(archive.receipts.isEmpty, "Sofort weg, auch offline")
        XCTAssertEqual(repo.receipts.count, 1)

        repo.failWith = nil
        await archive.flush()
        XCTAssertTrue(repo.receipts.isEmpty && repo.photos.isEmpty)
    }

    // MARK: - Fehler, Laden, Abmelden

    func test_rejectedUpload_isDroppedAfterMaxFailures() async throws {
        let repo = InMemoryReceiptsRepository()
        repo.failWith = NSError(domain: "Postgrest", code: 42501)
        let archive = makeArchive(repo)
        let receiptSaved = await archive.archive(draft())
        let receipt = try XCTUnwrap(receiptSaved)
        for _ in 0..<ReceiptArchive.maxFailures { await archive.flush() }
        XCTAssertEqual(archive.pendingCount, 0)
        XCTAssertTrue(archive.receipts.isEmpty)
        XCTAssertNil(archive.store.photo(path: receipt.photoPaths[0]), "Lokale Fotos aufgeräumt")
    }

    func test_refresh_loadsServer_andKeepsLastStateOffline() async {
        let other = ArchivedReceipt(id: UUID(), listId: listId, listTitle: "Wocheneinkauf", createdBy: UUID(),
                                    creatorName: "Anna", storeName: "Aldi", purchasedAt: Date(), total: 12,
                                    lineCount: 4, savedPriceCount: 4, photoPaths: ["a/b/1.jpg"], bytes: 1000,
                                    createdAt: Date())
        let repo = InMemoryReceiptsRepository([other])
        let archive = makeArchive(repo)
        await archive.refresh()
        XCTAssertEqual(archive.receipts.map(\.storeName), ["Aldi"])
        XCTAssertEqual(archive.totalBytes, 1000)

        repo.failWith = URLError(.notConnectedToInternet)
        await archive.refresh()
        XCTAssertEqual(archive.receipts.map(\.storeName), ["Aldi"], "Ohne Netz bleibt der letzte Stand")
    }

    /// Live-Test 26.09.2026: Bon nach „Löschen“ wieder da, weil eine ältere Server-Antwort den Stand überschrieb.
    func test_refresh_ignoresStaleFetch_whenDeletedMeanwhile() async throws {
        let repo = InMemoryReceiptsRepository()
        let archive = makeArchive(repo)
        let saved = await archive.archive(draft())
        let receipt = try XCTUnwrap(saved)
        await archive.flush()
        repo.duringFetch = { await archive.delete(archive.receipts[0]) }

        await archive.refresh()
        XCTAssertFalse(archive.receipts.contains { $0.id == receipt.id }, "gelöschter Bon bleibt weg")
        XCTAssertTrue(repo.receipts.isEmpty)
    }

    func test_clearLocal_removesEverything() async throws {
        let repo = InMemoryReceiptsRepository()
        repo.failWith = URLError(.notConnectedToInternet)
        let archive = makeArchive(repo)
        let receiptSaved = await archive.archive(draft())
        let receipt = try XCTUnwrap(receiptSaved)
        archive.clearLocal()
        XCTAssertTrue(archive.receipts.isEmpty)
        XCTAssertEqual(archive.pendingCount, 0)
        XCTAssertNil(archive.store.photo(path: receipt.photoPaths[0]))
        XCTAssertTrue(makeArchive(repo).receipts.isEmpty, "Auch nach Neustart leer")
    }
}
