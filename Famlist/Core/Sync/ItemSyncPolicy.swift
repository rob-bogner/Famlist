/*
 ItemSyncPolicy.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Die EINE Konfliktregel für Artikel: Last-Writer-Wins über die ganze Zeile nach HLC.
   Dieselbe Regel erzwingt der Server (Trigger items_lww_guard, Migration 015). Nur wenn App
   und Server gleich entscheiden, landen alle Geräte beim selben Stand.

 🔰 Notes for Beginners:
 - HLC = Hybrid Logical Clock: (Zeitstempel, Zähler, Geräte-ID). Größer = neuer.
 - Eine Löschung ist nur ein Feld (`tombstone`). Sie gewinnt, wenn sie neuer ist – und verliert,
   wenn jemand den Artikel danach neu anlegt (neuere HLC). Kein Sonderfall „Löschen gewinnt immer“.
 - Gleiche HLC = dieselbe Schreib-Operation (z. B. das Echo der eigenen Änderung) → nichts tun.

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Sync-Kern).
 ------------------------------------------------------------------------
 */

import Foundation

enum ItemSyncPolicy {
    enum Decision: Equatable {
        /// Lokal unbekannt → übernehmen.
        case insert
        /// Server/anderes Gerät ist neuer → lokale Zeile überschreiben.
        case applyRemote
        /// Lokal ist neuer oder identisch → Remote verwerfen.
        case keepLocal
    }

    static func decide(local: HybridLogicalClock?, remote: HybridLogicalClock) -> Decision {
        guard let local else { return .insert }
        return local < remote ? .applyRemote : .keepLocal
    }
}

extension ItemModel {
    /// HLC dieses Artikels; fehlende Werte zählen als Epoche 0.
    var hlc: HybridLogicalClock {
        HybridLogicalClock(timestamp: hlcTimestamp ?? 0, counter: hlcCounter ?? 0, nodeId: hlcNodeId ?? "")
    }
}
