/*
 ReceiptArchiveSetting.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einstellung „Fotos der Bons speichern“ (Einstellungen → Kassenzettel) und Formatierung der Größe.

 🔰 Notes for Beginners:
 - Gespeichert per @AppStorage (UserDefaults) unter `storageKey`; Standard ist „an“ (KASSENZETTEL_ARCHIV.md).
 - Aus → beim „Preise speichern“ entsteht kein Archiv-Eintrag, weder lokal noch auf dem Server.
   Die Preise werden trotzdem gespeichert.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptArchiveSetting {
    static let storageKey = "receipts.savePhotos"
    static let defaultValue = true

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: storageKey) as? Bool ?? defaultValue
    }

    /// „12 Bons · 38 MB“ (Einstellungen) – „1 Bon“ in der Einzahl.
    static func summary(count: Int, bytes: Int) -> String {
        "\(count) \(count == 1 ? "Bon" : "Bons") · \(size(bytes))"
    }

    /// Dezimale Einheiten wie das System („38 MB“, „820 kB“); deutsches Komma.
    static func size(_ bytes: Int) -> String {
        Int64(bytes).formatted(.byteCount(style: .file, allowedUnits: [.kb, .mb, .gb])
            .locale(Locale(identifier: "de_DE")))
    }
}
