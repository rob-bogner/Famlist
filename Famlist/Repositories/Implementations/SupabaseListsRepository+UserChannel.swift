/*
 SupabaseListsRepository+UserChannel.swift
 Famlist
 Created on: 27.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Privater Realtime-Kanal `user:<id>`: alle Ereignisse für genau dieses Konto in einem Abonnement.

 🔰 Notes for Beginners:
 - member_removed (Trigger on_list_member_removed, Migration 014): aus einer Liste entfernt.
 - member_restored, member_archived, account_archived (Migration 027): Konto-Archiv.
 - Postgres Changes auf list_members gingen nicht: DELETE-Events lassen sich dort nicht filtern und
   erreichten alle Nutzer. Deshalb schickt der Server gezielte Broadcasts an `user:<id>`.

 📝 Last Change:
 - Aus observeMemberRemovals hervorgegangen und um die Archiv-Ereignisse erweitert (Konto-Archiv, Phase 3).
 ------------------------------------------------------------------------
 */

import Foundation
import Supabase

extension SupabaseListsRepository {
    func observeUserEvents(userId: UUID) -> AsyncStream<UserChannelEvent> {
        AsyncStream { [weak self] continuation in
            guard let self else { continuation.finish(); return }

            let realtime = client.realtime
            let topic = "user:\(userId.uuidString.lowercased())"
            let events = ["member_removed", "member_restored", "member_archived", "account_archived"]

            let task = Task { @MainActor in
                // Anmelden mit Wiederholung und Ersatz eines vom SDK ausgetragenen Kanals – wie bei den
                // Listen-Kanälen (Audit 2, Befund S12; taube Kanäle 11.10.2026).
                await SupabaseRealtimeManager.keepChannelAlive(
                    realtime: realtime, topic: topic, listId: nil,
                    listeners: { channel in
                        events.map { event in
                            let stream = channel.broadcastStream(event: event)
                            return {
                                for await message in stream {
                                    if let parsed = Self.userEvent(event, message: message) { continuation.yield(parsed) }
                                }
                            }
                        }
                    })
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                // Das Kanal-Objekt kann inzwischen ersetzt worden sein: das abmelden, das das SDK gerade führt.
                Task { await realtime.channels["realtime:\(topic)"]?.unsubscribe() }
            }
        }
    }

    /// Übersetzt eine Broadcast-Nachricht in ein Ereignis; unvollständige Nachrichten werden ignoriert.
    nonisolated static func userEvent(_ event: String, message: JSONObject) -> UserChannelEvent? {
        let payload = message["payload"]?.objectValue ?? message
        switch event {
        case "member_removed":
            return listId(fromBroadcast: message).map { .memberRemoved(listId: $0) }
        case "member_restored":
            return listId(fromBroadcast: message).map { .memberRestored(listId: $0) }
        case "member_archived":
            guard let raw = payload["notice_id"]?.stringValue, let noticeId = UUID(uuidString: raw) else { return nil }
            let name = payload["subject_name"]?.stringValue ?? "Ein Mitglied"
            return .memberArchived(AccountNotice(id: noticeId, listId: listId(fromBroadcast: message), subjectName: name))
        case "account_archived":
            return .accountArchived
        default:
            return nil
        }
    }
}
