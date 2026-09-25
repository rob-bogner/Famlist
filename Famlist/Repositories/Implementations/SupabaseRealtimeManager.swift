/*
 SupabaseRealtimeManager.swift
 Famlist
 Created on: 18.10.2025
 Last updated on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Verwaltet den Realtime-Kanal je Liste: privater Broadcast-Kanal `list:<list_id>` (Migration 017).

 🛠 Includes:
 - Anmelden am Kanal mit Wiederholung (wachsende Wartezeit), Abmelden beim Verlassen der Liste.
 - Umwandeln der Broadcast-Nachricht „item_change“ in RealtimeEvent (insert/update/delete).
 - Meldung „wieder verbunden“, damit die Liste Verpasstes per Delta-Abgleich nachholt.

 🔰 Notes for Beginners:
 - Broadcast statt Postgres Changes: Supabase empfiehlt Broadcast für Skalierung; Postgres Changes
   verarbeitet alle Änderungen auf einem Thread und prüft jeden Abonnenten einzeln.
 - Der Kanal ist privat: Lesen darf nur, wer Zugriff auf die Liste hat (Policy list_topic_read).
 - Nachrichten können bei einem Verbindungsabbruch fehlen. Deshalb löst jede Wiederverbindung einen
   Delta-Abgleich aus; doppelte Nachrichten sind harmlos (HLC-Regel).

 📝 Last Change:
 - Auf privaten Broadcast umgestellt, Wiederholung und Wiederverbindungs-Meldung (Audit 25.09.2026).
 ------------------------------------------------------------------------
*/

import Foundation
import Supabase

/// Realtime event types with their payloads
enum RealtimeEvent {
    case insert(payload: [String: Any])
    case update(payload: [String: Any])
    case delete(payload: [String: Any])
}

/// Manages Realtime channel lifecycle and streams for a specific list.
@MainActor
final class SupabaseRealtimeManager {

    /// Ereignisname der Trigger-Nachricht (Migration 017).
    nonisolated static let itemChangeEvent = "item_change"
    /// Obergrenze der Wartezeit zwischen Anmeldeversuchen.
    nonisolated static let maxRetryDelay: TimeInterval = 30

    private let client: SupabaseClienting

    /// Laufende Beobachtung je Liste (Kanal + Aufgabe), damit sie beim Verlassen beendet werden kann.
    private var sessions: [UUID: Task<Void, Never>] = [:]
    private var channels: [UUID: RealtimeChannelV2] = [:]

    init(client: SupabaseClienting) {
        self.client = client
    }

    /// Kanalname für eine Liste.
    nonisolated static func topic(for listId: UUID) -> String {
        "list:\(listId.uuidString.lowercased())"
    }

    /// Startet die Beobachtung einer Liste.
    /// - Parameters:
    ///   - onEvent: Jede Artikeländerung.
    ///   - onResubscribed: Nach einer Wiederverbindung (nicht beim ersten Anmelden) – Verpasstes nachholen.
    func setupRealtimeChannel(
        for listId: UUID,
        onEvent: @escaping @MainActor @Sendable (RealtimeEvent) async -> Void,
        onResubscribed: @escaping @MainActor @Sendable () async -> Void = {}
    ) async {
        teardownRealtimeChannel(for: listId)
        let channel = client.realtime.channel(Self.topic(for: listId)) { $0.isPrivate = true }
        channels[listId] = channel
        let changes = channel.broadcastStream(event: Self.itemChangeEvent)
        let statuses = channel.statusChange

        sessions[listId] = Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                // Beide Aufgaben rufen Main-Actor-Funktionen auf; übergeben werden nur Sendable-Werte.
                group.addTask { await Self.forward(changes, to: onEvent) }
                group.addTask {
                    await Self.keepSubscribed(channel, statuses: statuses, listId: listId, onResubscribed: onResubscribed)
                }
                await group.waitForAll()
            }
        }
    }

    /// Reicht jede Artikeländerung des Kanals an `onEvent` weiter (auf dem Main Actor).
    private static func forward(_ changes: AsyncStream<JSONObject>,
                                to onEvent: @escaping @MainActor @Sendable (RealtimeEvent) async -> Void) async {
        for await message in changes {
            if let event = Self.event(from: message) { await onEvent(event) }
        }
    }

    /// Meldet an und hält die Verbindung: Nach jedem erneuten „subscribed“ wird Verpasstes nachgeholt;
    /// scheitert das Anmelden, wird mit wachsender Wartezeit erneut versucht.
    private static func keepSubscribed(_ channel: RealtimeChannelV2, statuses: AsyncStream<RealtimeChannelStatus>,
                                       listId: UUID, onResubscribed: @escaping @MainActor @Sendable () async -> Void) async {
        var delay: TimeInterval = 1
        while !Task.isCancelled {
            do {
                try await channel.subscribeWithError()
                logVoid(params: (action: "realtime.subscribed", listId: listId))
                break
            } catch {
                logVoid(params: (action: "realtime.subscribeError", listId: listId, retryIn: delay,
                                 error: String(describing: error)))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * 2, maxRetryDelay)
            }
        }
        var wasSubscribed = true
        for await status in statuses {
            guard !Task.isCancelled else { return }
            if status == .subscribed {
                if !wasSubscribed {
                    logVoid(params: (action: "realtime.resubscribed", listId: listId))
                    await onResubscribed()
                }
                wasSubscribed = true
            } else if status == .unsubscribed {
                wasSubscribed = false
            }
        }
    }

    /// Wandelt eine Broadcast-Nachricht in ein RealtimeEvent (nil = unbekanntes Format).
    nonisolated static func event(from message: JSONObject) -> RealtimeEvent? {
        let body = message["payload"]?.objectValue ?? message
        guard let operation = body["operation"]?.stringValue else { return nil }
        switch operation {
        case "INSERT", "UPDATE":
            guard let record = body["record"]?.objectValue else { return nil }
            let payload: [String: Any] = ["record": bridge(record)]
            return operation == "INSERT" ? .insert(payload: payload) : .update(payload: payload)
        case "DELETE":
            guard let old = body["old_record"]?.objectValue else { return nil }
            return .delete(payload: ["old_record": bridge(old)])
        default:
            return nil
        }
    }

    // MARK: - AnyJSON Bridge

    /// Converts a [String: AnyJSON] record into a [String: Any] dictionary with native Swift values,
    /// so that downstream `as? Int` / `as? Double` casts work.
    nonisolated static func bridge(_ record: [String: AnyJSON]) -> [String: Any] {
        guard
            let data = try? JSONEncoder().encode(record),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return record.mapValues { $0 as Any }
        }
        return dict
    }

    /// Tears down the Realtime channel for a specific list.
    /// Das SDK verwaltet Kanäle nach Namen: Wird die Liste sofort wieder geöffnet, liefert es dasselbe
    /// Kanal-Objekt zurück. Dann darf das verzögerte Entfernen es nicht mehr abmelden.
    func teardownRealtimeChannel(for listId: UUID) {
        sessions[listId]?.cancel()
        sessions.removeValue(forKey: listId)
        guard let channel = channels.removeValue(forKey: listId) else { return }
        let realtime = client.realtime
        Task { @MainActor [weak self] in
            if let current = self?.channels[listId], current === channel { return }   // wiederverwendet
            await realtime.removeChannel(channel)
        }
        logVoid(params: (listId: listId, action: "teardownRealtimeChannel"))
    }
}
