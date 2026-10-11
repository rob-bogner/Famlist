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
 - keepChannelAlive: Kanal bei jedem Anmeldeversuch neu aus der SDK-Verwaltung holen; vorher blieb ein vom
   SDK ausgetragener Kanal bis zum Neustart taub (11.10.2026).
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
    /// So lange darf ein Kanal „unsubscribed“ bleiben, bevor die App einen frischen nimmt (das SDK meldet nach
    /// einem Verbindungsabbruch selbst wieder an und braucht dafür Zeit).
    nonisolated static let abandonedAfter: UInt64 = 5_000_000_000

    private let client: SupabaseClienting

    /// Laufende Beobachtung je Liste (Kanal + Aufgabe), damit sie beim Verlassen beendet werden kann.
    private var sessions: [UUID: Task<Void, Never>] = [:]
    private var channels: [UUID: RealtimeChannelV2] = [:]
    /// Rückrufe je Liste, damit ein Kanal neu aufgebaut werden kann (replaceUnregisteredChannels).
    private var handlers: [UUID: (onEvent: @MainActor @Sendable (RealtimeEvent) async -> Void,
                                  onResubscribed: @MainActor @Sendable () async -> Void)] = [:]

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
        handlers[listId] = (onEvent, onResubscribed)
        let realtime = client.realtime
        let topic = Self.topic(for: listId)
        sessions[listId] = Task { @MainActor [weak self] in
            await Self.keepChannelAlive(
                realtime: realtime, topic: topic, listId: listId,
                onChannel: { [weak self] channel in self?.channels[listId] = channel },
                listeners: { channel in
                    let changes = channel.broadcastStream(event: Self.itemChangeEvent)
                    return [{ await Self.forward(changes, to: onEvent) }]
                },
                onSubscribed: onResubscribed)
        }
    }

    /// Reicht jede Artikeländerung des Kanals an `onEvent` weiter (auf dem Main Actor).
    private static func forward(_ changes: AsyncStream<JSONObject>,
                                to onEvent: @escaping @MainActor @Sendable (RealtimeEvent) async -> Void) async {
        for await message in changes {
            if let event = Self.event(from: message) { await onEvent(event) }
        }
    }

    /// Hält einen privaten Kanal dauerhaft angemeldet, bis die Aufgabe abgebrochen wird.
    ///
    /// Jeder Durchlauf holt den Kanal NEU aus der Verwaltung des SDK. Das ist nötig, weil das SDK einen Kanal
    /// dort austrägt, wenn der Server ihn schließt (phx_close), und Nachrichten nur eingetragenen Kanälen
    /// zustellt. Vorher meldete die App nach einem solchen Schließen dasselbe, ausgetragene Objekt wieder an:
    /// Die Anmeldung kam nie zustande, die Liste blieb bis zum Neustart ohne Live-Änderungen
    /// (Meldung Robert 11.10.2026, nachgestellt in LiveRealtimeSharingTests).
    /// - Parameters:
    ///   - onChannel: Das gerade benutzte Kanal-Objekt (für das spätere Abmelden).
    ///   - listeners: Aufgaben, die Nachrichten dieses Kanal-Objekts verarbeiten; je Durchlauf neu angelegt.
    ///   - onSubscribed: Nach JEDER erfolgreichen Anmeldung – Verpasstes nachholen. Beim ersten Mal, weil das
    ///     Start-Nachladen oft fertig ist, bevor der Kanal steht (Audit 2, Befund S2); danach nach jeder
    ///     Wiederverbindung (Audit 2, Befund S1).
    @MainActor
    static func keepChannelAlive(
        realtime: RealtimeClientV2, topic: String, listId: UUID?,
        onChannel: @MainActor (RealtimeChannelV2) -> Void = { _ in },
        listeners: @MainActor (RealtimeChannelV2) -> [@Sendable () async -> Void],
        onSubscribed: @escaping @MainActor @Sendable () async -> Void = {}
    ) async {
        var delay: TimeInterval = 1
        while !Task.isCancelled {
            let channel = realtime.channel(topic) { $0.isPrivate = true }
            onChannel(channel)
            let jobs = listeners(channel)
            do {
                try await channel.subscribeWithError()
            } catch {
                guard !Task.isCancelled else { return }
                logVoid(params: (action: "realtime.subscribeError", listId: listId as Any, retryIn: delay,
                                 error: String(describing: error)))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * 2, maxRetryDelay)
                continue
            }
            guard !Task.isCancelled else { return }
            logVoid(params: (action: "realtime.subscribed", listId: listId as Any))
            delay = 1
            // Erst jetzt anlegen: Der Strom beginnt mit dem aktuellen Zustand („subscribed“). Vor dem Anmelden
            // angelegt, lieferte er auch „subscribing“ nach, und Verpasstes wurde zweimal nachgeholt.
            let statuses = channel.statusChange
            await withTaskGroup(of: Void.self) { group in
                for job in jobs { group.addTask { await job() } }
                group.addTask { await Self.watch(channel, statuses: statuses, listId: listId, onSubscribed: onSubscribed) }
                await group.next()                  // der Kanal ist aufgegeben
                group.cancelAll()
            }
            if !Task.isCancelled { logVoid(params: (action: "realtime.channelReplaced", listId: listId as Any)) }
        }
    }

    /// Beobachtet den Zustand eines angemeldeten Kanals. Das SDK meldet ihn nach einem Verbindungsabbruch
    /// selbst wieder an (dann: Verpasstes nachholen). Kehrt zurück, wenn der Kanal 5 s lang „unsubscribed“
    /// bleibt – das SDK hat ihn aufgegeben oder ausgetragen, und der Aufrufer nimmt einen frischen.
    private static func watch(_ channel: RealtimeChannelV2, statuses: AsyncStream<RealtimeChannelStatus>,
                              listId: UUID?, onSubscribed: @escaping @MainActor @Sendable () async -> Void) async {
        await onSubscribed()
        var wasSubscribed = true
        for await status in statuses {
            guard !Task.isCancelled else { return }
            switch status {
            case .subscribed:
                if !wasSubscribed {
                    logVoid(params: (action: "realtime.resubscribed", listId: listId as Any))
                    await onSubscribed()
                }
                wasSubscribed = true
            case .unsubscribed:
                wasSubscribed = false
                try? await Task.sleep(nanoseconds: abandonedAfter)
                guard !Task.isCancelled else { return }
                if channel.status == .unsubscribed {
                    logVoid(params: (action: "realtime.channelAbandoned", listId: listId as Any))
                    return
                }
            case .subscribing, .unsubscribing:
                wasSubscribed = false
            }
        }
    }

    /// App wieder im Vordergrund: Kanäle, die das SDK nicht mehr führt, neu aufbauen. Ein solcher Kanal kann
    /// weiter als „subscribed“ gelten und bekommt trotzdem keine Nachrichten; ein Zustandswechsel bleibt aus.
    /// Bewusst eine einmalige Prüfung beim Öffnen und kein Takt (Wunsch Robert 11.10.2026: kein Akkuverbrauch
    /// durch regelmäßiges Prüfen). Nur ein Blick in den Arbeitsspeicher, kein Netzwerk.
    func replaceUnregisteredChannels() {
        let registered = client.realtime.channels
        for (listId, channel) in channels where registered[channel.topic] !== channel {
            guard let handler = handlers[listId] else { continue }
            logVoid(params: (action: "realtime.channelUnregistered", listId: listId))
            Task { @MainActor [weak self] in
                await self?.setupRealtimeChannel(for: listId, onEvent: handler.onEvent,
                                                 onResubscribed: handler.onResubscribed)
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
        handlers.removeValue(forKey: listId)
        guard let channel = channels.removeValue(forKey: listId) else { return }
        let realtime = client.realtime
        Task { @MainActor [weak self] in
            if let current = self?.channels[listId], current === channel { return }   // wiederverwendet
            await channel.unsubscribe()
            // Das Abmelden wartet auf den Server. Wurde die Liste inzwischen wieder geöffnet, benutzt die neue
            // Beobachtung dasselbe Objekt – dann bleibt es eingetragen (sie meldet es selbst wieder an).
            if let current = self?.channels[listId], current === channel { return }
            // removeChannel trägt nach dem THEMA aus, nicht nach dem Objekt: nur, wenn das SDK noch genau
            // dieses Objekt führt. Sonst träfe es einen neueren Kanal derselben Liste und machte ihn taub.
            guard realtime.channels[channel.topic] === channel else { return }
            await realtime.removeChannel(channel)
        }
        logVoid(params: (listId: listId, action: "teardownRealtimeChannel"))
    }
}
