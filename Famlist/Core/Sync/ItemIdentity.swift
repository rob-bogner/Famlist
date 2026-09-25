/*
 ItemIdentity.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Bestimmt die ID eines NEUEN Artikels.

 🔰 Notes for Beginners:
 - Standard: deterministische ID aus (Liste, Name) – zwei Geräte, die gleichzeitig „Milch“ anlegen,
   erzeugen denselben Datensatz statt eines Duplikats (ADR-005, FAM-50).
 - Ausnahme: Lebt unter dieser ID bereits ein Artikel mit ANDEREM Namen (Altbestand aus der Zeit,
   als Umbenennen die ID behielt), bekommt der neue Artikel eine zufällige ID. Sonst würde
   „Milch hinzufügen“ die umbenannte „Hafermilch“ überschreiben (Audit H3).

 📝 Last Change:
 - Initial creation (Audit 25.09.2026, Sync-Kern).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
enum ItemIdentity {
    /// - Parameter fallback: ID, die der Aufrufer bei einer Kollision schon vergeben hat (z. B. für die
    ///   sofortige Anzeige). Dann behalten beide Seiten dieselbe ID.
    static func newItemId(name: String, listId: UUID, store: SwiftDataItemStore, fallback: UUID? = nil) -> UUID {
        let deterministic = UUID.deterministicItemID(listId: listId, name: name)
        guard let existing = try? store.fetchItem(id: deterministic),
              existing.tombstone != true,
              normalizedKey(existing.name) != normalizedKey(name) else {
            return deterministic
        }
        if let fallback, fallback != deterministic { return fallback }
        return UUID()
    }

    /// Vergleichsschlüssel für Namen – dieselbe Normalisierung wie `UUID.deterministicItemID`.
    nonisolated static func normalizedKey(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }
}
