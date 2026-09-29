/*
 SupabaseDiagnosticsRepository.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Supabase-Umsetzung von DiagnosticsRepository: schreibt in public.diagnostic_reports (Migration 032).

 🔰 Notes for Beginners:
 - profile_id setzt der Server selbst (default auth.uid()); ohne Anmeldung lehnt er ab → Bericht bleibt liegen.
 - Kein `select` nach dem Einfügen: Die Tabelle ist für die App nicht lesbar.
 - Doppeltes Senden (Antwort ging verloren) meldet 23505 und gilt als erledigt.

 📝 Last Change:
 - Initial creation (Absturzberichte).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

final class SupabaseDiagnosticsRepository: DiagnosticsRepository {
    let client: SupabaseClienting

    init(client: SupabaseClienting) {
        self.client = client
    }

    private struct Row: Encodable {
        let id: UUID
        let received_at: Date
        let app_version: String
        let kinds: [String]
        let payload: AnyJSON
    }

    func upload(_ report: PendingDiagnostic) async throws {
        guard let payload = try? JSONDecoder().decode(AnyJSON.self, from: report.payload) else {
            throw DiagnosticsUploadError.rejected
        }
        let row = Row(id: report.id, received_at: report.receivedAt, app_version: report.appVersion,
                      kinds: report.kinds, payload: payload)
        do {
            try await client.from("diagnostic_reports").insert(row).execute()
        } catch let error as PostgrestError where error.code == "23505" {
            logVoid(params: (action: "diagnostics.upload.alreadyExists", id: report.id))
        } catch let error as PostgrestError where Self.isInvalidData(error.code) {
            throw DiagnosticsUploadError.rejected
        }
    }

    /// Postgres-Fehlerklassen 22 (ungültige Daten) und 23 (Regel verletzt, z. B. Größe) – außer 23505 (schon da).
    private static func isInvalidData(_ code: String?) -> Bool {
        guard let code else { return false }
        return code.hasPrefix("22") || code.hasPrefix("23")
    }
}
