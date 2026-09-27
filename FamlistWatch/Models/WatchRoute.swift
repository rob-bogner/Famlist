/*
 WatchRoute.swift
 FamlistWatch
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ziele der Navigation: Wurzel „Listen“ → aktive Liste → Artikel bzw. Hinzufügen.

 🔰 Notes for Beginners:
 - Beim Start liegt die aktive Liste schon auf dem Stapel; der Titel oben links führt zurück zu „Listen“.
 - Deep Links der Komplikationen: famlist://watch/list → [.list], famlist://watch/add → [.list, .add].

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 5).
 ------------------------------------------------------------------------
 */

import Foundation

enum WatchRoute: Hashable {
    case list
    case item(String)
    case add

    /// Navigationsstapel für einen Deep Link (nil = unbekannter Link).
    static func path(for url: URL) -> [WatchRoute]? {
        guard url.scheme == "famlist", url.host == "watch" else { return nil }
        switch url.path {
        case "/list": return [.list]
        case "/add": return [.list, .add]
        default: return nil
        }
    }
}
