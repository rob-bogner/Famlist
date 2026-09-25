/*
 InviteLink.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Baut den Einladungslink `famlist://invite?token=…&listTitle=…`.
 - Der Token kommt von der RPC create_list_invite (Migration 014): zufällig, 14 Tage gültig,
   widerrufen, sobald der Besitzer ein Mitglied entfernt.

 🔰 Notes for Beginners:
 - Deep Link statt Universal Link (Roberts Entscheidung F3: keine eigene Domain).
   Das Format liest AppSessionViewModel.handleOpenURL.

 📝 Last Change:
 - Token statt Listen-ID (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

enum InviteLink {
    static func url(token: String, listTitle: String) -> URL? {
        var c = URLComponents()
        c.scheme = "famlist"
        c.host = "invite"
        c.queryItems = [URLQueryItem(name: "token", value: token),
                        URLQueryItem(name: "listTitle", value: listTitle)]
        return c.url
    }
}
