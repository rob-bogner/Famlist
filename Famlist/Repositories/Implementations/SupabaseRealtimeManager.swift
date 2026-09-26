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

    /// Wird der Manager freigegeben, enden seine Sitzungen. Sonst hielten sich die Aufgaben selbst am Leben und
    /// meldeten Kanäle (auch gelöschter Listen) immer wieder an – in Tests beobachtet (Audit 2).
    deinit {
        for task in sessions.values { task.cancel() }
    }

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
    ///   - onResubscribed: Nach jeder erfolgreichen Anmeldung (auch der ersten) – Verpasstes nachholen.
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

    /// Meldet an und hält die Verbindung. Nach JEDER erfolgreichen Anmeldung wird Verpasstes nachgeholt:
    /// - beim ersten Mal, weil das Start-Nachladen oft fertig ist, bevor der Kanal steht (Audit 2, Befund S2);
    /// - nach jeder Wiederverbindung. Das SDK meldet den Kanal nach einem Abbruch selbst wieder an und
    ///   springt dabei von „subscribing“ direkt auf „subscribed“ – vorher wartete die App auf
    ///   „unsubscribed“ und holte deshalb nie nach (Audit 2, Befund S1).
    /// Bleibt der Kanal „unsubscribed“ (das SDK gibt auf), meldet die App ihn selbst neu an.
    private static func keepSubscribed(_ channel: RealtimeChannelV2, statuses: AsyncStream<RealtimeChannelStatus>,
                                       listId: UUID, onResubscribed: @escaping @MainActor @Sendable () async -> Void) async {
        await subscribeWithRetry(channel, listId: listId)
        guard !Task.isCancelled else { return }
        await onResubscribed()
        var wasSubscribed = true
        for await status in statuses {
            guard !Task.isCancelled else { return }
            switch status {
            case .subscribed:
                if !wasSubscribed {
                    logVoid(params: (action: "realtime.resubscribed", listId: listId))
                    await onResubscribed()
                }
                wasSubscribed = true
            case .unsubscribed:
                wasSubscribed = false
                await resubscribeIfAbandoned(channel, listId: listId)
            case .subscribing, .unsubscribing:
                wasSubscribed = false
            }
        }
    }

    /// Anmelden mit wachsender Wartezeit (1 s … maxRetryDelay), bis es klappt oder die Beobachtung endet.
    static func subscribeWithRetry(_ channel: RealtimeChannelV2, listId: UUID?) async {
        var delay: TimeInterval = 1
        while !Task.isCancelled {
            do {
                try await channel.subscribeWithError()
                logVoid(params: (action: "realtime.subscribed", listId: listId as Any))
                return
            } catch {
                logVoid(params: (action: "realtime.subscribeError", listId: listId as Any, retryIn: delay,
                                 error: String(describing: error)))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * 2, maxRetryDelay)
            }
        }
    }

    /// Gibt dem SDK 5 s für die eigene Neuanmeldung; steht der Kanal danach noch auf „unsubscribed“,
    /// meldet die App ihn selbst an. Beim Schließen der Liste ist die Aufgabe abgebrochen → nichts tun.
    private static func resubscribeIfAbandoned(_ channel: RealtimeChannelV2, listId: UUID) async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled, channel.status == .unsubscribed else { return }
        logVoid(params: (action: "realtime.resubscribeAbandoned", listId: listId))
        await subscribeWithRetry(channel, listId: listId)
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
