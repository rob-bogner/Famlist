/*
 ShareMember.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Eine Zeile in „Mitglieder & Teilen“: Name, Rolle („Besitzer“ / „Mitglied“), Initiale.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 4). Entspricht ListAccountMember im Referenzcode.
 ------------------------------------------------------------------------
 */

import Foundation

struct ShareMember: Identifiable, Hashable {
    let id: UUID
    let name: String
    let role: String
    let isOwner: Bool
    let isMe: Bool

    var initial: String { String(name.prefix(1)).uppercased() }
}
