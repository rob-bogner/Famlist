/*
 PendingDiagnostic.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ein Diagnosebericht von iOS (MetricKit), der auf dem Gerät auf das Senden wartet.

 🔰 Notes for Beginners:
 - `payload` ist das JSON aus `MXDiagnosticPayload.jsonRepresentation()` (Absturz, Hänger, …) – unverändert.
 - `kinds` fasst zusammen, was drinsteht („crash“, „hang“, „cpu“, „diskWrite“, „launch“), damit man in der
   Datenbank filtern kann, ohne das JSON zu öffnen.

 📝 Last Change:
 - Initial creation (Absturzberichte, Migration 032).
 ------------------------------------------------------------------------
 */

import Foundation

struct PendingDiagnostic: Codable, Equatable, Sendable {
    let id: UUID
    let receivedAt: Date
    let appVersion: String
    let kinds: [String]
    let payload: Data

    /// App-Version wie im Absturzbericht von iOS: „1.0 (2)“.
    static var currentAppVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
