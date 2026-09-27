/*
 AccountRepository.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zugriff auf den Archivzustand des eigenen Kontos und auf archivierte Mitglieder (Migrationen 027/028).

 🔰 Notes for Beginners:
 - Eigenes Protokoll statt Erweiterung von ProfilesRepository: So bleiben die bestehenden Test-Doubles unverändert.
 - status() liefert nil, wenn das Konto aktiv ist.
 - purge() ruft die Edge Function purge-my-account auf; sie löscht sofort alles (auch Fotos).
 - Alle Aufrufe brauchen Netz; ohne Verbindung werfen sie einen Fehler.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

protocol AccountRepository: Sendable {
    /// Archivzustand des angemeldeten Kontos, nil = aktiv.
    func status() async throws -> AccountArchiveStatus?
    /// Stellt das archivierte Konto wieder her. false = war nicht archiviert.
    func restore() async throws -> Bool
    /// Löscht das archivierte Konto sofort endgültig (inkl. Fotos).
    func purge() async throws
    /// Archivierte Mitglieder einer eigenen Liste (nur Besitzer).
    func archivedMembers(listId: UUID) async throws -> [ArchivedListMember]
    /// Entfernt ein archiviertes Mitglied endgültig aus der Liste (nur Besitzer).
    func removeArchivedMember(listId: UUID, profileId: UUID) async throws
    /// Noch nicht gezeigte Hinweise („Mitglied hat sein Konto gelöscht“).
    func unseenNotices() async throws -> [AccountNotice]
    /// Hinweis als gezeigt markieren.
    func markNoticeSeen(_ id: UUID) async throws
}
