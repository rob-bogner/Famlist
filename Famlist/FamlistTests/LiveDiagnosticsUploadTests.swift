/*
 LiveDiagnosticsUploadTests.swift
 FamlistTests
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Live-Test gegen das echte Supabase-Projekt: SupabaseDiagnosticsRepository legt einen Absturzbericht in
   diagnostic_reports an (Migration 032), doppeltes Senden ist harmlos, ungültige Daten gelten als abgelehnt,
   ohne Anmeldung lehnt der Server ab (Bericht bleibt dann auf dem Gerät liegen).

 🔰 Notes for Beginners:
 - Läuft nur mit `TEST_RUNNER_FAMLIST_LIVE=1 xcodebuild test … -only-testing:FamlistTests/LiveDiagnosticsUploadTests`.
 - Die App darf die Tabelle nicht lesen; die Testzeilen tragen app_version „live-test“ und werden mit
   Service-Rechten gelöscht (`delete from diagnostic_reports where app_version = 'live-test'`).

 📝 Last Change:
 - Initial creation (Absturzberichte).
 ------------------------------------------------------------------------
 */

#if DEBUG && targetEnvironment(simulator)
import XCTest
import Supabase
@testable import Famlist

final class LiveDiagnosticsUploadTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FAMLIST_LIVE"] == "1", "nur mit TEST_RUNNER_FAMLIST_LIVE=1")
    }

    private func client(signedIn: Bool) async throws -> SupabaseClient {
        let config = try XCTUnwrap(SupabaseConfigLoader.load(), "Supabase-Konfiguration fehlt")
        let client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey,
                                    options: .init(auth: .init(storage: MemoryAuthStorage()),
                                                   global: .init(session: AppSupabaseClient.uncachedSession)))
        if signedIn {
            let credentials = SimulatorAuthHelper.getCredentials(for: .tester)
            _ = try await client.auth.signIn(email: credentials.email, password: credentials.password)
        }
        return client
    }

    private func report(payload: String) -> PendingDiagnostic {
        PendingDiagnostic(id: UUID(), receivedAt: Date(), appVersion: "live-test", kinds: ["crash"],
                          payload: Data(payload.utf8))
    }

    private static let samplePayload = #"""
    {"timeStampBegin":"2026-09-29 21:00:00","timeStampEnd":"2026-09-29 21:10:00",
     "crashDiagnostics":[{"diagnosticMetaData":{"exceptionType":10,"signal":9,
       "terminationReason":"Namespace FRONTBOARD, Code 0x8badf00d"},"callStackTree":{"callStacks":[]}}]}
    """#

    func test_upload_createsReport_andDuplicateIsHarmless() async throws {
        let repository = SupabaseDiagnosticsRepository(client: LiveTestClient(try await client(signedIn: true)))
        let sample = report(payload: Self.samplePayload)
        try await repository.upload(sample)
        try await repository.upload(sample) // Antwort verloren → nochmal senden: 23505 gilt als erledigt.
    }

    func test_upload_invalidPayload_isRejected() async throws {
        let repository = SupabaseDiagnosticsRepository(client: LiveTestClient(try await client(signedIn: true)))
        do {
            try await repository.upload(report(payload: "kein JSON"))
            XCTFail("ungültiges JSON muss abgelehnt werden")
        } catch DiagnosticsUploadError.rejected {}
    }

    func test_upload_withoutSignIn_failsTemporarily() async throws {
        let repository = SupabaseDiagnosticsRepository(client: LiveTestClient(try await client(signedIn: false)))
        do {
            try await repository.upload(report(payload: Self.samplePayload))
            XCTFail("ohne Anmeldung darf der Server nichts annehmen")
        } catch DiagnosticsUploadError.rejected {
            XCTFail("ohne Anmeldung ist kein dauerhafter Fehler – der Bericht muss liegen bleiben")
        } catch {}
    }
}
#endif
