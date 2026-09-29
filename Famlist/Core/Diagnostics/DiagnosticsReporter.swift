/*
 DiagnosticsReporter.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Empfängt Absturz- und Hängerberichte von iOS (MetricKit), sichert sie in DiagnosticsInbox und sendet sie
   an Supabase (diagnostic_reports, Migration 032).

 🔰 Notes for Beginners:
 - iOS liefert Diagnoseberichte seit iOS 15 beim nächsten App-Start nach dem Ereignis (Apple-Doku MXMetricManager).
 - `didReceive` läuft auf einer beliebigen Warteschlange: Dort wird das Payload sofort in JSON umgewandelt
   (MXDiagnosticPayload ist nicht Sendable), danach übernimmt der Actor DiagnosticsInbox.
 - Gesendet wird bei Start, bei jedem neuen Bericht und wenn `retryTrigger` true meldet (Netz zurück, Anmeldung).
 - MetricKit gibt es nicht auf watchOS; die Uhr-App nutzt diese Datei nicht.

 📝 Last Change:
 - Initial creation (Anlass: Watchdog-Abbruch 29.09.2026 23:09, supabase-swift-Deadlock).
 ------------------------------------------------------------------------
 */

import Combine
import Foundation
import MetricKit

@MainActor
final class DiagnosticsReporter: NSObject, MXMetricManagerSubscriber {
    private let inbox: DiagnosticsInbox
    private let repository: DiagnosticsRepository
    private var retryCancellable: AnyCancellable?

    init(inbox: DiagnosticsInbox = DiagnosticsInbox(), repository: DiagnosticsRepository) {
        self.inbox = inbox
        self.repository = repository
        super.init()
    }

    /// Meldet sich bei MetricKit an und sendet liegengebliebene Berichte.
    func start(retryTrigger: AnyPublisher<Bool, Never>) {
        MXMetricManager.shared.add(self)
        retryCancellable = retryTrigger
            .filter { $0 }
            .sink { [weak self] _ in self?.flush() }
        flush()
    }

    func flush() {
        let inbox = inbox
        let repository = repository
        Task { await inbox.flush(using: repository) }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let reports = payloads.map(Self.makeReport)
        logVoid(params: (action: "diagnostics.received", count: reports.count, kinds: reports.map(\.kinds)))
        let inbox = inbox
        let repository = repository
        Task {
            for report in reports {
                do { try await inbox.save(report) } catch {
                    logVoid(params: (action: "diagnostics.save.error", error: (error as NSError).localizedDescription))
                }
            }
            await inbox.flush(using: repository)
        }
    }

    nonisolated private static func makeReport(_ payload: MXDiagnosticPayload) -> PendingDiagnostic {
        var kinds: [String] = []
        if payload.crashDiagnostics?.isEmpty == false { kinds.append("crash") }
        if payload.hangDiagnostics?.isEmpty == false { kinds.append("hang") }
        if payload.cpuExceptionDiagnostics?.isEmpty == false { kinds.append("cpu") }
        if payload.diskWriteExceptionDiagnostics?.isEmpty == false { kinds.append("diskWrite") }
        if #available(iOS 16.0, *), payload.appLaunchDiagnostics?.isEmpty == false { kinds.append("launch") }
        return PendingDiagnostic(id: UUID(), receivedAt: Date(), appVersion: PendingDiagnostic.currentAppVersion,
                                 kinds: kinds.isEmpty ? ["other"] : kinds, payload: payload.jsonRepresentation())
    }
}
