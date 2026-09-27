/*
 ArchivedListMember.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Mitglied einer eigenen Liste, das sein Konto gelöscht hat und noch wiederherstellen kann
   (RPC archived_list_members, Migration 027).

 🔰 Notes for Beginners:
 - Der Besitzer sieht diese Person in „Mitglieder & Teilen“ ausgegraut bis zum Datum purgeAfter.
 - Stellt die Person ihr Konto wieder her, ist sie automatisch wieder Mitglied – außer der Besitzer hat sie entfernt.

 📝 Last Change:
 - Initial creation (Konto-Archiv, Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

struct ArchivedListMember: Identifiable, Hashable, Sendable {
    /// profile_id des Mitglieds.
    let id: UUID
    let name: String
    let purgeAfter: Date
}
