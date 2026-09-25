/*
 ItemUpsertResult.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Antwort der RPC upsert_items_lww (Migration 015) für EINEN Artikel.

 🔰 Notes for Beginners:
 - applied: Der Server hat unseren Stand übernommen.
 - stale:   Der Server hatte schon einen neueren (oder denselben) Stand; `item` ist dieser Stand.
 - denied:  Kein Zugriff (z. B. aus der Liste entfernt). Erneutes Senden hilft nicht.
 - invalid: Ungültige Daten (z. B. Uhr weit in der Zukunft). Erneutes Senden hilft nicht.
 - `item` enthält nie das Foto (`imagedata`), damit die Antwort klein bleibt.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Sync-Kern).
 ------------------------------------------------------------------------
 */

import Foundation

struct ItemUpsertResult: Equatable {
    enum Status: String {
        case applied
        case stale
        case denied
        case invalid
    }

    let id: String
    let status: Status
    /// Gültige Server-Zeile (ohne Foto); nil bei denied/invalid.
    let item: ItemModel?
    /// Fehlertext des Servers bei `invalid`.
    let message: String?
}

/// Auftrag an upsert_items_lww: voller Artikelstand samt HLC und Löschmarkierung.
/// Eng mit ItemUpsertResult verbunden, daher in derselben Datei.
struct ItemUpsertRequest: Equatable {
    let item: ItemModel
    /// false = Foto nicht mitsenden (unverändert); der Server behält sein gespeichertes Foto.
    let includeImage: Bool
}
