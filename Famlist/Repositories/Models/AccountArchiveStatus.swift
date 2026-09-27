/*
 AccountArchiveStatus.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Zustand eines gelöschten (archivierten) Kontos: wann gelöscht, wann endgültig weg (RPC my_account_status,
   Migration 027).

 🔰 Notes for Beginners:
 - „Konto löschen“ archiviert das Konto 60 Tage lang. Wer sich in dieser Zeit wieder anmeldet, sieht den Screen
   „Konto wiederherstellen“ (RestoreAccountView) mit diesen Daten.
 - Die Resttage zählen Kalendertage: am Tag der endgültigen Löschung steht dort 0.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation

struct AccountArchiveStatus: Equatable, Sendable {
    let archivedAt: Date
    let purgeAfter: Date

    /// Ganze Kalendertage bis zur endgültigen Löschung (nie negativ).
    func daysLeft(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: purgeAfter)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }
}
