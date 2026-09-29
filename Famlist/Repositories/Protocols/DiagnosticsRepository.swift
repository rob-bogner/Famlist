/*
 DiagnosticsRepository.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schnittstelle zum Hochladen von Absturz- und Hängerberichten (Tabelle diagnostic_reports, Migration 032).

 🔰 Notes for Beginners:
 - Nur Schreiben: Die App darf ihre Berichte anlegen, aber nicht lesen (RLS).

 📝 Last Change:
 - Initial creation (Absturzberichte).
 ------------------------------------------------------------------------
 */

import Foundation

protocol DiagnosticsRepository: Sendable {
    /// Legt den Bericht an. Wirft bei Netz-/Serverfehlern; ein schon vorhandener Bericht (gleiche ID) ist kein Fehler.
    /// Lehnt der Server den Bericht dauerhaft ab (ungültig, zu groß), wirft es `DiagnosticsUploadError.rejected`.
    func upload(_ report: PendingDiagnostic) async throws
}

/// Dauerhafte Ablehnung: Wiederholen hilft nicht, der Bericht wird verworfen.
enum DiagnosticsUploadError: Error, Equatable {
    case rejected
}
