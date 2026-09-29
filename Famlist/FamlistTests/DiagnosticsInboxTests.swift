/*
 DiagnosticsInboxTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Absturzberichte offline zuerst: sichern, der Reihe nach senden, bei Fehler liegen lassen, dauerhaft
   abgelehnte verwerfen, höchstens `maxPending` behalten, übersteht einen Neustart (neue Inbox, gleicher Ordner).

 📝 Last Change:
 - Initial creation (Absturzberichte, Migration 032).
 ------------------------------------------------------------------------
 */

import XCTest
@testable import Famlist

private actor FakeDiagnosticsRepository: DiagnosticsRepository {
    var uploaded: [UUID] = []
    var failWith: Error?
    var rejectIds: Set<UUID> = []

    func setFailure(_ error: Error?) { failWith = error }
    func reject(_ id: UUID) { rejectIds.insert(id) }

    func upload(_ report: PendingDiagnostic) async throws {
        if let failWith { throw failWith }
        if rejectIds.contains(report.id) { throw DiagnosticsUploadError.rejected }
        uploaded.append(report.id)
    }
}

final class DiagnosticsInboxTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("DiagnosticsInboxTests-\(UUID())")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    private func report(_ secondsAgo: TimeInterval, kinds: [String] = ["crash"]) -> PendingDiagnostic {
        PendingDiagnostic(id: UUID(), receivedAt: Date().addingTimeInterval(-secondsAgo), appVersion: "1.0 (2)",
                          kinds: kinds, payload: Data(#"{"crashDiagnostics":[]}"#.utf8))
    }

    func testSaveSurvivesRestartAndKeepsContent() async throws {
        let original = report(10, kinds: ["crash", "hang"])
        try await DiagnosticsInbox(directory: directory).save(original)
        let pending = await DiagnosticsInbox(directory: directory).pending()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, original.id)
        XCTAssertEqual(pending.first?.kinds, ["crash", "hang"])
        XCTAssertEqual(pending.first?.payload, original.payload)
    }

    func testFlushSendsOldestFirstAndDeletes() async throws {
        let inbox = DiagnosticsInbox(directory: directory)
        let newer = report(1), older = report(60)
        try await inbox.save(newer)
        try await inbox.save(older)
        let repo = FakeDiagnosticsRepository()
        let sent = await inbox.flush(using: repo)
        XCTAssertEqual(sent, 2)
        let uploaded = await repo.uploaded
        XCTAssertEqual(uploaded, [older.id, newer.id])
        let remaining = await inbox.pending()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testFlushKeepsReportsWhenOfflineAndSendsLater() async throws {
        let inbox = DiagnosticsInbox(directory: directory)
        try await inbox.save(report(5))
        let repo = FakeDiagnosticsRepository()
        await repo.setFailure(URLError(.notConnectedToInternet))
        let sentOffline = await inbox.flush(using: repo)
        XCTAssertEqual(sentOffline, 0)
        let stillPending = await inbox.pending()
        XCTAssertEqual(stillPending.count, 1)

        await repo.setFailure(nil)
        let sentOnline = await inbox.flush(using: repo)
        XCTAssertEqual(sentOnline, 1)
        let remaining = await inbox.pending()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testRejectedReportIsDroppedAndDoesNotBlockOthers() async throws {
        let inbox = DiagnosticsInbox(directory: directory)
        let bad = report(60), good = report(1)
        try await inbox.save(bad)
        try await inbox.save(good)
        let repo = FakeDiagnosticsRepository()
        await repo.reject(bad.id)
        let sent = await inbox.flush(using: repo)
        XCTAssertEqual(sent, 1)
        let uploaded = await repo.uploaded
        XCTAssertEqual(uploaded, [good.id])
        let remaining = await inbox.pending()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testKeepsOnlyNewestMaxPending() async throws {
        let inbox = DiagnosticsInbox(directory: directory)
        let total = DiagnosticsInbox.maxPending + 3
        var saved: [PendingDiagnostic] = []
        for index in 0..<total {
            let next = report(TimeInterval(total - index))
            saved.append(next)
            try await inbox.save(next)
        }
        let pending = await inbox.pending()
        XCTAssertEqual(pending.count, DiagnosticsInbox.maxPending)
        XCTAssertEqual(pending.map(\.id), saved.suffix(DiagnosticsInbox.maxPending).map(\.id))
    }

    func testUnreadableFileIsRemoved() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let junk = directory.appendingPathComponent("\(UUID().uuidString).json")
        try Data("kaputt".utf8).write(to: junk)
        let pending = await DiagnosticsInbox(directory: directory).pending()
        XCTAssertTrue(pending.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: junk.path))
    }
}
