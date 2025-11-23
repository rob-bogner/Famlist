/*
 SupabaseRealtimeManager.swift
 Famlist
 Created on: 18.10.2025
 Last updated on: 18.10.2025

 ------------------------------------------------------------------------
 📄 File Overview: Manages Supabase Realtime channel lifecycle for item observation.
 🛠 Includes: Channel setup/teardown, stream handling for insertions, updates, and deletions.
 🔰 Notes for Beginners: Extracted from SupabaseItemsRepository to follow Single Responsibility.
 📝 Last Change: Initial creation to isolate Realtime channel management from CRUD operations.
 ------------------------------------------------------------------------
*/

import Foundation // Provides UUID.
import Supabase // Brings in Supabase types for Realtime channels.

/// Realtime event types with their payloads
enum RealtimeEvent {
    case insert(payload: [String: Any])
    case update(payload: [String: Any])
    case delete(payload: [String: Any])
}

/// Manages Realtime channel lifecycle and streams for a specific list.
final class SupabaseRealtimeManager {
    
    // MARK: - Dependencies
    
    private let client: SupabaseClienting
    
    // MARK: - State
    
    /// Track Realtime channels for each list to enable cleanup on unsubscribe.
    private var channels: [UUID: RealtimeChannelV2] = [:]
    
    // MARK: - Lifecycle
    
    init(client: SupabaseClienting) {
        self.client = client
    }
    
    // MARK: - Channel Management
    
    /// Sets up a Realtime channel to listen for changes on the items table for a specific list.
    /// Following the pattern from: https://ardyan.medium.com/building-chat-app-with-supabase-swiftui-in-under-100-lines-of-code-d01285f6e87a
    /// - Parameters:
    ///   - listId: The list UUID to monitor.
    ///   - onEvent: Callback invoked with event payload for granular processing.
    func setupRealtimeChannel(
        for listId: UUID,
        onEvent: @escaping (RealtimeEvent) async -> Void
    ) async {
        let channelId = "public:items:\(listId)"
        logVoid(params: (listId: listId, action: "setupChannel", channelId: channelId))
        
        let channel = client.realtime.channel(channelId)
        
        // Create AsyncStreams for each change type using postgresChange with type-safe filter syntax
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "items",
            filter: .eq("list_id", value: listId.uuidString)
        )
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "items",
            filter: .eq("list_id", value: listId.uuidString)
        )
        let deletions = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "items",
            filter: .eq("list_id", value: listId.uuidString)
        )
        
        // Subscribe to the channel BEFORE consuming the streams
        do {
            try await channel.subscribeWithError()
            logVoid(params: (
                listId: listId,
                action: "channelSubscribed",
                channelId: channelId,
                status: "success"
            ))
        } catch {
            logVoid(params: (
                listId: listId,
                action: "channelSubscribed",
                channelId: channelId,
                status: "failed",
                error: String(describing: error)
            ))
            return
        }
        
        // Store channel for later cleanup
        channels[listId] = channel
        
        // Process insertions in background task
        Task {
            for await insertion in insertions {
                logVoid(params: (listId: listId, action: "realtimeInsert", record: insertion.record))
                let payload = ["record": insertion.record]
                await onEvent(.insert(payload: payload))
            }
        }
        
        // Process updates in background task
        Task {
            for await update in updates {
                logVoid(params: (listId: listId, action: "realtimeUpdate", record: update.record))
                let payload = ["record": update.record]
                await onEvent(.update(payload: payload))
            }
        }
        
        // Process deletions in background task
        Task {
            for await deletion in deletions {
                logVoid(params: (listId: listId, action: "realtimeDelete", oldRecord: deletion.oldRecord))
                let payload = ["old_record": deletion.oldRecord]
                await onEvent(.delete(payload: payload))
            }
        }
    }
    
    /// Tears down the Realtime channel for a specific list when no more observers exist.
    /// - Parameter listId: The list UUID whose channel should be closed.
    func teardownRealtimeChannel(for listId: UUID) {
        guard let channel = channels[listId] else { return }
        Task {
            await channel.unsubscribe()
        }
        channels.removeValue(forKey: listId)
        logVoid(params: (listId: listId, action: "teardownRealtimeChannel"))
    }
}

