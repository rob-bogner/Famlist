/*
 ListMember.swift

 Famlist
 Created on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - DTO für Listenmitglieder (Kollaboratoren). Wird von MembersView und fetchMembers verwendet.

 📝 Last Change:
 - FAM-21: Initial creation for List Sharing feature.
 ------------------------------------------------------------------------
 */

import Foundation

/// Repräsentiert ein Mitglied (Kollaborator) einer geteilten Liste.
struct ListMember: Identifiable, Hashable {
    /// profile_id — entspricht auth.uid() des Mitglieds.
    let id: UUID
    let publicId: String
    let username: String?
    let fullName: String?
    /// Entspricht der `added_at`-Spalte in list_members.
    let addedAt: Date

    /// Zeigt fullName, username oder publicId — in dieser Priorität.
    var displayName: String { fullName ?? username ?? publicId }
}
