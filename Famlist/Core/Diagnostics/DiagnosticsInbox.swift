/*
 DiagnosticsInbox.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Offline-Zwischenspeicher für Absturz- und Hängerberichte: erst als Datei sichern, dann senden.

 🔰 Notes for Beginners:
 - Jeder Bericht ist eine JSON-Datei in „Application Support/Diagnostics“. So geht er nicht verloren, wenn beim
   Eintreffen kein Netz da ist oder niemand angemeldet ist.
 - `flush` sendet der Reihe nach (älteste zuerst) und löscht jede Datei erst nach Erfolg. Beim ersten Fehler
   hört es auf; der nächste Anlass (Netz zurück, Anmeldung, neuer Bericht) versucht es wieder. Lehnt der Server
   einen Bericht dauerhaft ab (`DiagnosticsUploadError.rejected`), wird nur dieser verworfen.
 - Höchstens `maxPending` Berichte bleiben liegen; ältere fallen weg, damit der Speicher nicht wächst.

 📝 Last Change:
 - Initial creation (Absturzberichte, Migration 032).
 ------------------------------------------------------------------------
 */

import Foundation

actor DiagnosticsInbox {
    static let maxPending = 20

    private let directory: URL
    private var isFlushing = false

    init(directory: URL = DiagnosticsInbox.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Diagnostics", isDirectory: true)
    }

    /// Sichert den Bericht als Datei und kürzt die Warteschlange auf `maxPending`.
    func save(_ report: PendingDiagnostic) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: fileURL(for: report.id), options: .atomic)
        let overflow = pending().dropLast(Self.maxPending)
        overflow.forEach { remove($0.id) }
    }

    /// Alle wartenden Berichte, älteste zuerst. Unlesbare Dateien werden entfernt.
    func pending() -> [PendingDiagnostic] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var reports: [PendingDiagnostic] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file), let report = try? decoder.decode(PendingDiagnostic.self, from: data) {
                reports.append(report)
            } else {
                try? FileManager.default.removeItem(at: file)
            }
        }
        return reports.sorted { $0.receivedAt < $1.receivedAt }
    }

    /// Sendet die wartenden Berichte. Gibt die Zahl der erledigten Berichte zurück.
    @discardableResult
    func flush(using repository: DiagnosticsRepository) async -> Int {
        guard !isFlushing else { return 0 }
        isFlushing = true
        defer { isFlushing = false }
        var sent = 0
        for report in pending() {
            do {
                try await repository.upload(report)
                remove(report.id)
                sent += 1
            } catch DiagnosticsUploadError.rejected {
                logVoid(params: (action: "diagnostics.flush.dropped", id: report.id))
                remove(report.id)
            } catch {
                logVoid(params: (action: "diagnostics.flush.deferred", id: report.id,
                                 error: (error as NSError).localizedDescription))
                break
            }
        }
        return sent
    }

    private func remove(_ id: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: id))
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }
}
