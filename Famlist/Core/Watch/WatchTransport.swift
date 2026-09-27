/*
 WatchTransport.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Schnittstelle zum Gegenüber (iPhone ↔ Uhr). Umsetzung: WatchConnectivityService (WCSession);
   in Tests ein Spion, der Nachrichten mitschreibt.

 🔰 Notes for Beginners:
 - send: sofort, nur wenn das Gegenüber erreichbar ist (sendMessage). Von der Uhr aus weckt das die
   iPhone-App im Hintergrund.
 - transfer: garantiert und in Reihenfolge, auch später (transferUserInfo) – für Abmelden.
 - updateContext: letzter Stand, ersetzt den vorigen (updateApplicationContext).

 📝 Last Change:
 - Initial creation (Watch-Plan Phase 4).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
protocol WatchTransport: AnyObject {
    /// Gegenüber jetzt per sendMessage erreichbar.
    var isReachable: Bool { get }
    /// Zuletzt vom Gegenüber empfangener Kontext (nil = noch keiner).
    var receivedContext: WatchApplicationContext? { get }
    /// Sofort senden; `reply` erhält die Antwort des Gegenübers (nil = keine Antwort erwartet).
    func send(_ message: WatchMessage, reply: (@MainActor (Result<WatchMessage, Error>) -> Void)?)
    /// Garantiert zustellen (Warteschlange des Systems).
    func transfer(_ message: WatchMessage)
    /// Letzten Stand für das Gegenüber setzen.
    func updateContext(_ context: WatchApplicationContext)
}

/// Empfänger der Nachrichten des Gegenübers (auf dem Main Actor).
@MainActor
protocol WatchTransportDelegate: AnyObject {
    /// Nachricht (sendMessage oder transferUserInfo). Rückgabe = Antwort, falls eine erwartet wird.
    func transport(didReceive message: WatchMessage) async -> WatchMessage?
    /// Neuer Kontext des Gegenübers.
    func transport(didReceiveContext context: WatchApplicationContext)
    /// Erreichbarkeit hat sich geändert.
    func transportReachabilityChanged(_ isReachable: Bool)
}
