/*
 InviteLink.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Baut den Einladungslink `famlist://invite?listId=…&inviterPublicId=…&listTitle=…`.

 🔰 Notes for Beginners:
 - Deep Link statt Universal Link (Roberts Entscheidung F3: keine eigene Domain).
   Das Format liest AppSessionViewModel.handleOpenURL.

 📝 Last Change:
 - Aus ShareListView ausgelagert (Redesign „Hybrid“, Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

enum InviteLink {
    static func url(listId: UUID, listTitle: String, inviterPublicId: String) -> URL? {
        var c = URLComponents()
        c.scheme = "famlist"
        c.host = "invite"
        c.queryItems = [URLQueryItem(name: "listId", value: listId.uuidString),
                        URLQueryItem(name: "inviterPublicId", value: inviterPublicId),
                        URLQueryItem(name: "listTitle", value: listTitle)]
        return c.url
    }
}
